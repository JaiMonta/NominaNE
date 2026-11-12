update parametros_legales
   set valor = 15,
       descripcion = 'Días de bono vacacional (año 1)',
       referencia_legal = 'LOTTT Art. 192'
 where clave = 'bono_vac_dias_base';

update parametros_legales
   set valor = 30,
       descripcion = 'Máximo de días de bono vacacional',
       referencia_legal = 'LOTTT Art. 192'
 where clave = 'bono_vac_dias_max';

update parametros_legales
   set valor = 30,
       descripcion = 'Mínimo de días de utilidades (empresa privada)',
       referencia_legal = 'LOTTT Art. 131'
 where clave = 'utilidades_dias_min';

update parametros_legales
   set descripcion = 'Máximo de días de utilidades (4 meses)',
       referencia_legal = 'LOTTT Art. 131'
 where clave = 'utilidades_dias_max';

update parametros_legales
   set descripcion = 'Días de utilidades que paga la empresa (30–120)',
       referencia_legal = 'LOTTT Arts. 131 y 134'
 where clave = 'dias_utilidades_empresa';

delete from parametros_legales where clave = 'utilidades_dias_pyme';

update parametros_legales
   set referencia_legal = 'LOTTT Art. 190'
 where clave in ('vacaciones_dias_base', 'vacaciones_dia_adicional', 'vacaciones_dias_max');

update parametros_legales
   set descripcion = 'Días de vacaciones (año 1)',
       referencia_legal = 'LOTTT Art. 190'
 where clave = 'vacaciones_dias_base';

update parametros_legales
   set descripcion = 'Días adicionales de vacaciones por año',
       referencia_legal = 'LOTTT Art. 190'
 where clave = 'vacaciones_dia_adicional';

update parametros_legales
   set descripcion = 'Máximo de días de vacaciones',
       referencia_legal = 'LOTTT Art. 190'
 where clave = 'vacaciones_dias_max';

update parametros_legales
   set descripcion = 'Días de salario por mes (garantía de prestaciones)',
       referencia_legal = 'LOTTT Art. 142'
 where clave = 'antiguedad_dias_mes';

update parametros_legales
   set descripcion = 'Días adicionales por año (desde el segundo año)',
       referencia_legal = 'LOTTT Art. 142'
 where clave = 'antiguedad_dias_anual_extra';

update parametros_legales
   set descripcion = 'Tope de días adicionales por año',
       referencia_legal = 'LOTTT Art. 142'
 where clave = 'antiguedad_dias_extra_max';

insert into parametros_legales (clave, valor, descripcion, referencia_legal) values
 ('prestaciones_dias_trimestre', 15, 'Días de salario integral por trimestre iniciado', 'LOTTT Art. 142 literal a'),
 ('prestaciones_dias_anio_extra', 2, 'Días adicionales por año desde el segundo año', 'LOTTT Art. 142 literal b'),
 ('prestaciones_dias_extra_max', 30, 'Tope anual de días adicionales', 'LOTTT Art. 142 literal b'),
 ('prestaciones_retro_dias_anio', 30, 'Días por año para el cálculo retroactivo', 'LOTTT Art. 142 literal c'),
 ('prestaciones_fraccion_meses', 6, 'Meses de fracción que cuentan como año completo', 'LOTTT Art. 142 literal c'),
 ('prestaciones_meses_minimos', 3, 'Meses mínimos para el régimen general', 'LOTTT Art. 142 literal e'),
 ('prestaciones_dias_mes_menos3', 5, 'Días por mes o fracción si dura menos de 3 meses', 'LOTTT Art. 142 literal e'),
 ('salario_integral_divisor', 360, 'Divisor para alícuotas de utilidades y bono', 'LOTTT Art. 122'),
 ('utilidades_ejercicio_inicio_mes', 1, 'Mes de inicio del ejercicio fiscal (1 = enero)', 'LOTTT Art. 131')
on conflict (clave) do update
   set valor = excluded.valor,
       descripcion = excluded.descripcion,
       referencia_legal = excluded.referencia_legal;
