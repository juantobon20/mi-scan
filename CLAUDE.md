# CLAUDE.md

Contexto y reglas de trabajo para asistentes de IA en este repositorio. Lee `README.md` para la arquitectura, los contratos y los detalles de CI; este archivo es el resumen operativo.

## Qué es la app

Mi Scan es un escáner de documentos hecho con Flutter (Dart ^3.12, Flutter 3.44) para Android e iOS: detección de bordes en vivo con OpenCV, recorte con corrección de perspectiva y filtros, exportación a PDF de varias páginas y compartir. Es un proyecto de portafolio, así que la calidad del código, la arquitectura y las pruebas importan tanto como las funcionalidades.

Paquete `mi_scan`, id de Android `com.appinc.mi_scan`. Sin backend ni base de datos: los documentos son `nombre.pdf` más una miniatura `nombre.pdf.jpg` en el directorio de documentos de la app.

## Arquitectura (Clean Architecture)

```
presentation ──▶ domain ◀── data        core/di = composition root
```

- `lib/domain`: Dart puro (entidades, interfaces de repositorios y servicios, casos de uso). Sin Flutter ni plugins.
- `lib/data`: implementaciones (`FileDocumentRepository`, `OpenCvImageProcessor`, PDF, compartir, directorios).
- `lib/presentation`: pantallas y controladores `ChangeNotifier` (`HomeController`, `ScanSession`). Las pantallas reciben sus dependencias por constructor.
- `lib/core/di/service_locator.dart`: el único lugar que conoce las clases concretas (`get_it`). No llames a `sl` desde pantallas ni desde el dominio.
- `ScanSession` es la fachada que usan las pantallas del escáner para páginas, detección, recorte y creación del PDF.
- `Quad` guarda cuatro puntos normalizados a 0..1, ordenados arriba-izquierda, arriba-derecha, abajo-derecha, abajo-izquierda.

Brechas conocidas: `ScannerScreen` y `GalleryPickerScreen` usan `camera` y `photo_manager` directamente (sin abstraer y con poca cobertura de pruebas); `OpenCvImageProcessor` no tiene pruebas automatizadas.

## Comandos

```bash
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
dart tool/check_english.dart            # usa `dart tool/...`, no `dart run` (lento en este proyecto)
flutter test                            # pruebas unitarias + de widgets
flutter test integration_test -d <id>   # requiere simulador/dispositivo
./scripts/check_quality.sh              # analizador + changelog + verificación de inglés
./scripts/install_hooks.sh              # una vez por clon
```

## Reglas para todo cambio

1. **Solo inglés** en identificadores, textos de la interfaz, pruebas, mensajes de commit, títulos de PR, nombres de rama y workflows. `tool/check_english.dart` lo verifica. Excepción: `README.md`, `CHANGELOG.md` y este archivo están en español; mantén cada archivo en un solo idioma.
2. **Sin comentarios en el código.** Documenta el comportamiento y los contratos en `README.md` (ver "Contratos importantes"). Prefiere nombres claros a las explicaciones.
3. **Actualiza `CHANGELOG.md`** bajo `## [Sin publicar]` en todo cambio de archivos o recurso nuevo, incluido el trabajo hecho por IA. El hook de pre-commit y CI fallan si no lo haces.
4. **Agrega o actualiza pruebas** junto con el cambio. Pon los dobles de prueba en `test/helpers/fakes.dart`; usa `mocktail` solo para verificar interacciones.
5. **Respeta la regla de dependencia**: el dominio nunca importa `data`, `presentation` ni Flutter; presentation depende de interfaces del dominio.
6. **Actualiza `README.md`** cuando cambien la arquitectura, los contratos o los workflows, y este archivo cuando su contenido quede desactualizado.
7. **Los lints son estrictos**: imports sin usar, orden incorrecto de directivas y similares son errores. Comillas simples, sin `print`.

## Convenciones de git

- Ramas: `<type>/<kebab-case>` con type en `feature bugfix hotfix release chore docs refactor test ci`. El trabajo de features apunta a `develop`; `release/*` y `hotfix/*` apuntan a `main`.
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
- El build release está firmado con la clave debug; solo sirve para pruebas internas.
