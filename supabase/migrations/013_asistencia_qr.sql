create extension if not exists pgcrypto;

create table if not exists qr_asistencia (
  id uuid primary key default gen_random_uuid(),
  fecha date not null,
  token text not null unique,
  activo boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create unique index if not exists qr_asistencia_activo_por_fecha
  on qr_asistencia (fecha) where activo;

create table if not exists asistencia_pines (
  empleado_id uuid primary key references empleados(id) on delete cascade,
  pin_hash text not null,
  intentos_fallidos integer not null default 0,
  bloqueado_hasta timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists asistencias (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid not null references empleados(id) on delete cascade,
  fecha date not null,
  entrada timestamptz,
  salida timestamptz,
  metodo_entrada text check (metodo_entrada in ('qr', 'manual')),
  metodo_salida text check (metodo_salida in ('qr', 'manual')),
  qr_entrada_id uuid references qr_asistencia(id),
  qr_salida_id uuid references qr_asistencia(id),
  nota text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint asistencias_empleado_fecha_unique unique (empleado_id, fecha)
);

create index if not exists asistencias_fecha_idx on asistencias (fecha);
create index if not exists asistencias_empleado_idx on asistencias (empleado_id);

create or replace function crear_qr_asistencia(p_reemplazar boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_fecha date := (now() at time zone 'America/Caracas')::date;
  v_token text;
begin
  if not es_rrhh() then
    raise exception 'No autorizado';
  end if;

  if not p_reemplazar then
    select token into v_token
      from qr_asistencia
     where fecha = v_fecha and activo
     order by created_at desc
     limit 1;
    if v_token is not null then
      return jsonb_build_object('token', v_token, 'fecha', v_fecha);
    end if;
  else
    update qr_asistencia
       set activo = false
     where fecha = v_fecha and activo;
  end if;

  v_token := encode(gen_random_bytes(16), 'hex');
  insert into qr_asistencia (fecha, token, activo, created_by)
  values (v_fecha, v_token, true, auth.uid());

  return jsonb_build_object('token', v_token, 'fecha', v_fecha);
end;
$$;

create or replace function validar_qr_asistencia(p_token text)
returns boolean
language sql
security definer
set search_path = public, extensions, pg_temp
as $$
  select exists (
    select 1
      from qr_asistencia
     where token = p_token
       and activo
       and fecha = (now() at time zone 'America/Caracas')::date
  );
$$;

create or replace function asignar_pin_asistencia(p_empleado_id uuid, p_pin text)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  if not es_rrhh() then
    raise exception 'No autorizado';
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{4,6}$' then
    raise exception 'El PIN debe tener entre 4 y 6 dígitos';
  end if;
  if not exists (select 1 from empleados where id = p_empleado_id) then
    raise exception 'Empleado no encontrado';
  end if;

  insert into asistencia_pines (empleado_id, pin_hash, intentos_fallidos, bloqueado_hasta, updated_at)
  values (p_empleado_id, crypt(p_pin, gen_salt('bf')), 0, null, now())
  on conflict (empleado_id) do update
    set pin_hash = excluded.pin_hash,
        intentos_fallidos = 0,
        bloqueado_hasta = null,
        updated_at = now();
end;
$$;

create or replace function registrar_asistencia(
  p_token text,
  p_cedula text,
  p_pin text,
  p_tipo text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_fecha date := (now() at time zone 'America/Caracas')::date;
  v_hora timestamptz := now();
  v_tipo text := lower(trim(coalesce(p_tipo, '')));
  v_cedula text := regexp_replace(coalesce(p_cedula, ''), '\D', '', 'g');
  v_qr qr_asistencia%rowtype;
  v_emp empleados%rowtype;
  v_pin asistencia_pines%rowtype;
  v_row asistencias%rowtype;
  v_nombre text;
begin
  if v_tipo not in ('entrada', 'salida') then
    return jsonb_build_object('ok', false, 'error', 'Tipo de registro inválido');
  end if;
  if p_pin is null or p_pin = '' then
    return jsonb_build_object('ok', false, 'error', 'Cédula o PIN incorrectos');
  end if;

  select * into v_qr
    from qr_asistencia
   where token = p_token and fecha = v_fecha and activo
   order by created_at desc
   limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'QR vencido o inválido. Solicite el QR del día a RRHH.');
  end if;

  select * into v_emp
    from empleados
   where cedula = v_cedula and activo
   limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Cédula o PIN incorrectos');
  end if;

  select * into v_pin
    from asistencia_pines
   where empleado_id = v_emp.id
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'No tiene PIN de asistencia. Consulte a RRHH.');
  end if;

  if v_pin.bloqueado_hasta is not null and v_pin.bloqueado_hasta > now() then
    return jsonb_build_object('ok', false, 'error', 'Demasiados intentos. Intente de nuevo en unos minutos.');
  end if;

  if crypt(p_pin, v_pin.pin_hash) <> v_pin.pin_hash then
    update asistencia_pines
       set intentos_fallidos = v_pin.intentos_fallidos + 1,
           bloqueado_hasta = case
             when v_pin.intentos_fallidos + 1 >= 5 then now() + interval '15 minutes'
             else null
           end,
           updated_at = now()
     where empleado_id = v_emp.id;
    return jsonb_build_object('ok', false, 'error', 'Cédula o PIN incorrectos');
  end if;

  update asistencia_pines
     set intentos_fallidos = 0,
         bloqueado_hasta = null,
         updated_at = now()
   where empleado_id = v_emp.id;

  if v_tipo = 'entrada' then
    select * into v_row
      from asistencias
     where empleado_id = v_emp.id and fecha = v_fecha
     for update;
    if found and v_row.entrada is not null then
      return jsonb_build_object('ok', false, 'error', 'Ya registró su entrada hoy');
    end if;
    if exists (
      select 1
        from asistencias
       where empleado_id = v_emp.id
         and entrada is not null
         and salida is null
         and entrada >= now() - interval '24 hours'
    ) then
      return jsonb_build_object('ok', false, 'error', 'Tiene una entrada sin salida. Registre la salida o consulte a RRHH.');
    end if;

    insert into asistencias (empleado_id, fecha, entrada, metodo_entrada, qr_entrada_id)
    values (v_emp.id, v_fecha, v_hora, 'qr', v_qr.id)
    on conflict (empleado_id, fecha) do update
      set entrada = excluded.entrada,
          metodo_entrada = 'qr',
          qr_entrada_id = excluded.qr_entrada_id,
          updated_at = now()
      where asistencias.entrada is null;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'Ya registró su entrada hoy');
    end if;
  else
    select * into v_row
      from asistencias
     where empleado_id = v_emp.id
       and entrada is not null
       and salida is null
       and entrada >= now() - interval '24 hours'
     order by entrada desc
     limit 1
     for update;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'No tiene una entrada pendiente de salida');
    end if;
    update asistencias
       set salida = v_hora,
           metodo_salida = 'qr',
           qr_salida_id = v_qr.id,
           updated_at = now()
     where id = v_row.id;
  end if;

  v_nombre := trim(v_emp.nombres || ' ' || v_emp.apellidos);
  return jsonb_build_object('ok', true, 'nombre', v_nombre, 'tipo', v_tipo, 'hora', v_hora);
