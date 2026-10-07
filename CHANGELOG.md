# Changelog

Todos los cambios relevantes de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa [Versionado Semántico](https://semver.org/lang/es/). Consulta la sección "Política de changelog" del README para conocer las reglas que debe seguir todo cambio.

## [Sin publicar]

### Añadido
- `firebase-distribution.yml` verifica con `scripts/check_release_version.sh` que la versión del tag `vX.Y.Z` coincida con `pubspec.yaml` y que `CHANGELOG.md` tenga la sección `[X.Y.Z]`, para no publicar un APK de otra versión por un tag mal ubicado.

## [1.1.0] - 2026-10-06

### Añadido
- La app soporta inglés y español: usa español si el idioma del dispositivo es `es` (incluidas variantes) y inglés en cualquier otro caso. Textos en `lib/l10n/*.arb` generados con `flutter gen-l10n`, extensión `context.l10n` y pruebas de localización (claves, placeholders, plurales y resolución de idioma).
- Las notas de cada versión en Firebase App Distribution se generan automáticamente desde `CHANGELOG.md` con `scripts/release_notes.sh` (tag `vX.Y.Z` o versión de `pubspec.yaml`); en ejecuciones manuales se pueden sobrescribir.
- El README documenta la convención de títulos de PR y commits, con los tipos, las reglas, ejemplos válidos e inválidos y el patrón exacto.
- El README explica cómo manejar los arreglos durante la estabilización de una release: se corrigen solo en la rama de release, sin traer `develop`, y se propagan con el back-merge `main → develop`.
- El job `CI` verifica que los archivos de localización generados estén al día.
- `ios/Runner/Info.plist` declara `en` y `es` en `CFBundleLocalizations`, necesario para que iOS entregue el idioma español a la app.

### Cambiado
- `PR validation` cancela las ejecuciones anteriores del mismo PR mediante un grupo de `concurrency`.
- Los textos de la interfaz ya no están escritos en los widgets: se leen de los archivos ARB. `ScanFilter` ya no tiene etiqueta (se resuelve en presentación) y `formatDocSubtitle` usa el idioma activo para fecha y decimales.
- `tool/check_english.dart` no revisa `lib/l10n/`, donde es legítimo el español.
- El README ya no incluye los pasos para crear el keystore, probar la firma en local ni subir los secretos, porque están configurados; se conserva la descripción del flujo y los nombres de los secretos.
- El README describe que el workflow verifica la firma con `apksigner`.
- El README ya no documenta la protección de ramas ni los scripts de instalación de hooks, calidad y reglas de GitHub; las ramas ya están protegidas y los hooks se activan con `git config core.hooksPath .githooks`.
- `.gitignore` ignora las capturas locales `img*.png` de la raíz del repositorio.

## [1.0.0] - 2026-10-06

Primera versión publicada.

### Añadido
- Escáner de documentos con detección de bordes en vivo (OpenCV, Canny + contornos) ejecutada en un isolate.
- Importación desde la galería con selección múltiple (HEIC se convierte a JPEG en iOS).
- Editor de recorte con esquinas arrastrables, detección automática y filtros: Original, Enhanced, Grayscale, B&W.
- Revisión de páginas: reordenar, rotar, eliminar y agregar páginas.
- Generación de PDF de varias páginas con miniatura; compartir, renombrar y eliminar documentos guardados.
- Temas claro y oscuro Material 3.
- Clean Architecture (domain, data, presentation) con inyección de dependencias mediante `get_it`.
- Suites de pruebas unitarias, de widgets y de integración.
- Reglas estrictas del analizador, verificación de solo inglés (`tool/check_english.dart`) y Git hooks (`.githooks/`).
- `CHANGELOG.md` y una política de changelog aplicada por el hook de pre-commit (`scripts/check_changelog.sh`) y por el workflow `PR validation`.
- `CLAUDE.md` con el contexto del proyecto y las reglas de trabajo para asistentes de IA.
- Estrategia de ramas (GitFlow simplificado), flujos de trabajo, release y hotfix, y reglas de protección de ramas y tags en el README.
- Reglas de protección como código (`.github/rulesets/`), `.github/CODEOWNERS` y `scripts/apply_github_rules.sh`: solo el dueño del repositorio puede integrar en `main` y `develop`, y los tags `v*` están protegidos.
- GitHub Actions: validación de PR, CI en `develop` y Firebase App Distribution para Android; el workflow rechaza tags `v*` que no estén en `main` y permite el PR de back-merge `main → develop`.
- Firma de release de Android sin credenciales en el código: `android/app/build.gradle.kts` lee el keystore de variables de entorno o de `android/key.properties`, y `firebase-distribution.yml` lo restaura desde secretos del environment `release`, valida que el APK no esté firmado con la clave debug y borra el keystore al terminar.

### Cambiado
- Los textos de la interfaz, identificadores y pruebas están en inglés; se eliminaron los comentarios del código a favor del README.
- Todos los archivos `.md` (`README.md`, `CHANGELOG.md`, `CLAUDE.md` y la plantilla de PR) están en español y `tool/check_english.dart` ya no los revisa.

### Seguridad
- Se ignoran `*.jks`, `*.keystore` y `key.properties` también en la raíz del repositorio, y la clave de firma ya no está en el código.
