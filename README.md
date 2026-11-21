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
   - `supabase/migrations/013_asistencia_qr.sql`
   - `supabase/migrations/014_asistencia_horarios.sql`
- `supabase/migrations/015_tope_aportes_ince.sql`
- `supabase/migrations/016_recalcular_borrar_nomina.sql`
- `supabase/migrations/017_parametros_lottt.sql`
- `supabase/migrations/018_liquidaciones_prestaciones.sql`
- `supabase/migrations/019_inicializar_liquidaciones.sql`
- `supabase/migrations/020_empleado_liquidaciones_trigger.sql`
- `supabase/migrations/021_aportes_pension_lppss.sql`
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
   También se puede elegir **tasa del día, tasa registrada o tasa manual** antes
   de generar.
6. Revisa recibos (Bs y US$), **Aprobar** y **Marcar pagada**.
7. **PDF**: botón por recibo y **PDF nómina** (multipágina). En el PDF de nómina
   se puede elegir **3 a 6 recibos por hoja** y tamaño **A4, Carta u Oficio**.
   El PDF individual de un recibo sigue siendo una hoja por recibo.

En **Generar nómina** puedes elegir **Tipo de nómina: Contratados**. Los
empleados con modalidad **Contratado** se excluyen de la nómina normal y se
pagan en una nómina semanal, quincenal o mensual (la frecuencia del empleado),
solo con su sueldo, sin deducciones ni aportes. El sueldo se prorratea según
la frecuencia igual que en la nómina normal.

Al **Aprobar** una nómina normal se eliminan las novedades **no recurrentes**
de los empleados incluidos que se solapen con el período. Las novedades
recurrentes se conservan.

Los departamentos se administran en la pestaña **Departamentos**; la ficha del
empleado toma el dato de ese catálogo.

Los conceptos marcados como **no salariales** (por ejemplo bonificaciones o
alimentación) se pagan y suman al neto, pero no entran en la base de IVSS, RPE,
FAOV ni prestaciones. En el recibo aparecen al final en la sección
**Ingreso extra (no salarial)**.

El IVSS y el RPE usan la misma base semanal: salario mensual × 12 / 52, topada
por `tope_mensual_aportes_bs` (650 Bs por defecto; equivale a 150 Bs semanales).
Se aplica por cada lunes del período: IVSS trabajador 4%, IVSS patrono 11%,
RPE trabajador 0,5% y RPE patrono 2%. Con `tope_mensual_aportes_bs = 0` se
desactiva el tope. En meses de 4/5 lunes el IVSS trabajador resulta 24/30 Bs.
El INCES patronal (2%) se incluye solo en nómina de fijos cuando hay más de 5
trabajadores fijos activos (`inces_min_trabajadores`).

La **Contribución Especial de Protección de Pensiones (LPPSS)** se calcula al
9% (`pension_patrono_pct`) sobre el total de salario y bonificaciones no
salariales del período. Es un aporte exclusivo del patrono (no se descuenta al
trabajador) y no aplica a la nómina de contratados. Por cada trabajador la base
no debe ser menor al ingreso mínimo integral: configura
`pension_base_minima_bs` con ese monto mensual (0 = sin piso); en nóminas
semanales o quincenales el piso se prorratea según la frecuencia.

## Asistencia
La pestaña **Asistencia** tiene dos vistas:

- **Día**: RRHH genera o muestra el **QR del día**, lo puede **imprimir** en
  PDF A4, asigna un **PIN de 4 a 6 dígitos** a cada empleado y puede registrar
  entradas/salidas manualmente.
- **Reporte**: resumen de días, horas y **retardos** por empleado en período
  **semanal, quincenal o mensual**, con navegación y exportación a PDF.

El empleado escanea el QR con la cámara de su teléfono; se abre una página
pública (sin login) donde ingresa **cédula + PIN** y marca **Entrada** o
**Salida**. La hora la registra el servidor en zona `America/Caracas`. El QR
vence al final del día y puede regenerarse; el anterior queda inválido.

