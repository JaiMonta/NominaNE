# Nómina Web (Flutter Web + Supabase)

Aplicación web de nómina para Venezuela: empleados/obreros, conceptos de **ingresos y egresos**,
novedades (horas extra, bonos, préstamos, vacaciones), generación de nóminas por período,
recibos de pago y aportes patronales (IVSS, RPE, FAOV, LOPCYMAT).

## ⚠️ Antes de usarla para pagar de verdad
1. **Código no compilado ni probado**: fue escrito sin Flutter/Dart instalado. Ejecute `flutter analyze` y
   corrija lo que salga; pruebe con datos ficticios.
2. **Normativa**: la LOT adjunta (Gaceta 5.152, 1997) fue reemplazada por la LOTTT (2012). Todos los
   porcentajes y días están en la tabla `parametros_legales` (pantalla *Parámetros*); valídelos con
   un abogado laboral / contador. El salario mínimo sembrado (`130`) es un marcador: actualícelo.
3. **IVSS, RPE y FAOV** (4%/9%, 0,5%/2%, 1%/2%) **no están en los documentos adjuntos**; son valores
   de conocimiento general. Confírmelos con la normativa y los decretos vigentes.
4. No incluye: ISLR, cálculo completo de liquidación (Art. 108 y siguientes), cestaticket como
   concepto de ley, ni la generación de archivos bancarios.

## Puesta en marcha
1. Cree un proyecto en [supabase.com](https://supabase.com).
2. En *SQL Editor* ejecute `supabase/migrations/001_schema.sql`.
3. En *Authentication > Providers* deje habilitado Email (para pruebas, desactive la confirmación por correo).
4. Edite `lib/core/supabase_config.dart` con su *Project URL* y *anon key*.
5. `flutter pub get` y `flutter run -d chrome`.
6. Regístrese: **el primer usuario queda como `admin`**. Los siguientes quedan como `consulta`
   (solo lectura); cambie su rol en la tabla `perfiles` (`admin`, `rrhh`, `consulta`).
7. Publicar: `flutter build web` y suba `build/web` a cualquier hosting estático.

> Si `flutter run` indica que falta la carpeta `web`/plataforma, ejecute `flutter create . --platforms web`
> en esta carpeta (no sobrescribe `lib/`).

## Flujo de uso
Parámetros → Empleados → Novedades del período → *Generar nómina* (borrador) → revisar recibos →
*Aprobar* → *Marcar pagada*.

## Qué calcula el motor (`lib/core/payroll_engine.dart`)
| Concepto | Regla | Referencia |
|---|---|---|
| Salario diario / hora | mensual ÷ 30; diario ÷ 8 | LOT Art. 140, 195 |
| Sueldo del período | días según frecuencia | LOT Art. 150 |
| Hora extra diurna / nocturna | +50% (y +30% nocturno) | LOT Arts. 155-156 |
| Feriado / descanso trabajado | +50% | LOT Arts. 154, 217-218 |
| Vacaciones / bono vacacional | cantidad (días) × salario diario; `diasVacaciones()` y `diasBonoVacacional()` sugieren los días | LOT Arts. 219, 223 |
| Utilidades | días indicados × salario diario | LOT Arts. 174-175 |
| Cuota de préstamo | limitada a 1/3 del ingreso | LOT Art. 165 |
| IVSS / RPE / FAOV | % sobre base salarial (IVSS con tope en salarios mínimos) | externo |
| Aportes patronales | IVSS, RPE, FAOV, LOPCYMAT (0,75%–10% según riesgo) | LOPCYMAT Art. 7 |

Roles y seguridad: RLS en todas las tablas; lectura para usuarios autenticados, escritura solo `admin`/`rrhh`.
