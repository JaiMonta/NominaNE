alter table empleados add column if not exists motivo_egreso text;

alter table empleados drop constraint if exists empleados_motivo_egreso_check;
alter table empleados add constraint empleados_motivo_egreso_check
  check (motivo_egreso is null or motivo_egreso in (
    'renuncia', 'despido_justificado', 'despido_injustificado',
    'mutuo_acuerdo', 'fin_contrato', 'jubilacion', 'fallecimiento'));

create table if not exists liquidaciones (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid not null references empleados(id),
  fecha_ingreso date not null,
  fecha_egreso date not null,
  motivo text not null check (motivo in (
    'renuncia', 'despido_justificado', 'despido_injustificado',
    'mutuo_acuerdo', 'fin_contrato', 'jubilacion', 'fallecimiento')),
  fecha_calculo date not null default current_date,
  tasa_bcv numeric(18,4),
  salario_normal_usd numeric(14,2) default 0,
  salario_normal_bs numeric(16,2) default 0,
  salario_integral_bs numeric(16,4) default 0,
  anios integer default 0,
  meses integer default 0,
  dias integer default 0,
  garantia_bs numeric(16,2) default 0,
  intereses_bs numeric(16,2) default 0,
  retroactivo_bs numeric(16,2) default 0,
  prestaciones_bs numeric(16,2) default 0,
  vacaciones_bs numeric(16,2) default 0,
  bono_vac_bs numeric(16,2) default 0,
  utilidades_bs numeric(16,2) default 0,
  indemnizacion_bs numeric(16,2) default 0,
  salario_pendiente_bs numeric(16,2) default 0,
  otros_ingresos_bs numeric(16,2) default 0,
  deducciones_bs numeric(16,2) default 0,
  neto_bs numeric(16,2) default 0,
  total_usd numeric(14,2) default 0,
  estado text not null default 'borrador'
    check (estado in ('borrador', 'aprobada', 'pagada', 'anulada')),
  nota text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  aprobada_por uuid references auth.users(id),
  aprobada_at timestamptz,
  pagada_at timestamptz
);

create table if not exists liquidacion_detalle (
  id uuid primary key default gen_random_uuid(),
  liquidacion_id uuid not null references liquidaciones(id) on delete cascade,
  codigo text not null,
  nombre text not null,
  tipo text not null check (tipo in ('ingreso', 'deduccion')),
  dias numeric(10,2) default 0,
  base numeric(16,4) default 0,
  monto numeric(16,2) not null default 0,
  base_legal text,
  orden integer default 0
);
create index if not exists liquidacion_detalle_liquidacion_idx
  on liquidacion_detalle (liquidacion_id);

create table if not exists prestaciones_config (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid not null references empleados(id) on delete cascade,
  vigente_desde date not null,
  modalidad text not null default 'contabilidad'
    check (modalidad in ('contabilidad', 'fideicomiso', 'fondo', 'no_depositada')),
  tipo_tasa text not null default 'pasiva'
    check (tipo_tasa in ('pasiva', 'promedio', 'activa', 'rendimiento')),
  capitalizar_intereses boolean not null default false,
  nota text,
  created_at timestamptz default now(),
  unique (empleado_id, vigente_desde)
);

create table if not exists prestaciones_movimientos (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid not null references empleados(id) on delete cascade,
  fecha date not null,
  periodo date,
  tipo text not null check (tipo in (
    'saldo_inicial', 'garantia_trimestral', 'dias_adicionales',
    'interes', 'anticipo', 'pago', 'ajuste')),
  dias numeric(10,2) default 0,
  salario_integral numeric(16,4) default 0,
  monto numeric(16,2) not null default 0,
  tasa_interes numeric(10,6),
  modalidad text,
  nota text,
  liquidacion_id uuid references liquidaciones(id) on delete set null,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);
create index if not exists prestaciones_movimientos_empleado_idx
  on prestaciones_movimientos (empleado_id, fecha);

create table if not exists tasas_interes_prestaciones (
  periodo date primary key,
  tasa_activa numeric(10,6) not null default 0,
  tasa_pasiva numeric(10,6) not null default 0,
  tasa_promedio numeric(10,6) not null default 0,
  rendimiento_fideicomiso numeric(10,6) not null default 0,
  fuente text default 'BCV',
  created_at timestamptz default now()
);

create table if not exists vacaciones_registro (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid not null references empleados(id) on delete cascade,
  periodo_inicio date not null,
  periodo_fin date not null,
  dias_vacaciones numeric(6,2) not null default 0,
  dias_bono numeric(6,2) not null default 0,
  dias_disfrutados numeric(6,2) not null default 0,
  dias_bono_pagados numeric(6,2) not null default 0,
  salario_normal numeric(16,4) default 0,
  nota text,
  created_at timestamptz default now(),
  unique (empleado_id, periodo_inicio)
);
create index if not exists vacaciones_registro_empleado_idx
  on vacaciones_registro (empleado_id, periodo_inicio);

alter table liquidaciones enable row level security;
alter table liquidacion_detalle enable row level security;
alter table prestaciones_config enable row level security;
alter table prestaciones_movimientos enable row level security;
alter table tasas_interes_prestaciones enable row level security;
alter table vacaciones_registro enable row level security;

drop policy if exists liquidaciones_read on liquidaciones;
drop policy if exists liquidaciones_write on liquidaciones;
create policy liquidaciones_read on liquidaciones for select
  using (auth.uid() is not null);
