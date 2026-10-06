# Mi Scan

A document scanner for Android and iOS built with Flutter. It detects document edges live with OpenCV, corrects perspective, applies filters and produces multi-page PDFs that can be shared.

> Portfolio project: beyond the features, the focus is **clean architecture, dependency injection and a test suite** (unit, widget and integration).

## Features

- Camera with **live edge detection** (Canny + contours, run in an isolate).
- Import from the **gallery** with multi-selection (HEIC is converted to JPEG on iOS).
- Crop editor with draggable corners, automatic detection and **filters**: Original, Enhanced, Grayscale, Black & White (adaptive threshold).
- Page review: reorder, rotate, delete, add more.
- **PDF** generation (A4, portrait or landscape depending on the image) with a thumbnail.
- Document list: share, rename (name collisions are resolved) and delete.
- Material 3 light/dark theme.

## Stack

| Area | Package |
|---|---|
| Camera | `camera` |
| Computer vision | `opencv_dart` |
| PDF | `pdf` |
| Gallery | `photo_manager` |
| Sharing | `share_plus` |
| Storage | `path_provider`, `path` |
| Dependency injection | `get_it` |
| Testing | `flutter_test`, `mocktail`, `integration_test` |

State management: `ChangeNotifier` + `ListenableBuilder` (no extra library; enough for the size of the app).

## Architecture

Clean Architecture in three layers. The dependency rule always points towards the domain.

```
        presentation ───────▶ domain ◀─────── data
   (widgets, controllers)   (pure Dart)   (plugins, disk, OpenCV)
                               ▲
                core/di  (composition root: the only place that
                          knows the concrete implementations)
```

```
lib/
├── main.dart                     # entry point: configureDependencies() + runApp
├── app.dart                      # MaterialApp, themes, home screen
├── core/
│   ├── di/service_locator.dart   # dependency registration (get_it)
│   ├── theme/app_theme.dart
│   └── utils/formatters.dart     # date/size formatting, file names, silentDelete
├── domain/                       # pure Dart, no Flutter or plugins
│   ├── entities/                 # Quad, ScanPage, ScanFilter, ScannedDocument, GrayFrame
│   ├── repositories/             # DocumentRepository (interface)
│   ├── services/                 # ImageProcessor, PdfGenerator, ThumbnailGenerator,
│   │                             # ShareService, SessionStorage (interfaces)
│   └── usecases/                 # ListDocuments, CreateDocument, RenameDocument, DeleteDocument
├── data/
│   ├── repositories/file_document_repository.dart   # PDFs on disk + thumbnails
│   └── services/                 # OpenCvImageProcessor, PdfPackageGenerator,
│                                 # UiThumbnailGenerator, SharePlusService,
│                                 # PathProviderDirectories, FileSessionStorage
└── presentation/
    ├── home/                     # HomeScreen + HomeController
    ├── scanner/                  # ScannerScreen, ScanSession, frame_converter
    ├── crop/                     # CropScreen (corner editor and filters)
    ├── review/                   # ReviewScreen (pages of the session)
    ├── gallery/                  # GalleryPickerScreen
    └── widgets/                  # QuadPainter, name dialog, PDF saving
```

### Capture flow

```
ScannerScreen ──takePicture──▶ ScanSession.importSource ──▶ ImageProcessor.normalize
      │                                                          (JPEG, max 3000 px)
      ▼
CropScreen ──detectInFile──▶ ImageProcessor.detectInFile ──▶ Quad
      │  (user adjusts corners and filter)
      ▼
ScanSession.cropPage ──▶ ImageProcessor.crop (perspective + filter) ──▶ ScanPage
      ▼
ScanSession.saveAsPdf ──▶ CreateDocument ──▶ DocumentRepository ──▶ PdfGenerator + ThumbnailGenerator
```

### Design decisions

- **`ScanSession` as presentation facade.** It holds the pages of an ongoing scan and is the only entry point from the screens to the domain. Screens receive just the session, which keeps wiring small and makes it easy to replace in tests.
- **The domain knows no plugins.** `Quad` relies on `dart:math`; the geometry (corner ordering, convexity, temporal smoothing) is pure logic and is tested without a device.
- **OpenCV isolated behind `ImageProcessor`.** The app logic is tested with a double. Only primitive types (`List<double>`, paths) cross the isolate boundary.
- **Heavy work off the UI thread.** Detection and filters use `compute`; live detection is throttled to ~5 fps and frames are subsampled to ~320 px (`frame_converter.dart`).
- **No database.** Each document is `name.pdf` + `name.pdf.jpg` (thumbnail); `FileDocumentRepository` resolves collisions (`Doc`, `Doc (2)`, ...) and sanitizes names.

