# Guía rápida de clonación

Proyecto: **Sistema de Nómina** (Flutter Web + Supabase + Firebase Hosting).

## Requisitos

- Git
- Flutter 3.x (en este proyecto se usa 3.47.5)
- Google Chrome
- Opcional para desplegar: Node.js/npm y Firebase CLI

Comprobar Flutter:

```powershell
flutter --version
flutter doctor
```

## 1. Clonar el repositorio

El repositorio es público:

```powershell
git clone https://github.com/JaiMonta/NominaNE.git
cd NominaNE
```

## 2. Instalar dependencias

```powershell
flutter pub get
```

## 3. Ejecutar la app

```powershell
flutter run -d chrome
```

La app usa el Supabase existente: `lib/core/supabase_config.dart` ya contiene la
URL y la anon key. No hace falta configurar variables de entorno para probar.

## 4. Ejecutar pruebas

```powershell
flutter test
flutter analyze
```

## 5. Compilar y desplegar (opcional)

```powershell
flutter build web --release
npm install -g firebase-tools   # solo si no está instalado
firebase login
firebase deploy --only hosting --project nomina-ne
```

Sitio publicado: https://nomina-ne.web.app

## Notas

- Usa la **raíz** del repositorio (`NominaNE`). No uses `nomina_app/` ni
  `nomina_app.zip`: son una copia antigua.
- La base de datos de producción ya está migrada. Las migraciones
  `supabase/migrations/001…010` solo son necesarias si se crea un Supabase nuevo.
- La anon key es pública por diseño; la seguridad la dan las políticas RLS.
  La contraseña de la base de datos no está en el repositorio.
- Para hacer `push` se necesita acceso al repositorio con una cuenta de GitHub.
  Para solo clonar y ejecutar no hace falta.
- Si `flutter` no se reconoce, agrega la carpeta `bin` de Flutter al `PATH` y
  reinicia la terminal.
- Si aparece un bloqueo de Flutter (`Waiting for another flutter command...`),
  cierra las otras terminales/IDE que estén usando Flutter y reintenta.

## Problemas frecuentes

| Problema | Solución |
|---|---|
| `flutter` no se reconoce | Agregar Flutter al `PATH` y reiniciar la terminal |
| Error de dependencias | `flutter clean` y luego `flutter pub get` |
| No abre Chrome | Verificar que Chrome esté instalado; probar `flutter devices` |
| Error al desplegar | Ejecutar `firebase login` y confirmar acceso al proyecto `nomina-ne` |
