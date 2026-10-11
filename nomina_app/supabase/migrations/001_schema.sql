-- =====================================================================
-- NÓMINA WEB APP — Esquema Supabase (PostgreSQL)
-- Base legal: LOT (arts. 108, 133, 140, 144-146, 154-156, 174-175,
-- 195, 219, 223), LOPCYMAT (arts. 7, 95) y NT-03-2016.
-- Todos los porcentajes/días son PARÁMETROS editables (tabla
-- parametros_legales): la ley adjunta (LOT 1997) fue sustituida por la
-- LOTTT 2012, así que valide los valores vigentes antes de producción.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------- Roles ----------
create table perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null,
  rol text not null default 'consulta' check (rol in ('admin','rrhh','consulta')),
  created_at timestamptz default now()
);

create or replace function es_rrhh() returns boolean
language sql stable security definer as $$
  select exists (select 1 from perfiles where id = auth.uid() and rol in ('admin','rrhh'));
$$;

-- Crea perfil automáticamente al registrarse un usuario
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, nombre, rol)
  values (new.id, coalesce(new.raw_user_meta_data->>'nombre', new.email),
          case when (select count(*) from public.perfiles) = 0 then 'admin' else 'consulta' end);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Parámetros legales (editables) ----------
create table parametros_legales (
  clave text primary key,
  valor numeric not null,
  descripcion text not null,
  referencia_legal text
);

insert into parametros_legales (clave, valor, descripcion, referencia_legal) values
 ('dias_mes',                 30,    'Divisor para salario diario (mensual/30)',                 'LOT Art. 140'),
 ('horas_jornada_diurna',      8,    'Horas de la jornada diurna diaria',                        'LOT Art. 195'),
 ('recargo_hora_extra',      0.50,   'Recargo hora extraordinaria (50%)',                        'LOT Art. 155'),
 ('recargo_nocturno',        0.30,   'Recargo jornada nocturna (30%)',                           'LOT Art. 156'),
 ('recargo_feriado',         0.50,   'Recargo trabajo en feriado/descanso (50%)',                'LOT Arts. 154, 217'),
 ('vacaciones_dias_base',     15,    'Días hábiles de vacaciones al primer año',                 'LOT Art. 219'),
 ('vacaciones_dia_adicional',  1,    'Días adicionales por cada año de servicio',                'LOT Art. 219'),
 ('vacaciones_dias_max',      30,    'Máximo de días hábiles de vacaciones',                     'LOT Art. 219'),
 ('bono_vac_dias_base',        7,    'Días de salario del bono vacacional (año 1)',              'LOT Art. 223'),
 ('bono_vac_dia_adicional',    1,    'Días adicionales de bono por año',                         'LOT Art. 223'),
 ('bono_vac_dias_max',        21,    'Máximo de días de bono vacacional',                        'LOT Art. 223'),
 ('utilidades_dias_min',      15,    'Mínimo de días de utilidades (anticipo diciembre)',        'LOT Arts. 174-175'),
 ('utilidades_dias_max',     120,    'Máximo de días de utilidades (4 meses)',                   'LOT Art. 174'),
 ('utilidades_dias_pyme',     60,    'Máximo para empresas pequeñas (2 meses)',                  'LOT Art. 174 §1'),
 ('antiguedad_dias_mes',       5,    'Días de salario por mes (tras 3 meses de servicio)',       'LOT Art. 108'),
 ('antiguedad_dias_anual_extra',2,   'Días adicionales por año (acumulativo hasta tope)',        'LOT Art. 108'),
 ('antiguedad_dias_extra_max',30,    'Tope de días adicionales acumulados',                      'LOT Art. 108'),
 ('ivss_empleado_pct',      0.04,    'Seguro Social Obligatorio - aporte trabajador',            'Ley del Seguro Social (parámetro externo)'),
 ('ivss_patrono_pct',       0.09,    'Seguro Social Obligatorio - aporte patrono (riesgo medio)','Ley del Seguro Social (parámetro externo)'),
 ('ivss_tope_salarios_min',    5,    'Tope de cotización IVSS en salarios mínimos',              'Ley del Seguro Social (parámetro externo)'),
 ('rpe_empleado_pct',      0.005,    'Régimen Prestacional de Empleo (paro forzoso) - trabajador','Ley RPE (parámetro externo)'),
 ('rpe_patrono_pct',        0.02,    'Régimen Prestacional de Empleo - patrono',                 'Ley RPE (parámetro externo)'),
 ('faov_empleado_pct',      0.01,    'Ley de Política Habitacional (FAOV) - trabajador',         'LRPVH (parámetro externo)'),
 ('faov_patrono_pct',       0.02,    'Ley de Política Habitacional (FAOV) - patrono',            'LRPVH (parámetro externo)'),
 ('lopcymat_patrono_pct',  0.0075,   'Cotización LOPCYMAT patrono (banda 0,75%–10%)',            'LOPCYMAT Art. 7 y 94-95'),
 ('salario_minimo_mensual', 130,     'Salario mínimo mensual vigente (ACTUALIZAR)',              'Decreto ejecutivo vigente'),
 ('dias_utilidades_empresa',  30,    'Días de utilidades que paga la empresa (15–120)',          'LOT Art. 174');

