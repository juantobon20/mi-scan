# Changelog

Todos los cambios relevantes de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa [Versionado Semántico](https://semver.org/lang/es/). Consulta la sección "Política de changelog" del README para conocer las reglas que debe seguir todo cambio.

## [Sin publicar]

### Añadido
- `CHANGELOG.md` y una política de changelog aplicada por el hook de pre-commit (`scripts/check_changelog.sh`) y por el workflow `PR validation`.
- `CLAUDE.md` con el contexto del proyecto y las reglas de trabajo para asistentes de IA.
- Estrategia de ramas (GitFlow simplificado), flujos de trabajo, release y hotfix, y reglas de protección de ramas y tags en el README.
- Reglas de protección como código (`.github/rulesets/`), `.github/CODEOWNERS` y `scripts/apply_github_rules.sh`: solo el dueño del repositorio puede integrar en `main` y `develop`, y los tags `v*` están protegidos.

### Cambiado
- `pr-validation.yml` permite el PR de back-merge `main → develop`.
- `firebase-distribution.yml` rechaza tags `v*` que no estén en `main`.
- Todos los archivos `.md` (`README.md`, `CHANGELOG.md`, `CLAUDE.md` y la plantilla de PR) están en español y `tool/check_english.dart` ya no los revisa.

## [1.0.0] - 2026-10-06

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
- GitHub Actions: validación de PR, CI en `develop` y Firebase App Distribution para Android.

### Cambiado
- Los textos de la interfaz, identificadores y pruebas están en inglés; se eliminaron los comentarios del código a favor del README.