end;
$$;

create or replace function registrar_asistencia_manual(
  p_empleado_id uuid,
  p_fecha date,
  p_tipo text,
  p_hora timestamptz default now(),
  p_nota text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_tipo text := lower(trim(coalesce(p_tipo, '')));
  v_row asistencias%rowtype;
begin
  if not es_rrhh() then
    raise exception 'No autorizado';
  end if;
  if v_tipo not in ('entrada', 'salida') then
    raise exception 'Tipo inválido';
  end if;
  if not exists (select 1 from empleados where id = p_empleado_id) then
    raise exception 'Empleado no encontrado';
  end if;

  if v_tipo = 'entrada'
     and exists (
       select 1
         from asistencias
        where empleado_id = p_empleado_id
          and entrada is not null
          and salida is null
          and entrada >= now() - interval '24 hours'
     ) then
    raise exception 'Tiene una entrada sin salida. Registre la salida primero.';
  end if;

  if v_tipo = 'entrada' then
    select * into v_row
      from asistencias
     where empleado_id = p_empleado_id and fecha = p_fecha
     for update;
    if found and v_row.entrada is not null then
      raise exception 'Ese empleado ya tiene entrada en la fecha';
    end if;

    insert into asistencias (empleado_id, fecha, entrada, metodo_entrada, nota, created_by)
    values (p_empleado_id, p_fecha, p_hora, 'manual', p_nota, auth.uid())
    on conflict (empleado_id, fecha) do update
      set entrada = excluded.entrada,
          metodo_entrada = 'manual',
          nota = coalesce(excluded.nota, asistencias.nota),
          created_by = auth.uid(),
          updated_at = now()
      where asistencias.entrada is null;
    if not found then
      raise exception 'Ese empleado ya tiene entrada en la fecha';
    end if;
  else
    select * into v_row
      from asistencias
     where empleado_id = p_empleado_id and fecha = p_fecha
     for update;
    if not found or v_row.entrada is null then
      raise exception 'Primero registre la entrada';
    end if;
    if v_row.salida is not null then
      raise exception 'Ese empleado ya tiene salida en la fecha';
    end if;
    if p_hora < v_row.entrada then
      raise exception 'La salida no puede ser anterior a la entrada';
    end if;

    update asistencias
       set salida = p_hora,
           metodo_salida = 'manual',
           nota = coalesce(p_nota, nota),
           updated_at = now()
     where id = v_row.id;
  end if;
end;
$$;

create or replace function corregir_asistencia(
  p_id uuid,
  p_entrada timestamptz,
  p_salida timestamptz,
  p_nota text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  if not es_rrhh() then
    raise exception 'No autorizado';
  end if;
  if p_entrada is null and p_salida is not null then
    raise exception 'Debe indicar la entrada';
  end if;
  if p_entrada is not null and p_salida is not null and p_salida < p_entrada then
    raise exception 'La salida no puede ser anterior a la entrada';
  end if;

  update asistencias
     set entrada = p_entrada,
         salida = p_salida,
         nota = p_nota,
         updated_at = now()
   where id = p_id;
  if not found then
    raise exception 'Registro no encontrado';
  end if;
end;
$$;

alter table qr_asistencia enable row level security;
alter table asistencia_pines enable row level security;
alter table asistencias enable row level security;

drop policy if exists qr_asistencia_rrhh on qr_asistencia;
create policy qr_asistencia_rrhh on qr_asistencia for all
  using (es_rrhh()) with check (es_rrhh());

drop policy if exists asistencia_pines_rrhh on asistencia_pines;
create policy asistencia_pines_rrhh on asistencia_pines for all
  using (es_rrhh()) with check (es_rrhh());

drop policy if exists asistencias_read on asistencias;
create policy asistencias_read on asistencias for select
  using (auth.uid() is not null);

drop policy if exists asistencias_write on asistencias;
create policy asistencias_write on asistencias for all
  using (es_rrhh()) with check (es_rrhh());

revoke all on function crear_qr_asistencia(boolean) from public;
grant execute on function crear_qr_asistencia(boolean) to authenticated;
revoke all on function validar_qr_asistencia(text) from public;
grant execute on function validar_qr_asistencia(text) to anon, authenticated;
revoke all on function asignar_pin_asistencia(uuid, text) from public;
grant execute on function asignar_pin_asistencia(uuid, text) to authenticated;
revoke all on function registrar_asistencia(text, text, text, text) from public;
grant execute on function registrar_asistencia(text, text, text, text) to anon, authenticated;
revoke all on function registrar_asistencia_manual(uuid, date, text, timestamptz, text) from public;
grant execute on function registrar_asistencia_manual(uuid, date, text, timestamptz, text) to authenticated;
revoke all on function corregir_asistencia(uuid, timestamptz, timestamptz, text) from public;
grant execute on function corregir_asistencia(uuid, timestamptz, timestamptz, text) to authenticated;
