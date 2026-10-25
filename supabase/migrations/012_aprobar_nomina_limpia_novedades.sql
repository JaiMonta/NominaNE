create or replace function aprobar_nomina(p_nomina_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_inicio date;
  v_fin date;
  v_modalidad text;
  v_eliminadas integer := 0;
begin
  if not es_rrhh() then
    raise exception 'No autorizado';
  end if;

  select periodo_inicio, periodo_fin, modalidad_nomina
    into v_inicio, v_fin, v_modalidad
    from nominas
   where id = p_nomina_id
     and estado = 'borrador'
     for update;

  if not found then
    raise exception 'Nomina no encontrada o no esta en borrador';
  end if;

  if v_modalidad = 'normal' then
    delete from novedades n
     using recibos r
     where r.nomina_id = p_nomina_id
       and n.empleado_id = r.empleado_id
       and n.periodo_inicio is not null
       and n.periodo_inicio <= v_fin
       and coalesce(n.periodo_fin, n.periodo_inicio) >= v_inicio;
    get diagnostics v_eliminadas = row_count;
  end if;

  update nominas set estado = 'aprobada' where id = p_nomina_id;
  return v_eliminadas;
end;
$$;