-- ---------- Empleados ----------
create table empleados (
  id uuid primary key default gen_random_uuid(),
  cedula text unique not null,
  nombres text not null,
  apellidos text not null,
  cargo text not null,
  departamento text,
  tipo text not null default 'empleado' check (tipo in ('empleado','obrero')), -- LOT Arts. 41, 43
  fecha_ingreso date not null,
  fecha_egreso date,
  salario_mensual numeric(14,2) not null check (salario_mensual >= 0),
  jornada text not null default 'diurna' check (jornada in ('diurna','nocturna','mixta')),
  frecuencia_pago text not null default 'quincenal' check (frecuencia_pago in ('semanal','quincenal','mensual')), -- Art. 150
  banco text,
  cuenta text,
  email text,
  activo boolean not null default true,
  created_at timestamptz default now()
);
create index on empleados (activo);

-- ---------- Conceptos de nómina ----------
create table conceptos (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,
  nombre text not null,
  tipo text not null check (tipo in ('ingreso','egreso')),
  base_legal text,
  es_salarial boolean not null default true,       -- Art. 133
  calculo text not null default 'fijo' check (calculo in ('fijo','porcentaje_salario','manual')),
  valor numeric(14,4) not null default 0,          -- monto fijo o porcentaje (0.05 = 5%)
  automatico boolean not null default false,       -- lo calcula el motor
  activo boolean not null default true
);

insert into conceptos (codigo, nombre, tipo, base_legal, es_salarial, calculo, automatico) values
 ('SUELDO',   'Sueldo básico del período',            'ingreso', 'LOT Art. 133, 140',       true,  'manual', true),
 ('HE_DIURNA','Horas extraordinarias diurnas',        'ingreso', 'LOT Art. 155',            true,  'manual', true),
 ('HE_NOCT',  'Horas extraordinarias nocturnas',      'ingreso', 'LOT Arts. 155-156',       true,  'manual', true),
 ('REC_NOCT', 'Recargo jornada nocturna',             'ingreso', 'LOT Art. 156',            true,  'manual', true),
 ('FERIADO',  'Trabajo en feriado/descanso (recargo)','ingreso', 'LOT Arts. 154, 217-218',  true,  'manual', true),
 ('BONO_VAC', 'Bono vacacional',                      'ingreso', 'LOT Art. 223',            true,  'manual', true),
 ('VACACIONES','Pago de vacaciones',                  'ingreso', 'LOT Arts. 219, 222',      true,  'manual', true),
 ('UTILIDADES','Utilidades / participación en beneficios','ingreso','LOT Arts. 174-175',    true,  'manual', true),
 ('BONO_ALIM','Bonificación (alimentación/otros)',    'ingreso', 'LOT Art. 133 §1',         false, 'fijo',   false),
 ('COMISION', 'Comisiones',                           'ingreso', 'LOT Art. 133',            true,  'manual', false),
 ('IVSS',     'Seguro Social Obligatorio (SSO)',      'egreso',  'Ley del Seguro Social',   false, 'manual', true),
 ('RPE',      'Régimen Prestacional de Empleo',       'egreso',  'Ley RPE',                 false, 'manual', true),
 ('FAOV',     'Ley de Política Habitacional (FAOV)',  'egreso',  'LRPVH',                   false, 'manual', true),
 ('PRESTAMO', 'Cuota de préstamo a la empresa',       'egreso',  'LOT Art. 165 (máx. 1/3)', false, 'manual', false),
 ('ANTICIPO', 'Adelanto de sueldo',                   'egreso',  'LOT Art. 165',            false, 'manual', false),
 ('EMBARGO',  'Retención judicial',                   'egreso',  'LOT Arts. 162-164',       false, 'manual', false),
 ('CUOTA_SIND','Cuota sindical',                      'egreso',  'LOT Arts. 132 §1, 446',   false, 'manual', false);

