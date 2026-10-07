# CLAUDE.md

Contexto y reglas de trabajo para asistentes de IA en este repositorio. Lee `README.md` para la arquitectura, los contratos y los detalles de CI; este archivo es el resumen operativo.

## Qué es la app

Mi Scan es un escáner de documentos hecho con Flutter (Dart ^3.12, Flutter 3.44) para Android e iOS: detección de bordes en vivo con OpenCV, recorte con corrección de perspectiva y filtros, exportación a PDF de varias páginas y compartir. Es un proyecto de portafolio, así que la calidad del código, la arquitectura y las pruebas importan tanto como las funcionalidades.

Paquete `mi_scan`, id de Android `com.appinc.mi_scan`. Sin backend: los PDFs (`nombre.pdf` más una miniatura `nombre.pdf.jpg`) están en el directorio de documentos de la app y sus metadatos (carpetas, páginas, fechas) en SQLite (`mi_scan.db`, vía `sqflite`).

## Arquitectura (Clean Architecture)

```
presentation ──▶ domain ◀── data        core/di = composition root
```

- `lib/domain`: Dart puro (entidades, interfaces de repositorios y servicios, casos de uso). Sin Flutter ni plugins.
- `lib/data`: implementaciones (`SqliteDocumentRepository`, `SqliteFolderRepository`, `AppDatabase`, `DocumentFiles`, `OpenCvImageProcessor`, PDF, compartir, directorios).
- `lib/presentation`: pantallas y controladores `ChangeNotifier` (`HomeController`, `ScanSession`). Las pantallas reciben sus dependencias por constructor.
- `lib/core/di/service_locator.dart`: el único lugar que conoce las clases concretas (`get_it`). No llames a `sl` desde pantallas ni desde el dominio.
- `ScanSession` es la fachada que usan las pantallas del escáner para páginas, detección, recorte y creación del PDF.
- `Quad` guarda cuatro puntos normalizados a 0..1, ordenados arriba-izquierda, arriba-derecha, abajo-derecha, abajo-izquierda.

La cámara y la galería están detrás de `CameraService`/`CameraSession` y `GalleryService` (domain); las implementaciones con plugins viven en `lib/data/services/` y las pantallas usan `ScannerController`/`GalleryController` creados por `ScreenFactory`. El escáner solo usa cámaras traseras y cambia de lente según el zoom (nunca hay botones de lente ni cámara frontal). Brechas conocidas: la detección de bordes de `OpenCvImageProcessor`, `PluginCameraSession` y `PhotoManagerGalleryService` no tienen pruebas automatizadas (se validan en un teléfono); los filtros de OpenCV sí se prueban en el simulador con `integration_test/opencv_filters_test.dart`.

- Cambios de esquema: sube `AppDatabase.schemaVersion`, agrega la migración en `onUpgrade` y pruébala con una base creada con el esquema anterior. Los repositorios SQLite se prueban con `sqflite_common_ffi` (`test/helpers/sqlite_helpers.dart`) y con el plugin real en `integration_test/storage_test.dart`.

## Comandos

```bash
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
dart tool/check_english.dart            # usa `dart tool/...`, no `dart run` (lento en este proyecto)
flutter test                            # pruebas unitarias + de widgets
flutter test integration_test -d <id>   # requiere simulador/dispositivo
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d <id>
./scripts/check_quality.sh              # analizador + changelog + verificación de inglés
./scripts/install_hooks.sh              # una vez por clon
```

## Reglas para todo cambio