create policy liquidaciones_write on liquidaciones for all
  using (es_rrhh()) with check (es_rrhh());

drop policy if exists liquidacion_detalle_read on liquidacion_detalle;
drop policy if exists liquidacion_detalle_write on liquidacion_detalle;
create policy liquidacion_detalle_read on liquidacion_detalle for select
  using (auth.uid() is not null);
create policy liquidacion_detalle_write on liquidacion_detalle for all
  using (es_rrhh()) with check (es_rrhh());

drop policy if exists prestaciones_config_read on prestaciones_config;
drop policy if exists prestaciones_config_write on prestaciones_config;
create policy prestaciones_config_read on prestaciones_config for select
  using (auth.uid() is not null);
create policy prestaciones_config_write on prestaciones_config for all
  using (es_rrhh()) with check (es_rrhh());

drop policy if exists prestaciones_movimientos_read on prestaciones_movimientos;
drop policy if exists prestaciones_movimientos_write on prestaciones_movimientos;
create policy prestaciones_movimientos_read on prestaciones_movimientos for select
  using (auth.uid() is not null);
create policy prestaciones_movimientos_write on prestaciones_movimientos for all
  using (es_rrhh()) with check (es_rrhh());

drop policy if exists tasas_interes_prestaciones_read on tasas_interes_prestaciones;
drop policy if exists tasas_interes_prestaciones_write on tasas_interes_prestaciones;
create policy tasas_interes_prestaciones_read on tasas_interes_prestaciones for select
  using (auth.uid() is not null);
create policy tasas_interes_prestaciones_write on tasas_interes_prestaciones for all
  using (es_rrhh()) with check (es_rrhh());

drop policy if exists vacaciones_registro_read on vacaciones_registro;
drop policy if exists vacaciones_registro_write on vacaciones_registro;
create policy vacaciones_registro_read on vacaciones_registro for select
  using (auth.uid() is not null);
create policy vacaciones_registro_write on vacaciones_registro for all
  using (es_rrhh()) with check (es_rrhh());

create or replace function inicializar_vacaciones(p_empleado_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ingreso date;
  v_cursor date;
  v_fin date;
  v_n integer := 0;
  v_count integer := 0;
  v_dias numeric;
begin
  if not es_rrhh() then
    raise exception 'No autorizado';
  end if;

  select fecha_ingreso into v_ingreso
    from empleados where id = p_empleado_id;

  if v_ingreso is null then
    raise exception 'Empleado no encontrado';
  end if;

  loop
    v_cursor := (v_ingreso + (v_n || ' years')::interval)::date;
    exit when v_cursor > current_date;

    v_fin := (v_cursor + interval '1 year' - interval '1 day')::date;
    v_dias := least(15 + v_n, 30);

    insert into vacaciones_registro
      (empleado_id, periodo_inicio, periodo_fin,
       dias_vacaciones, dias_bono, salario_normal)
    values
      (p_empleado_id, v_cursor, v_fin, v_dias, v_dias, 0)
    on conflict (empleado_id, periodo_inicio) do nothing;

    v_count := v_count + 1;
    v_n := v_n + 1;
  end loop;

  return v_count;
end;
$$;

create or replace function aprobar_liquidacion(p_liquidacion_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_empleado uuid;
  v_fecha date;
  v_motivo text;
begin
  if not es_rrhh() then
    raise exception 'No autorizado';
  end if;

  select empleado_id, fecha_egreso, motivo
    into v_empleado, v_fecha, v_motivo
    from liquidaciones
   where id = p_liquidacion_id
     and estado = 'borrador'
     for update;

  if not found then
    raise exception 'Liquidacion no encontrada o no esta en borrador';
  end if;

  update liquidaciones
     set estado = 'aprobada',
         aprobada_por = auth.uid(),
         aprobada_at = now()
   where id = p_liquidacion_id;

  update empleados
     set activo = false,
         fecha_egreso = v_fecha,
         motivo_egreso = v_motivo
   where id = v_empleado;
end;
$$;

create or replace function anular_liquidacion(p_liquidacion_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_empleado uuid;
  v_estado text;
begin
  if not es_rrhh() then
    raise exception 'No autorizado';
  end if;

  select empleado_id, estado
    into v_empleado, v_estado
    from liquidaciones
   where id = p_liquidacion_id
     for update;

  if not found then
    raise exception 'Liquidacion no encontrada';
  end if;
  if v_estado not in ('borrador', 'aprobada') then
    raise exception 'Solo se puede anular una liquidacion no pagada';
  end if;

  update liquidaciones
     set estado = 'anulada'
   where id = p_liquidacion_id;

  update empleados
     set activo = true,
         fecha_egreso = null,
         motivo_egreso = null
   where id = v_empleado;
end;
$$;

create or replace function pagar_liquidacion(p_liquidacion_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not es_rrhh() then
    raise exception 'No autorizado';
  end if;

  update liquidaciones
     set estado = 'pagada',
         pagada_at = now()
   where id = p_liquidacion_id
     and estado = 'aprobada';

  if not found then
    raise exception 'Liquidacion no encontrada o no esta aprobada';
  end if;
end;
$$;

grant execute on function inicializar_vacaciones(uuid) to authenticated;
grant execute on function aprobar_liquidacion(uuid) to authenticated;
grant execute on function anular_liquidacion(uuid) to authenticated;
grant execute on function pagar_liquidacion(uuid) to authenticated;
