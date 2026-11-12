update empleados
   set fecha_ingreso = '2026-01-01'
 where cedula <> '5221075';

insert into prestaciones_config
  (empleado_id, vigente_desde, modalidad, tipo_tasa, capitalizar_intereses)
select id, fecha_ingreso, 'contabilidad', 'pasiva', false
  from empleados
on conflict (empleado_id, vigente_desde) do nothing;

do $$
declare
  e record;
  v_n integer;
  v_cursor date;
  v_fin date;
  v_dias numeric;
begin
  for e in select id, fecha_ingreso from empleados loop
    v_n := 0;
    loop
      v_cursor := (e.fecha_ingreso + (v_n || ' years')::interval)::date;
      exit when v_cursor > current_date;
      v_fin := (v_cursor + interval '1 year' - interval '1 day')::date;
      v_dias := least(15 + v_n, 30);
      insert into vacaciones_registro
        (empleado_id, periodo_inicio, periodo_fin,
         dias_vacaciones, dias_bono, salario_normal)
      values
        (e.id, v_cursor, v_fin, v_dias, v_dias, 0)
      on conflict (empleado_id, periodo_inicio) do nothing;
      v_n := v_n + 1;
    end loop;
  end loop;
end $$;