### Contracts worth knowing

These replace in-code comments; the code itself carries none.

| Element | Contract |
|---|---|
| `Quad` | Four points normalized to 0..1, ordered top-left, top-right, bottom-right, bottom-left. `Quad.ordered` sorts any four corners into that order; `Quad.inset(m)` is a rectangle with margin `m`; `toFlat`/`fromFlat` use `[x0, y0, x1, y1, ...]`. |
| `Quad.smoothedTo` | Interpolates towards the next detection by `factor`; if any vertex jumps more than `maxJump` it is treated as a different document and the new quad is adopted as is. |
| `isConvexQuad` | `true` only for four points in traversal order forming a convex, non-degenerate polygon. |
| `GrayFrame` | Grayscale camera frame; `rotation` is the sensor orientation in degrees (0, 90, 180, 270). |
| `downsampleToGray` | Subsamples a camera plane to ~320 px wide. Android (YUV420): plane 0 is already luminance. iOS (BGRA8888): luma approximated as (B + 2G + R) / 4. Honors `bytesPerRow` padding. |
| `ImageProcessor.normalize` | Downscales to at most 3000 px and writes a JPEG; `src` and `dst` may be the same file. |
| `ImageProcessor.crop` | Corrects perspective using the quad, applies the filter and writes the JPEG. |
| `ImageProcessor.rotate` | Rotates 90° clockwise in place and returns the new size. |
| `DocumentRepository.list` | Most recent first; thumbnails are not listed as documents. |
| `ScanSession.move` | Same semantics as `ReorderableListView.onReorderItem` (index after removal). |
| `ScanSession.cropPage` | Returns the cropped page but does **not** add it; the scanner adds it with `add`. |
| `saveSessionAsPdf` | Asks for a name, shows a progress dialog, returns `null` if cancelled or on failure (a snackbar is shown). |
| `showNameDialog` | Returns the entered text, or `null` if cancelled. |
| `GalleryPickerScreen` | Returns the JPEG paths of the chosen images, in selection order. |
| `CropResult` | The cropped page and whether the user chose to save the PDF now. |

## Dependency injection

`core/di/service_locator.dart` is the *composition root*:

| Type | Registration |
|---|---|
| Services, repository and use cases | `registerLazySingleton` |
| `HomeController` | `registerFactory` (new instance per use) |
| `ScanSessionFactory` | singleton that creates one `ScanSession` per scan |

Classes receive their dependencies **through the constructor** and depend on interfaces; the locator is only queried in `app.dart` and in its own registration. Tests build objects directly with doubles or re-register the graph (`sl.reset()`), as `integration_test/` does.

## Testing

```bash
flutter test                                        # unit + widget tests (107 tests)
flutter test integration_test -d <device-id>        # integration on a simulator/device
flutter test --coverage
```

| Type | What it covers |
|---|---|
| Domain unit | `Quad` (ordering, convexity, smoothing, serialization), use cases (with `mocktail`) |
| Data unit | `FileDocumentRepository` against a real temp directory: create, list, rename, delete, collisions |
| Presentation unit | `ScanSession`, `HomeController`, `downsampleToGray` (YUV/BGRA, `bytesPerRow`), formatters, DI graph |
| Widget | `HomeScreen` (empty, loading, error/retry, rename, delete, share), `ReviewScreen`, `CropScreen` (filters, save/add/cancel, batch, drag), `QuadPainter` |
| Integration | Full flow with the real widget tree and DI container on an iOS simulator: list → rename → share → delete; open and close the scanner |

Test doubles live in `test/helpers/fakes.dart` (in-memory repository, image processor, share service, etc.).

**Coverage:** ~56% of lines overall; ~95% in the domain, repository, controllers and session. `OpenCvImageProcessor`, `GalleryPickerScreen` and most of `ScannerScreen` are not covered because they depend on native OpenCV, `photo_manager` and the real camera (see limitations).

## Running

Requirements: Flutter 3.44+ (Dart ^3.12).

```bash
flutter pub get
flutter run                 # use a physical device to access the camera
```

Regenerate icons: `dart run flutter_launcher_icons`.

## Quality gates

Local checks (run on every commit and in CI):

| Check | How |
|---|---|
| Unused imports, unused code, import ordering, lints | `flutter analyze --fatal-infos --fatal-warnings` with strict rules in `analysis_options.yaml` (`unused_import`, `directives_ordering`, `prefer_single_quotes`, ...) |
| English-only code, strings and docs | `dart tool/check_english.dart` |
| Conventional commit messages | `.githooks/commit-msg` |

