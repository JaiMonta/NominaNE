update parametros_legales
   set valor = 0,
       descripcion = 'Tope de cotización IVSS en salarios mínimos (0 = sin tope)'
 where clave = 'ivss_tope_salarios_min';

update parametros_legales
   set valor = 0.11,
       descripcion = 'Seguro Social Obligatorio - aporte patrono (riesgo máximo)'
 where clave = 'ivss_patrono_pct';
