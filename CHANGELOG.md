# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/). See the "Changelog policy" section of the README for the rules every change must follow.

## [Unreleased]

### Added
- `CHANGELOG.md` and a changelog policy enforced by the pre-commit hook (`scripts/check_changelog.sh`) and by the `PR validation` workflow.
- `CLAUDE.md` with the project context and working rules for AI assistants.

### Changed
- `tool/check_english.dart` now also checks `CHANGELOG.md` and `CLAUDE.md`.

## [1.0.0] - 2026-10-06

### Added
- Document scanner with live edge detection (OpenCV, Canny + contours) running in an isolate.
- Gallery import with multi-selection (HEIC converted to JPEG on iOS).
- Crop editor with draggable corners, automatic detection and filters: Original, Enhanced, Grayscale, Black & White.
- Page review: reorder, rotate, delete and add pages.
- Multi-page PDF generation with thumbnail; share, rename and delete saved documents.
- Material 3 light and dark themes.
- Clean architecture (domain, data, presentation) with `get_it` dependency injection.
- Unit, widget and integration test suites.
- Strict analyzer rules, English-only check (`tool/check_english.dart`) and Git hooks (`.githooks/`).
- GitHub Actions: PR validation, CI on `develop` and Firebase App Distribution for Android.

### Changed
- UI strings, identifiers, tests and documentation are in English; in-code comments were removed in favor of the README.
