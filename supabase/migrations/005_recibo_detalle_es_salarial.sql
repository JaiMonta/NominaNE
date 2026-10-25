-- =====================================================================
-- NóminaNE — Marca de concepto salarial en el detalle del recibo
-- Permite separar en el recibo los ingresos no salariales (bonificaciones,
-- alimentación, etc.) y mostrarlos al final como "ingreso extra".
-- Requiere haber ejecutado antes 001..004.
-- =====================================================================

alter table recibo_detalle
  add column if not exists es_salarial boolean not null default true;

-- Rellenar recibos históricos según la definición actual del concepto.
update recibo_detalle d
   set es_salarial = c.es_salarial
  from conceptos c
 where c.codigo = d.concepto_codigo;

comment on column recibo_detalle.es_salarial is
  'false = ingreso no salarial: suma al neto pero no a la base de aportes/prestaciones';