The English check flags accented Latin letters, inverted Spanish punctuation and non-Latin scripts (Cyrillic, CJK, ...) and a curated list of distinctive Spanish words (`tool/spanish_words.txt`) found in identifiers, strings and docs of `lib/`, `test/`, `integration_test/`, and `.github/`. `README.md`, `CHANGELOG.md` and `CLAUDE.md` are excluded and may be written in Spanish or English. It is a heuristic, not a translator: extend the word list when a new false negative shows up. The checker has its own tests in `test/tool/`.

### Git hooks

```bash
./scripts/install_hooks.sh      # sets core.hooksPath to .githooks (run once after cloning)
./scripts/check_quality.sh      # run the same checks manually
```

- `pre-commit`: analyzer plus English check on the staged files.
- `commit-msg`: requires `<type>(<scope>)?: <description>` in English, with type in `feat fix chore docs refactor test ci perf build style revert`.

## CI/CD (GitHub Actions)

| Workflow | Trigger | What it does |
|---|---|---|
| `pr-validation.yml` | PR to `develop` or `main` | Validates branch name, PR title and ASCII-only text, then runs analyzer and English check |
| `ci.yml` | Push (merge) to `develop`, PRs | Analyzer, English check, `flutter test --coverage`, uploads `lcov.info` |
| `firebase-distribution.yml` | Manual run or tag `v*` | Quality gate, release APK build, upload to Firebase App Distribution |

**Branch naming:** `<type>/<kebab-case-description>` with type in `feature bugfix hotfix release chore docs refactor test ci`, for example `feature/add-flash-toggle`.

- `feature`, `bugfix`, `chore`, `docs`, `refactor`, `test`, `ci` branches target `develop`.
- `release/*` and `hotfix/*` branches target `main`; `develop` may also be merged into `main`.

**PR title:** `<type>(<scope>)?: <description>` (Conventional Commits), for example `feat(scanner): add flash toggle`.

**Firebase App Distribution setup:**

1. In Firebase, register the Android app `com.appinc.mi_scan`, enable App Distribution and create a tester group (default name `testers`).
2. Create a service account with the *Firebase App Distribution Admin* role and download its JSON key.
3. Add these repository secrets: `FIREBASE_ANDROID_APP_ID` (for example `1:1234567890:android:abc123`) and `FIREBASE_SERVICE_ACCOUNT_JSON` (the full JSON content).
4. Run the workflow manually (choosing groups and release notes) or push a tag such as `v1.0.0`.

Notes: the release build is currently signed with the debug key (`android/app/build.gradle.kts`), which is fine for internal testing but not for the Play Store. iOS distribution is not set up because it needs signing certificates and provisioning profiles. Recommended repository settings: protect `develop` and `main`, require the `PR validation` and `CI` checks, and use squash merges so the PR title becomes the commit message.

## Changelog policy

Every change to project files, and every new resource (code, tests, assets, dependencies, CI, scripts), must add an entry to [`CHANGELOG.md`](CHANGELOG.md) under `## [Unreleased]`. This applies equally to human and AI-authored changes.

- Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), with the sections `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed` and `Security`.
- Write one bullet per change, in Spanish or English, describing the effect for users or maintainers rather than the file touched.
- On release, rename `[Unreleased]` to the new version and date, and open a fresh `[Unreleased]` section.
- Exempt files: `CHANGELOG.md`, `README.md`, `CLAUDE.md`, `.gitignore`, `pubspec.lock`, `.metadata`.

Enforcement:

| Where | How |
|---|---|
| Local commit | `.githooks/pre-commit` runs `scripts/check_changelog.sh --staged`; it fails unless the staged `CHANGELOG.md` adds at least one `- ` bullet |
| Pull request | The `changelog` job in `pr-validation.yml` runs the same script against the PR diff; a maintainer can bypass it with the `skip-changelog` label for changes with no user or maintainer impact |
| AI assistants | `CLAUDE.md` makes updating the changelog part of every task |

## Conventions

- All code, identifiers, UI strings, tests, commit messages, PR titles and workflows are in English. `README.md`, `CHANGELOG.md` and `CLAUDE.md` are the only documents that may be in Spanish.
- No code comments: behavior and contracts are documented in this README.
- `CLAUDE.md` holds the context and rules for AI assistants; keep it in sync with the architecture.

## Known limitations and next steps

- `ScannerScreen` and `GalleryPickerScreen` use `camera` and `photo_manager` directly. Next step: abstract them (`CameraService`, `GalleryService`) so they can be tested with doubles.
- `OpenCvImageProcessor` has no automated tests; on-device integration tests with sample images could be added.
- UI strings are hard-coded; localization (`flutter gen-l10n`) is missing.
- No metadata persistence beyond the file system (no search or tags).
- Release signing, iOS distribution and automatic version bumping are not configured.
