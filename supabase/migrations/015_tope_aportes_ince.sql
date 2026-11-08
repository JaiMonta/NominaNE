insert into parametros_legales (clave, valor, descripcion, referencia_legal) values
  ('tope_mensual_aportes_bs', 650, 'Tope mensual de la base de IVSS y RPE en Bs. El tope semanal se obtiene multiplicando por 12/52', 'Ley del Seguro Social / Ley RPE'),
  ('inces_patrono_pct', 0.02, 'Aporte patronal INCES (2%)', 'Ley del INCES'),
  ('inces_min_trabajadores', 5, 'Se aplica INCES con más de este número de trabajadores fijos activos', 'Ley del INCES')
on conflict (clave) do nothing;

update parametros_legales
   set descripcion = 'Referencia de tope en salarios mínimos (el cálculo usa tope_mensual_aportes_bs)'
 where clave = 'ivss_tope_salarios_min';

alter table recibos
  add column if not exists aporte_ince_patronal numeric(14,2) not null default 0;

alter table nominas
  add column if not exists total_aporte_ince numeric(16,2) not null default 0;