1. **Solo inglés** en identificadores, pruebas, mensajes de commit, títulos de PR, nombres de rama y workflows. `tool/check_english.dart` lo verifica. Excepciones: `lib/l10n/` (traducciones al español de la interfaz) y todos los archivos `.md` (`README.md`, `CHANGELOG.md`, este archivo y la plantilla de PR) están en español; mantén cada archivo en un solo idioma. Si una prueba necesita caracteres con acento (por ejemplo las de la búsqueda sin acentos), escríbelos como escapes Unicode (`\u00e1`) para no romper la regla.
2. **Sin comentarios en el código.** Documenta el comportamiento y los contratos en `README.md` (ver "Contratos importantes"). Prefiere nombres claros a las explicaciones.
3. **Actualiza `CHANGELOG.md`** bajo `## [Sin publicar]` en todo cambio de archivos o recurso nuevo, incluido el trabajo hecho por IA. El hook de pre-commit y CI fallan si no lo haces.
4. **Agrega o actualiza pruebas** junto con el cambio. Pon los dobles de prueba en `test/helpers/fakes.dart`; usa `mocktail` solo para verificar interacciones.
5. **Respeta la regla de dependencia**: el dominio nunca importa `data`, `presentation` ni Flutter; presentation depende de interfaces del dominio.
6. **Actualiza `README.md`** cuando cambien la arquitectura, los contratos o los workflows, y este archivo cuando su contenido quede desactualizado.
7. **Textos visibles solo vía localización**: agrega la clave en `lib/l10n/app_en.arb` y `app_es.arb`, ejecuta `flutter gen-l10n`, commitea los archivos generados y usa `context.l10n`. Nunca escribas textos de UI en los widgets. Con idioma distinto de `es` la app usa inglés.
8. **Los lints son estrictos**: imports sin usar, orden incorrecto de directivas y similares son errores. Comillas simples, sin `print`.

## Convenciones de git

- Ramas: GitFlow simplificado (`main` + `develop` protegidas, ramas de vida corta). Detalle y reglas de protección en el README, sección "Estrategia de ramas". Nombre `<type>/<kebab-case>` con type en `feature bugfix hotfix release chore docs refactor test ci`; las de trabajo salen de `develop` y vuelven a `develop` con squash; `release/*` y `hotfix/*` apuntan a `main` con merge commit, seguidos de un back-merge `main → develop`.
- Solo el dueño del repositorio integra y aprueba PRs en `main` y `develop` (ver `.github/rulesets/` y `.github/CODEOWNERS`). No integres PRs ni cambies las reglas de protección por tu cuenta.
- Nunca hagas push directo a `main` ni a `develop`, ni crees tags `v*` sin que lo pida el usuario (un tag publica en Firebase).
- Commits y títulos de PR: Conventional Commits, `<type>(<scope>)?: <description>`, en inglés.
- No hagas commit de `img.png` (captura de referencia ignorada por git), `build/`, `.dart_tool/` ni `local.properties`.
- Las líneas de atribución de commits y PRs se agregan según las instrucciones de la sesión.

## CI

- `pr-validation.yml`: nombre de rama, título del PR, verificación ASCII, analizador, verificación de inglés y changelog.
- `ci.yml`: analizador, verificación de inglés y pruebas en `develop` y en PRs.
- `firebase-distribution.yml`: APK release de Android a Firebase App Distribution (manual o tag `v*`); requiere los secretos `FIREBASE_ANDROID_APP_ID` y `FIREBASE_SERVICE_ACCOUNT_JSON`.

## Detalles a tener en cuenta

- `opencv_dart` necesita assets nativos; el primer build de iOS/Android es lento. La cámara y la detección en vivo solo funcionan en un dispositivo real.
- Se usan los parámetros nombrados privados de Dart 3.12 (`required this._createDocument` en `ScanSession`); quien llama pasa `createDocument:`.
- Las pruebas de widgets que tocan E/S de archivos reales o decodificación de imágenes necesitan `tester.runAsync` y varios ciclos cortos de `pump` (ver `crop_screen_test.dart`).
- La firma de release sale de variables de entorno o `android/key.properties`; sin ellas el build local usa la clave debug. Nunca imprimas, commitees ni pidas en el chat el keystore, las contraseñas ni el token. Los secretos de distribución viven en el environment `release` de GitHub.