Los horarios y la tolerancia se configuran en **Parámetros → Asistencia**:
diurna 07:00–16:00, nocturna 22:00–06:00, mixta 10:00–19:00 y tolerancia de
5 minutos por defecto. El reporte cuenta un retardo cuando la entrada supera
la hora de entrada de la jornada del empleado más la tolerancia; también suma
los minutos de retardo. En turnos nocturnos, la entrada se asocia al día de
inicio del turno, incluso si se marca después de medianoche.

Seguridad: el QR diario por sí solo no prueba presencia física (puede
compartirse). El PIN protege la identidad, se guarda con hash y se bloquea
tras 5 intentos fallidos. Para control de presencia estricto se recomienda un
kiosco en la entrada con el empleado marcando allí; el registro manual de RRHH
queda siempre como respaldo.

## Reporte de nómina
La pestaña **Reporte nómina** agrupa las nóminas **aprobadas y pagadas** por
período **semanal, mensual, trimestral, semestral o anual**. Incluye el resumen
de ingresos, egresos, neto y aportes patronales (IVSS, RPE, FAOV, LOPCYMAT e
INCES), el detalle de todos los conceptos por empleado y exportación a
**PDF detallado** y **CSV**. Se filtra por el período de cierre (`periodo_fin`).

## Recalcular y eliminar nóminas
En una nómina **aprobada y aún no pagada** se puede:

- **Recalcular** con una tasa del día, una tasa registrada o una tasa manual.
  La misma nómina se reemplaza con los nuevos montos en Bs/USD; se conserva el
  estado aprobado y se actualizan PDF, recibos y reportes.
- **Eliminar** la nómina y sus recibos antes de pagarla.
- Consultar el **historial de recálculos** (tasa anterior/nueva y fechas).

Las novedades no recurrentes aplicadas a una nómina se marcan como consumidas y
se restauran si la nómina se elimina. Las que ya se habían eliminado antes de la
migración 016 no se pueden recuperar. Las nóminas pagadas no se recalculan ni se
eliminan.

## Liquidaciones
La pestaña **Liquidaciones** incluye:

- **Liquidar**: calcula prestaciones (garantía + intereses vs retroactivo),
  vacaciones y bono pendientes/fraccionados, utilidades fraccionadas,
  indemnización Art. 92 cuando corresponda, salario pendiente y deducciones.
- **Prestaciones**: saldo inicial, movimientos de garantía/días adicionales,
  anticipos, pagos, ajustes y generación de intereses mensuales con tasas BCV.
- **Vacaciones**: períodos generados desde la fecha de ingreso, días
  disfrutados/pagados y saldos pendientes.
- **Tasas de interés**: carga mensual de tasas activa, pasiva, promedio y
  rendimiento de fideicomiso.

Al aprobar una liquidación el trabajador queda inactivo con su fecha y motivo
de egreso. El PDF incluye el comparativo garantía/retroactivo y el detalle de
cada concepto con su base legal.

La migración 017 corrige los parámetros a la LOTTT: bono vacacional 15 días
(hasta 30), utilidades mínimo 30 días y referencias legales actualizadas. Las
prestaciones usan salario integral; vacaciones, bono y utilidades usan salario
normal.

## Despliegue (Firebase Hosting)
```
flutter build web --release
firebase deploy --only hosting
```
`firebase.json` sirve `build/web` con rewrite SPA.

## Validación rápida
- [ ] Migraciones 001 a 021 aplicadas.
- [ ] Dominio de Firebase agregado en Supabase Auth.
- [ ] Tasa BCV del día cargada en *Tasas*.
- [ ] Nombre/RIF de la empresa en *Parámetros*.
- [ ] Generar nómina y verificar neto en Bs y US$.
- [ ] Descargar PDF de recibo y de nómina.
- [ ] Asignar PIN de asistencia y probar el QR con un teléfono.
- [ ] Verificar los reportes semanal, quincenal y mensual, y su PDF.
- [ ] Verificar el reporte de nómina por período, su PDF y su CSV.

## Aviso legal
La LOT adjunta (1997) fue reemplazada por la LOTTT (2012); los porcentajes de
IVSS/RPE/FAOV no provienen de los documentos adjuntos. Valida cada parámetro con
un abogado laboral/contador antes de pagar.
