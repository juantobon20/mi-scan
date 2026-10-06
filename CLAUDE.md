# CLAUDE.md

Context and working rules for AI assistants in this repository. Read `README.md` for the architecture, contracts and CI details; this file is the short operational summary.

## What the app is

Mi Scan is a Flutter (Dart ^3.12, Flutter 3.44) document scanner for Android and iOS: live edge detection with OpenCV, perspective crop with filters, multi-page PDF export and sharing. It is a portfolio project, so code quality, architecture and tests matter as much as features.

Package name `mi_scan`, Android id `com.appinc.mi_scan`. No backend, no database: documents are `name.pdf` plus a `name.pdf.jpg` thumbnail in the app documents directory.

## Architecture (Clean Architecture)

```
presentation ──▶ domain ◀── data        core/di = composition root
```

- `lib/domain`: pure Dart (entities, repository and service interfaces, use cases). No Flutter, no plugins.
- `lib/data`: implementations (`FileDocumentRepository`, `OpenCvImageProcessor`, PDF, share, directories).
- `lib/presentation`: screens and `ChangeNotifier` controllers (`HomeController`, `ScanSession`). Screens receive dependencies through constructors.
- `lib/core/di/service_locator.dart`: the only place that knows concrete classes (`get_it`). Do not call `sl` from screens or domain code.
- `ScanSession` is the facade the scanner screens use for pages, detection, cropping and PDF creation.
- `Quad` holds four points normalized to 0..1 ordered top-left, top-right, bottom-right, bottom-left.

Known gaps: `ScannerScreen` and `GalleryPickerScreen` use `camera` and `photo_manager` directly (not abstracted, little test coverage); `OpenCvImageProcessor` has no automated tests.

## Commands

```bash
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
dart tool/check_english.dart            # use `dart tool/...`, not `dart run` (slow in this project)
flutter test                            # unit + widget tests
flutter test integration_test -d <id>   # needs a simulator/device
./scripts/check_quality.sh              # analyzer + changelog + English checks
./scripts/install_hooks.sh              # once per clone
```

## Rules for every change

1. **English only** for identifiers, UI strings, tests, commit messages, PR titles, branch names and workflows. `tool/check_english.dart` enforces it. Exception: `README.md`, `CHANGELOG.md` and this file may be in Spanish or English; keep each file in one language and match the language it is already written in.
2. **No code comments.** Document behavior and contracts in `README.md` instead (see "Contracts worth knowing"). Prefer clear names over explanation.
3. **Update `CHANGELOG.md`** under `## [Unreleased]` for every change to files or new resource, including AI-authored work. The pre-commit hook and CI fail otherwise.
4. **Add or update tests** with the change. Put test doubles in `test/helpers/fakes.dart`; use `mocktail` only for interaction checks.
5. **Respect the dependency rule**: domain never imports `data`, `presentation` or Flutter; presentation depends on domain interfaces.
6. **Update `README.md`** when architecture, contracts or workflows change, and this file when its content becomes stale.
7. **Lints are strict**: unused imports, wrong directive order and similar are errors. Single quotes, no `print`.

## Git conventions

- Branches: `<type>/<kebab-case>` with type in `feature bugfix hotfix release chore docs refactor test ci`. Feature work targets `develop`; `release/*` and `hotfix/*` target `main`.
- Commits and PR titles: Conventional Commits, `<type>(<scope>)?: <description>`.
- Do not commit `img.png` (a reference screenshot, git-ignored), `build/`, `.dart_tool/` or `local.properties`.
- Commit and PR attribution lines are added per the session instructions.

## CI

- `pr-validation.yml`: branch name, PR title, ASCII check, analyzer, English check, changelog.
- `ci.yml`: analyzer, English check and tests on `develop` and PRs.
- `firebase-distribution.yml`: Android release APK to Firebase App Distribution (manual or `v*` tag); needs the `FIREBASE_ANDROID_APP_ID` and `FIREBASE_SERVICE_ACCOUNT_JSON` secrets.

## Gotchas

- `opencv_dart` needs native assets; the first iOS/Android build is slow. Camera and live detection only work on a real device.
- Dart 3.12 private named parameters are used (`required this._createDocument` in `ScanSession`); callers pass `createDocument:`.
- Widget tests that touch real file I/O or image decoding need `tester.runAsync` and several short pump cycles (see `crop_screen_test.dart`).
- The release build is signed with the debug key; fine for internal testing only.
