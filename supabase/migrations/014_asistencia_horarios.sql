insert into ajustes (clave, valor, descripcion) values
  ('asistencia_diurna_entrada', '07:00', 'Entrada jornada diurna (HH:mm)'),
  ('asistencia_diurna_salida', '16:00', 'Salida jornada diurna (HH:mm)'),
  ('asistencia_nocturna_entrada', '22:00', 'Entrada jornada nocturna (HH:mm)'),
  ('asistencia_nocturna_salida', '06:00', 'Salida jornada nocturna (HH:mm)'),
  ('asistencia_mixta_entrada', '10:00', 'Entrada jornada mixta (HH:mm)'),
  ('asistencia_mixta_salida', '19:00', 'Salida jornada mixta (HH:mm)'),
  ('asistencia_tolerancia_min', '5', 'Minutos de tolerancia para contar retardo')
on conflict (clave) do nothing;

alter table asistencias add column if not exists jornada text;
alter table asistencias drop constraint if exists asistencias_jornada_check;
alter table asistencias add constraint asistencias_jornada_check
  check (jornada in ('diurna', 'nocturna', 'mixta'));

update asistencias a
   set jornada = e.jornada
  from empleados e
 where a.empleado_id = e.id
   and a.jornada is null;

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
  v_hora_local timestamp := (now() at time zone 'America/Caracas');
  v_hora timestamptz := now();
  v_tipo text := lower(trim(coalesce(p_tipo, '')));
  v_cedula text := regexp_replace(coalesce(p_cedula, ''), '\D', '', 'g');
  v_qr qr_asistencia%rowtype;
  v_emp empleados%rowtype;
  v_pin asistencia_pines%rowtype;
  v_row asistencias%rowtype;
  v_nombre text;
  v_fecha_jornada date;
  v_entrada_txt text;
  v_salida_txt text;
  v_entrada_time time;
  v_salida_time time;
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

  select valor into v_entrada_txt
    from ajustes
   where clave = 'asistencia_' || v_emp.jornada || '_entrada';
  select valor into v_salida_txt
    from ajustes
   where clave = 'asistencia_' || v_emp.jornada || '_salida';

  v_entrada_time := coalesce(
    nullif(v_entrada_txt, '')::time,
    case v_emp.jornada
      when 'nocturna' then '22:00'::time
      when 'mixta' then '10:00'::time
      else '07:00'::time
    end
  );
  v_salida_time := coalesce(
    nullif(v_salida_txt, '')::time,
    case v_emp.jornada
      when 'nocturna' then '06:00'::time
      when 'mixta' then '19:00'::time
      else '16:00'::time
    end
  );

  if v_salida_time <= v_entrada_time
     and v_hora_local::time <= v_salida_time then
    v_fecha_jornada := v_fecha - 1;
  else
    v_fecha_jornada := v_fecha;
  end if;

  if v_tipo = 'entrada' then
    select * into v_row
      from asistencias
     where empleado_id = v_emp.id and fecha = v_fecha_jornada
     for update;
    if found and v_row.entrada is not null then
      return jsonb_build_object('ok', false, 'error', 'Ya registró su entrada para ese turno');
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

    insert into asistencias
      (empleado_id, fecha, entrada, metodo_entrada, qr_entrada_id, jornada)
    values
      (v_emp.id, v_fecha_jornada, v_hora, 'qr', v_qr.id, v_emp.jornada)
    on conflict (empleado_id, fecha) do update
      set entrada = excluded.entrada,
          metodo_entrada = 'qr',
          qr_entrada_id = excluded.qr_entrada_id,
          jornada = excluded.jornada,
          updated_at = now()
      where asistencias.entrada is null;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'Ya registró su entrada para ese turno');
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
  return jsonb_build_object(
    'ok', true,
    'nombre', v_nombre,
    'tipo', v_tipo,
    'hora', v_hora,
    'fecha', v_fecha_jornada
  );
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
  v_jornada text;
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

  select jornada into v_jornada from empleados where id = p_empleado_id;

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

    insert into asistencias
      (empleado_id, fecha, entrada, metodo_entrada, nota, created_by, jornada)
    values
      (p_empleado_id, p_fecha, p_hora, 'manual', p_nota, auth.uid(), v_jornada)
    on conflict (empleado_id, fecha) do update
      set entrada = excluded.entrada,
          metodo_entrada = 'manual',
          nota = coalesce(excluded.nota, asistencias.nota),
          created_by = auth.uid(),
          jornada = excluded.jornada,
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
           jornada = coalesce(jornada, v_jornada),
           updated_at = now()
     where id = v_row.id;
  end if;
end;
$$;

revoke all on function registrar_asistencia(text, text, text, text) from public;
grant execute on function registrar_asistencia(text, text, text, text) to anon, authenticated;
revoke all on function registrar_asistencia_manual(uuid, date, text, timestamptz, text) from public;
grant execute on function registrar_asistencia_manual(uuid, date, text, timestamptz, text) to authenticated;
