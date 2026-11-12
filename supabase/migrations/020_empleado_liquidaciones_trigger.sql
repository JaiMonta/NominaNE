create or replace function inicializar_empleado_liquidaciones()
returns trigger
language plpgsql
as $$
begin
  insert into prestaciones_config
    (empleado_id, vigente_desde, modalidad, tipo_tasa, capitalizar_intereses)
  values
    (new.id, new.fecha_ingreso, 'contabilidad', 'pasiva', false)
  on conflict (empleado_id, vigente_desde) do nothing;

  insert into vacaciones_registro
    (empleado_id, periodo_inicio, periodo_fin,
     dias_vacaciones, dias_bono, salario_normal)
  values
    (new.id, new.fecha_ingreso,
     (new.fecha_ingreso + interval '1 year' - interval '1 day')::date,
     15, 15, 0)
  on conflict (empleado_id, periodo_inicio) do nothing;

  return new;
end;
$$;

drop trigger if exists empleados_liquidaciones_trigger on empleados;
create trigger empleados_liquidaciones_trigger
after insert on empleados
for each row execute function inicializar_empleado_liquidaciones();
