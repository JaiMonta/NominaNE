# NóminaNE

Aplicación web de nómina para Venezuela (Flutter Web + Supabase): empleados/obreros,
conceptos de ingresos y egresos, novedades, generación de nóminas por período,
recibos de pago en USD y Bolívares (VES) a la tasa del BCV, y aportes patronales
(IVSS, RPE, FAOV, LOPCYMAT).

## Moneda
- Los montos base se guardan en **USD** (salario del empleado, montos de novedades y
  valores fijos de conceptos).
- Al **generar la nómina** se convierten a **Bolívares (VES)** con la **tasa BCV** de
  la fecha de cierre, cargada manualmente en la pestaña **Tasas**. La tasa queda
  congelada en la nómina y los recibos guardan el equivalente en ambas monedas.

## Puesta en marcha
1. Crea un proyecto en https://supabase.com.
2. En el *SQL Editor* ejecuta, en orden:
   - `supabase/migrations/001_schema.sql`
   - `supabase/migrations/002_usd_tasas.sql`
   - `supabase/migrations/003_ajustes.sql`
   - `supabase/migrations/004_aportes_patronales.sql`
   - `supabase/migrations/005_recibo_detalle_es_salarial.sql`
   - `supabase/migrations/006_ivss_sin_tope.sql`
   - `supabase/migrations/007_empleados_fecha_nacimiento_telefono.sql`
   - `supabase/migrations/008_departamentos.sql`
   - `supabase/migrations/009_ajustes_empresa_publica.sql`
   - `supabase/migrations/010_ivss_tope_semanal.sql`
   - `supabase/migrations/011_modalidad_nomina.sql`
   - `supabase/migrations/012_aprobar_nomina_limpia_novedades.sql`
3. En *Authentication → URL Configuration* agrega tu dominio (ej.
   `https://nomina-ne.web.app`) en **Site URL** y **Additional Redirect URLs**.
   Para pruebas, en *Authentication → Providers → Email* puedes desactivar la
   confirmación por correo.
4. Edita `lib/core/supabase_config.dart` con tu *Project URL* y *anon key*.
5. `flutter pub get` y `flutter run -d chrome`.
6. Regístrate: **el primer usuario queda como `admin`**. Los siguientes quedan como
   `consulta`; cambia su rol en la tabla `perfiles` (`admin`, `rrhh`, `consulta`).

## Uso
1. **Tasas**: registra la tasa BCV del día (Bs por USD). Sin tasa no se puede generar nómina.
2. **Parámetros**: revisa los parámetros legales y la sección **Empresa** (nombre/RIF para el PDF).
3. **Empleados**: carga empleados con salario mensual en **USD**.
4. **Conceptos** y **Novedades** del período (montos en USD).
5. **Nóminas → Generar nómina**: calcula en VES a la tasa del cierre (borrador).
6. Revisa recibos (Bs y US$), **Aprobar** y **Marcar pagada**.
7. **PDF**: botón por recibo y **PDF nómina** (multipágina). Descarga directa.

En **Generar nómina** puedes elegir **Tipo de nómina: Contratados**. Los
empleados con modalidad **Contratado** se excluyen de la nómina normal y se
pagan en una nómina mensual solo con su sueldo, sin deducciones ni aportes.

Al **Aprobar** una nómina normal se eliminan las novedades **no recurrentes**
de los empleados incluidos que se solapen con el período. Las novedades
recurrentes se conservan.

Los departamentos se administran en la pestaña **Departamentos**; la ficha del
empleado toma el dato de ese catálogo.

Los conceptos marcados como **no salariales** (por ejemplo bonificaciones o
alimentación) se pagan y suman al neto, pero no entran en la base de IVSS, RPE,
FAOV ni prestaciones. En el recibo aparecen al final en la sección
**Ingreso extra (no salarial)**.

El IVSS se calcula con la retención semanal: salario mensual × 12 / 52 × 4% por
cada lunes del período, con un tope mensual de 5 salarios mínimos
(`ivss_tope_salarios_min = 5`, `salario_minimo_mensual` en Bs). El aporte
patronal usa la misma base semanal y los mismos lunes, al 11% (riesgo máximo).
Con `ivss_tope_salarios_min = 0` se desactiva el tope.

## Despliegue (Firebase Hosting)
```
flutter build web --release
firebase deploy --only hosting
```
`firebase.json` sirve `build/web` con rewrite SPA.

## Validación rápida
- [ ] Migraciones 001 a 012 aplicadas.
- [ ] Dominio de Firebase agregado en Supabase Auth.
- [ ] Tasa BCV del día cargada en *Tasas*.
- [ ] Nombre/RIF de la empresa en *Parámetros*.
- [ ] Generar nómina y verificar neto en Bs y US$.
- [ ] Descargar PDF de recibo y de nómina.

## Aviso legal
La LOT adjunta (1997) fue reemplazada por la LOTTT (2012); los porcentajes de
IVSS/RPE/FAOV no provienen de los documentos adjuntos. Valida cada parámetro con
un abogado laboral/contador antes de pagar.