-- Novedades por empleado y concepto (recurrentes o del período)
create table novedades (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid not null references empleados(id) on delete cascade,
  concepto_id uuid not null references conceptos(id),
  periodo_inicio date,                 -- null = recurrente
  periodo_fin date,
  cantidad numeric(12,2) default 1,    -- horas, días, unidades
  monto numeric(14,2) not null default 0,
  nota text,
  created_at timestamptz default now()
);
create index on novedades (empleado_id);

-- ---------- Corridas de nómina ----------
create table nominas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  frecuencia text not null check (frecuencia in ('semanal','quincenal','mensual')),
  periodo_inicio date not null,
  periodo_fin date not null,
  estado text not null default 'borrador' check (estado in ('borrador','aprobada','pagada')),
  total_ingresos numeric(16,2) default 0,
  total_egresos numeric(16,2) default 0,
  total_neto numeric(16,2) default 0,
  total_aportes_patronales numeric(16,2) default 0,
  creada_por uuid references auth.users(id),
  created_at timestamptz default now()
);

create table recibos (
  id uuid primary key default gen_random_uuid(),
  nomina_id uuid not null references nominas(id) on delete cascade,
  empleado_id uuid not null references empleados(id),
  salario_mensual numeric(14,2) not null,
  salario_diario numeric(14,4) not null,
  total_ingresos numeric(14,2) not null,
  total_egresos numeric(14,2) not null,
  neto numeric(14,2) not null,
  aportes_patronales numeric(14,2) not null default 0,
  unique (nomina_id, empleado_id)
);

create table recibo_detalle (
  id uuid primary key default gen_random_uuid(),
  recibo_id uuid not null references recibos(id) on delete cascade,
  concepto_codigo text not null,
  concepto_nombre text not null,
  tipo text not null check (tipo in ('ingreso','egreso')),
  cantidad numeric(12,2) default 1,
  monto numeric(14,2) not null,
  base_legal text
);
create index on recibo_detalle (recibo_id);

-- Prestaciones sociales: acreditación mensual (Art. 108)
create table antiguedad_acreditada (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid not null references empleados(id) on delete cascade,
  mes date not null,
  dias numeric(6,2) not null,
  salario_diario numeric(14,4) not null,
  monto numeric(14,2) not null,
  unique (empleado_id, mes)
);

-- ---------- RLS ----------
alter table perfiles enable row level security;
alter table parametros_legales enable row level security;
alter table empleados enable row level security;
alter table conceptos enable row level security;
alter table novedades enable row level security;
alter table nominas enable row level security;
alter table recibos enable row level security;
alter table recibo_detalle enable row level security;
alter table antiguedad_acreditada enable row level security;

create policy perfiles_self on perfiles for select using (id = auth.uid() or es_rrhh());
create policy perfiles_insert on perfiles for insert
  with check (id = auth.uid() or es_rrhh());
create policy perfiles_admin on perfiles for update
  using (exists (select 1 from perfiles p where p.id = auth.uid() and p.rol = 'admin'));

-- Lectura: cualquier usuario autenticado con perfil; escritura: admin/rrhh
do $$
declare t text;
begin
  foreach t in array array['parametros_legales','empleados','conceptos','novedades',
                           'nominas','recibos','recibo_detalle','antiguedad_acreditada']
  loop
    execute format('create policy %I_read on %I for select using (auth.uid() is not null)', t, t);
    execute format('create policy %I_write on %I for all using (es_rrhh()) with check (es_rrhh())', t, t);
  end loop;
end $$;
