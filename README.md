# Mi Scan

Escáner de documentos para Android e iOS hecho con Flutter. Detecta los bordes del documento en vivo con OpenCV, corrige la perspectiva, aplica filtros y genera PDFs de varias páginas que se pueden compartir.

> Proyecto de portafolio: además de las funcionalidades, el foco está en una **arquitectura limpia, inyección de dependencias y una suite de pruebas** (unitarias, de widgets y de integración).

## Funcionalidades

- Cámara con **detección de bordes en vivo** (Canny + contornos, ejecutada en un isolate).
- Importación desde la **galería** con selección múltiple (HEIC se convierte a JPEG en iOS).
- Editor de recorte con esquinas arrastrables, detección automática y **filtros**: Original, Enhanced, Grayscale, B&W (umbral adaptativo).
- Revisión de páginas: reordenar, rotar, eliminar y agregar más.
- Generación de **PDF** (A4, vertical u horizontal según la imagen) con miniatura.
- Lista de documentos: compartir, renombrar (se resuelven colisiones de nombre) y eliminar.
- Tema claro/oscuro Material 3.
- Interfaz en **inglés y español** según el idioma del dispositivo (inglés por defecto).

## Stack

| Área | Paquete |
|---|---|
| Cámara | `camera` |
| Visión por computador | `opencv_dart` |
| PDF | `pdf` |
| Galería | `photo_manager` |
| Compartir | `share_plus` |
| Almacenamiento | `path_provider`, `path` |
| Inyección de dependencias | `get_it` |
| Localización | `flutter_localizations`, `intl` (`flutter gen-l10n`) |
| Pruebas | `flutter_test`, `mocktail`, `integration_test` |

Manejo de estado: `ChangeNotifier` + `ListenableBuilder` (sin librería adicional; suficiente para el tamaño de la app).

## Arquitectura

Clean Architecture en tres capas. La regla de dependencia siempre apunta hacia el dominio.

```
        presentation ───────▶ domain ◀─────── data
   (widgets, controllers)   (Dart puro)   (plugins, disco, OpenCV)
                               ▲
                core/di  (composition root: el único lugar que
                          conoce las implementaciones concretas)
```

```
lib/
├── main.dart                     # arranque: configureDependencies() + runApp
├── app.dart                      # MaterialApp, temas, pantalla inicial
├── core/
│   ├── di/service_locator.dart   # registro de dependencias (get_it)
│   ├── l10n/l10n.dart            # extensión context.l10n
│   ├── theme/app_theme.dart
│   └── utils/formatters.dart     # formato de fecha/tamaño, nombres de archivo, silentDelete
├── domain/                       # Dart puro, sin Flutter ni plugins
│   ├── entities/                 # Quad, ScanPage, ScanFilter, ScannedDocument, GrayFrame
│   ├── repositories/             # DocumentRepository (interfaz)
│   ├── services/                 # ImageProcessor, PdfGenerator, ThumbnailGenerator,
│   │                             # ShareService, SessionStorage (interfaces)
│   └── usecases/                 # ListDocuments, CreateDocument, RenameDocument, DeleteDocument
├── data/
│   ├── repositories/file_document_repository.dart   # PDFs en disco + miniaturas
│   └── services/                 # OpenCvImageProcessor, PdfPackageGenerator,
│                                 # UiThumbnailGenerator, SharePlusService,
│                                 # PathProviderDirectories, FileSessionStorage
└── presentation/
    ├── home/                     # HomeScreen + HomeController
    ├── scanner/                  # ScannerScreen, ScanSession, frame_converter
    ├── crop/                     # CropScreen (editor de esquinas y filtros)
    ├── review/                   # ReviewScreen (páginas de la sesión)
    ├── gallery/                  # GalleryPickerScreen
    └── widgets/                  # QuadPainter, diálogo de nombre, guardado de PDF
```

### Flujo de captura

```
ScannerScreen ──takePicture──▶ ScanSession.importSource ──▶ ImageProcessor.normalize
      │                                                          (JPEG, máx. 3000 px)
      ▼
CropScreen ──detectInFile──▶ ImageProcessor.detectInFile ──▶ Quad
      │  (el usuario ajusta esquinas y filtro)
      ▼
ScanSession.cropPage ──▶ ImageProcessor.crop (perspectiva + filtro) ──▶ ScanPage
      ▼
ScanSession.saveAsPdf ──▶ CreateDocument ──▶ DocumentRepository ──▶ PdfGenerator + ThumbnailGenerator
```

### Decisiones de diseño

- **`ScanSession` como fachada de presentación.** Guarda las páginas de un escaneo en curso y es la única puerta de entrada de las pantallas al dominio. Las pantallas reciben solo la sesión, lo que reduce el cableado y facilita reemplazarla en las pruebas.
- **El dominio no conoce plugins.** `Quad` usa `dart:math`; la geometría (orden de esquinas, convexidad, suavizado temporal) es lógica pura y se prueba sin dispositivo.
- **OpenCV aislado detrás de `ImageProcessor`.** La lógica de la app se prueba con un doble. Solo tipos primitivos (`List<double>`, rutas) cruzan el límite del isolate.
- **Trabajo pesado fuera del hilo de UI.** La detección y los filtros usan `compute`; la detección en vivo se limita a ~5 fps y los frames se submuestrean a ~320 px (`frame_converter.dart`).
- **Sin base de datos.** Cada documento es `nombre.pdf` + `nombre.pdf.jpg` (miniatura); `FileDocumentRepository` resuelve colisiones (`Doc`, `Doc (2)`, ...) y sanea los nombres.

### Contratos importantes

Estos reemplazan los comentarios en el código; el código no lleva ninguno.

| Elemento | Contrato |
|---|---|
| `Quad` | Cuatro puntos normalizados a 0..1, ordenados arriba-izquierda, arriba-derecha, abajo-derecha, abajo-izquierda. `Quad.ordered` ordena cuatro esquinas cualesquiera en ese orden; `Quad.inset(m)` es un rectángulo con margen `m`; `toFlat`/`fromFlat` usan `[x0, y0, x1, y1, ...]`. |
| `Quad.smoothedTo` | Interpola hacia la siguiente detección según `factor`; si algún vértice salta más de `maxJump` se considera otro documento y se adopta el nuevo quad tal cual. |
| `isConvexQuad` | `true` solo para cuatro puntos, en orden de recorrido, que forman un polígono convexo y no degenerado. |
| `GrayFrame` | Frame de cámara en escala de grises; `rotation` es la orientación del sensor en grados (0, 90, 180, 270). |
| `downsampleToGray` | Submuestrea un plano de la cámara a ~320 px de ancho. Android (YUV420): el plano 0 ya es luminancia. iOS (BGRA8888): luma aproximada como (B + 2G + R) / 4. Respeta el relleno de `bytesPerRow`. |
| `ImageProcessor.normalize` | Reduce a un máximo de 3000 px y escribe un JPEG; `src` y `dst` pueden ser el mismo archivo. |
| `ImageProcessor.crop` | Corrige la perspectiva con el quad, aplica el filtro y escribe el JPEG. |
| `ImageProcessor.rotate` | Rota 90° en sentido horario sobre el mismo archivo y devuelve el nuevo tamaño. |
| `DocumentRepository.list` | Más reciente primero; las miniaturas no se listan como documentos. |
| `ScanSession.move` | Misma semántica que `ReorderableListView.onReorderItem` (índice después de quitar el elemento). |
| `ScanSession.cropPage` | Devuelve la página recortada pero **no** la agrega; el escáner la agrega con `add`. |
| `saveSessionAsPdf` | Pide un nombre, muestra un diálogo de progreso y devuelve `null` si se cancela o falla (se muestra un snackbar). |
| `showNameDialog` | Devuelve el texto ingresado, o `null` si se cancela. |
| `GalleryPickerScreen` | Devuelve las rutas JPEG de las imágenes elegidas, en orden de selección. |
| `CropResult` | La página recortada y si el usuario eligió guardar el PDF ahora. |

## Inyección de dependencias

`core/di/service_locator.dart` es el *composition root*:

| Tipo | Registro |
|---|---|
| Servicios, repositorio y casos de uso | `registerLazySingleton` |
| `HomeController` | `registerFactory` (instancia nueva en cada uso) |
| `ScanSessionFactory` | singleton que crea una `ScanSession` por escaneo |

Las clases reciben sus dependencias **por constructor** y dependen de interfaces; el localizador solo se consulta en `app.dart` y en su propio registro. Las pruebas construyen los objetos directamente con dobles o vuelven a registrar el grafo (`sl.reset()`), como hace `integration_test/`.

## Pruebas

```bash
flutter test                                        # pruebas unitarias + de widgets (124 pruebas)
flutter test integration_test -d <id-dispositivo>   # integración en simulador/dispositivo
flutter test --coverage
```

| Tipo | Qué cubre |
|---|---|
| Unitarias de dominio | `Quad` (orden, convexidad, suavizado, serialización), casos de uso (con `mocktail`) |
| Unitarias de datos | `FileDocumentRepository` contra un directorio temporal real: crear, listar, renombrar, eliminar, colisiones |
| Unitarias de presentación | `ScanSession`, `HomeController`, `downsampleToGray` (YUV/BGRA, `bytesPerRow`), formateadores, grafo de DI |
| Widgets | `HomeScreen` (vacío, carga, error/reintento, renombrar, eliminar, compartir), `ReviewScreen`, `CropScreen` (filtros, guardar/agregar/cancelar, lote, arrastre), `QuadPainter` |
| Localización | Claves y placeholders idénticos en los ARB, plurales, resolución de idioma (`es`, `es-MX`, idiomas no soportados → inglés) y pantallas en español |
| Integración | Flujo completo con el árbol real de widgets y el contenedor de DI en un simulador iOS: listar → renombrar → compartir → eliminar; abrir y cerrar el escáner |

Los dobles de prueba están en `test/helpers/fakes.dart` (repositorio en memoria, procesador de imágenes, servicio de compartir, etc.).

**Cobertura:** ~56 % de las líneas en total; ~95 % en dominio, repositorio, controladores y sesión. `OpenCvImageProcessor`, `GalleryPickerScreen` y la mayor parte de `ScannerScreen` no están cubiertos porque dependen de OpenCV nativo, `photo_manager` y la cámara real (ver limitaciones).

## Idiomas (localización)

La app está disponible en **inglés** y **español**, con `flutter gen-l10n` y archivos ARB:

- Si el idioma del dispositivo es español (`es`, incluidas variantes como `es-MX` o `es-CO`), la app se muestra en español.
- Con cualquier otro idioma (francés, portugués, etc.) se muestra en **inglés**, que es el idioma principal y el de respaldo.
- Cambia con el idioma del sistema; no hay selector dentro de la app.

| Archivo | Rol |
|---|---|
| `l10n.yaml` | Configuración del generador |
| `lib/l10n/app_en.arb` | Plantilla: textos en inglés |
| `lib/l10n/app_es.arb` | Traducción al español |
| `lib/l10n/app_localizations*.dart` | Código generado (se versiona; no se edita a mano) |
| `lib/core/l10n/l10n.dart` | Extensión `context.l10n` para usar los textos |
| `ios/Runner/Info.plist` | `CFBundleLocalizations` con `en` y `es`; sin esto iOS no entrega el español a la app |

**Cómo agregar o cambiar un texto:**

1. Agrega la clave en `app_en.arb` y en `app_es.arb` (mismas claves y mismos placeholders; para plurales usa la sintaxis ICU, por ejemplo `{count, plural, =1{1 page} other{{count} pages}}`).
2. Ejecuta `flutter gen-l10n` (también lo hacen `flutter run` y `flutter test`) y commitea los archivos generados.
3. En el código usa `context.l10n.miClave`; nunca escribas textos visibles directamente en los widgets.

**Reglas y controles:**

- El dominio no conoce la localización: `ScanFilter` no tiene etiqueta; el texto se resuelve en presentación con `ScanFilterLabel` (`presentation/widgets/scan_filter_label.dart`).
- Las fechas y los decimales de `formatDocSubtitle` usan el idioma activo (`3/5/2026` en inglés, `5/3/2026` en español).
- `tool/check_english.dart` no revisa `lib/l10n/`, porque ahí es legítimo el español; el resto del código sigue solo en inglés.
- `test/presentation/localization_test.dart` comprueba que ambos ARB tengan las mismas claves y placeholders, que los plurales funcionen, y que un dispositivo en `es`/`es-MX` muestre español y uno en `fr`, `pt`, `de` o `ja` muestre inglés.
- El job `CI` falla si los archivos generados no están al día con los ARB.

## Ejecución

Requisitos: Flutter 3.44+ (Dart ^3.12).

```bash
flutter pub get
flutter run                 # usa un dispositivo físico para acceder a la cámara
```

Regenerar iconos: `dart run flutter_launcher_icons`.

## Controles de calidad

Verificaciones locales (se ejecutan en cada commit y en CI):

| Verificación | Cómo |
|---|---|
| Imports sin usar, código sin usar, orden de imports, lints | `flutter analyze --fatal-infos --fatal-warnings` con reglas estrictas en `analysis_options.yaml` (`unused_import`, `directives_ordering`, `prefer_single_quotes`, ...) |
| Código, textos y documentación solo en inglés | `dart tool/check_english.dart` |
| Mensajes de commit convencionales | `.githooks/commit-msg` |

La verificación de inglés marca letras latinas con acento, signos de puntuación invertidos del español y alfabetos no latinos (cirílico, CJK, ...), además de una lista curada de palabras distintivas del español (`tool/spanish_words.txt`) encontradas en identificadores, textos y documentos de `lib/`, `test/`, `integration_test/` y `.github/`. Los archivos `.md` están excluidos: la documentación va en español. Es una heurística, no un traductor: amplía la lista de palabras cuando aparezca un falso negativo nuevo. El verificador tiene sus propias pruebas en `test/tool/`.

### Git hooks

Los hooks están en `.githooks/` y se activan con `git config core.hooksPath .githooks`.

- `pre-commit`: política de changelog, analizador y verificación de inglés sobre los archivos en stage.
- `commit-msg`: exige `<type>(<scope>)?: <description>` en inglés, con type en `feat fix chore docs refactor test ci perf build style revert`.

## CI/CD (GitHub Actions)

| Workflow | Disparador | Qué hace |
|---|---|---|
| `pr-validation.yml` | PR a `develop` o `main` | Valida nombre de rama, título del PR, texto solo ASCII y changelog; luego ejecuta analizador y verificación de inglés |
| `ci.yml` | Push (merge) a `develop`, PRs | Analizador, verificación de inglés, `flutter test --coverage`, sube `lcov.info` |
| `firebase-distribution.yml` | Ejecución manual o tag `v*` | Control de calidad, compilación del APK release y subida a Firebase App Distribution |

Los nombres de rama y los destinos de cada tipo de rama están en [Estrategia de ramas](#estrategia-de-ramas).

**Título del PR:** `<type>(<scope>)?: <description>` (Conventional Commits), por ejemplo `feat(scanner): add flash toggle`.

**Publicar una versión en Firebase App Distribution:** la app de Firebase, el grupo de testers `testers` y los secretos del environment `release` ya están configurados (ver [Firma de release](#firma-de-release-android)). Para publicar, ejecuta el workflow manualmente desde `main` (eligiendo grupos y notas de versión) o sube un tag desde `main`, por ejemplo `v1.0.0`. El job espera tu aprobación del environment `release` antes de usar los secretos.

Notas: la firma de release se describe en la sección siguiente. La distribución en iOS no está configurada porque requiere certificados de firma y perfiles de aprovisionamiento.

## Firma de release (Android)

El keystore y las contraseñas **nunca están en el código**: `android/app/build.gradle.kts` los lee de variables de entorno (CI) o de `android/key.properties` (local, ignorado por git). Si no hay ninguna configurada, el build release usa la clave debug para que `flutter run --release` siga funcionando en desarrollo. El workflow de distribución nunca llega a ese caso: falla si faltan los secretos y verifica que el APK no esté firmado con la clave debug.

| Variable (CI) | Propiedad en `key.properties` | Contenido |
|---|---|---|
| `ANDROID_KEYSTORE_PATH` | `storeFile` | Ruta del archivo `.jks` (en CI la crea el workflow) |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` | Contraseña del keystore |
| `ANDROID_KEY_ALIAS` | `keyAlias` | Alias de la clave |
| `ANDROID_KEY_PASSWORD` | `keyPassword` | Contraseña de la clave |

**Secretos del environment `release`.** El keystore y las credenciales ya están configurados como secretos del environment `release` (despliegue restringido a `main` y a los tags `v*`, con revisor requerido). Solo llegan a los jobs que declaran `environment: release`. Si hay que rotarlos o auditarlos, se gestionan en *Settings → Environments → release*.

| Secreto | Uso |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Keystore `.jks` codificado en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Contraseña del keystore |
| `ANDROID_KEY_ALIAS` | Alias de la clave |
| `ANDROID_KEY_PASSWORD` | Contraseña de la clave |
| `FIREBASE_ANDROID_APP_ID` | Id de la app Android en Firebase |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Clave JSON de la cuenta de servicio de distribución |

**Qué hace el workflow:** valida que los cuatro secretos de firma existan, restaura el keystore en un directorio temporal del runner, compila el APK firmado, comprueba con `apksigner` que el certificado no sea `CN=Android Debug`, lo sube a Firebase y borra el keystore al terminar.

## Estrategia de ramas

Se usa un **GitFlow simplificado**: dos ramas permanentes y ramas de vida corta que siempre se integran mediante pull request. Es la estrategia que asumen los workflows (`ci.yml` corre en `develop`, `firebase-distribution.yml` publica desde tags en `main`).

```
main      ●───────────────●───────────────●──────  producción, solo recibe PRs; cada commit = versión con tag vX.Y.Z
           \             ↗ ↘               ↗ ↘
develop    ●──●──●──●──●───●──●──●──●──●───●────  integración continua, siempre verde
            \  ↗ \  ↗
feature/*    ●─●   ●─●                            una rama por cambio, vida corta
```

### Ramas

| Rama | Se crea desde | Se integra en | Vida | Propósito |
|---|---|---|---|---|
| `main` | — | — | Permanente | Código publicable. Cada merge corresponde a una versión con tag `vX.Y.Z` |
| `develop` | `main` | `main` (PR) | Permanente | Integración de todo el trabajo; CI corre en cada merge |
| `feature/<nombre>` | `develop` | `develop` | Corta | Funcionalidad nueva |
| `bugfix/<nombre>` | `develop` | `develop` | Corta | Corrección de un bug no urgente |
| `refactor/<nombre>` | `develop` | `develop` | Corta | Mejora interna sin cambio funcional |
| `test/<nombre>` | `develop` | `develop` | Corta | Solo pruebas |
| `docs/<nombre>` | `develop` | `develop` | Corta | Solo documentación |
| `chore/<nombre>` | `develop` | `develop` | Corta | Dependencias, configuración, mantenimiento |
| `ci/<nombre>` | `develop` | `develop` | Corta | Workflows, hooks y scripts |
| `release/<x.y.z>` | `develop` | `main` | Corta | Estabilización opcional antes de publicar: subir `version` en `pubspec.yaml` y cerrar `[Sin publicar]` en el changelog |
| `hotfix/<nombre>` | `main` | `main` | Muy corta | Corrección urgente en producción |

Nombre de rama: `<tipo>/<kebab-case>`, por ejemplo `feature/add-flash-toggle`. La validación del PR rechaza otros formatos y destinos incorrectos.

### Flujos

**Trabajo diario**

1. `git switch develop && git pull`, luego `git switch -c feature/add-flash-toggle`.
2. Commits con Conventional Commits y entrada en `CHANGELOG.md`.
3. PR hacia `develop` con título `feat(scanner): add flash toggle`; esperar los checks.
4. **Squash merge**: el título del PR queda como único commit en `develop`, lo que mantiene el historial lineal y legible. Se borra la rama.

**Publicar una versión**

1. Con `develop` estable, abrir un PR `develop → main` (o `release/x.y.z → main` si hace falta estabilizar: subir la versión y cerrar el changelog ahí).
2. **Merge commit** (sin squash) para conservar el historial de `develop`.
3. Crear el tag en `main`: `git tag v1.1.0 && git push origin v1.1.0`. Esto dispara el APK a Firebase App Distribution (el workflow rechaza tags que no estén en `main`).
4. **Back-merge**: abrir un PR `main → develop` (merge commit) para que `develop` reciba el commit de merge y cualquier ajuste hecho en `main`.

**Hotfix**

1. `git switch main && git pull`, luego `git switch -c hotfix/fix-pdf-crash`.
2. PR hacia `main` (merge commit), tag de parche (`v1.1.1`) y back-merge `main → develop`.

### Arreglos durante la estabilización de una release

Mientras una rama `release/x.y.z` se prueba, `develop` sigue recibiendo trabajo nuevo que **no** debe salir en esa versión. Por eso la release se corta desde `develop` en un momento fijo y después sigue su propio camino:

```
develop        ●──●──●──●──●──●──●──●──────●     siguen entrando features nuevas
                    \                     ↑
release/1.1.0        ●──●──(fix)──●──┐    │ back-merge
                                      \   │
main                   ●───────────────●───┘     tag v1.1.0
```

1. **Cortar la release** desde `develop` actualizado: `git switch develop && git pull && git switch -c release/1.1.0`. En esa rama se sube `version` en `pubspec.yaml` y se cierra `[Sin publicar]` en el changelog.
2. **Corregir en la release.** Si las pruebas encuentran un bug, el arreglo se hace **solo en `release/1.1.0`**, con un commit directo o con una rama corta `bugfix/<nombre>` creada **desde la release** y fusionada de vuelta a ella. Cada arreglo lleva su entrada en el changelog.
3. **No traer `develop` a la release.** No hagas merge ni rebase de `develop` dentro de `release/x.y.z`: se colarían features que no estaban en esa versión.
4. **Publicar.** PR `release/x.y.z → main` con merge commit, y tag `vx.y.z` desde `main`.
5. **Back-merge.** PR `main → develop` con merge commit, para que `develop` reciba los arreglos hechos en la release. Si el mismo bug ya estaba corregido en `develop`, los conflictos se resuelven en ese PR.

**Qué rama usar para cada caso**

| Situación | Rama |
|---|---|
| Bug encontrado probando una release en curso | Arreglo **en** `release/x.y.z` (commit directo o `bugfix/*` desde la release) |
| Bug en producción, versión ya publicada | `hotfix/*` desde `main`, con tag de parche (`vx.y.z+1`) |
| Bug en `develop` que no afecta a la release | `bugfix/*` hacia `develop` |

Limitaciones actuales: los workflows `ci.yml` y `pr-validation.yml` solo se disparan en PRs hacia `develop` y `main`, y las ramas `release/*` no están protegidas. Un PR `bugfix/* → release/x.y.z` no pasa por validación ni CI; las pruebas de la release se ejecutan al abrir el PR hacia `main`. Para validar también esos PRs habría que extender los workflows a `release/**`.

### Alternativa más simple

Si el proyecto sigue siendo de una sola persona, se puede omitir `develop` y trabajar con *trunk-based*: ramas de vida corta hacia `main`, squash merge y tag por versión. Se pierde la rama de integración y habría que cambiar `ci.yml`, `pr-validation.yml` y esta sección. Se mantiene GitFlow simplificado porque demuestra un flujo de equipo con releases controlados, que es el objetivo del portafolio.

## Política de changelog

Todo cambio en archivos del proyecto, y todo recurso nuevo (código, pruebas, assets, dependencias, CI, scripts), debe agregar una entrada en [`CHANGELOG.md`](CHANGELOG.md) bajo `## [Sin publicar]`. Aplica por igual a cambios hechos por personas y por IA.

- Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/), con las secciones `Añadido`, `Cambiado`, `Obsoleto`, `Eliminado`, `Corregido` y `Seguridad`.
- Escribe una viñeta por cambio, en español, describiendo el efecto para usuarios o mantenedores y no el archivo modificado.
- Al publicar una versión, renombra `[Sin publicar]` con la nueva versión y fecha, y abre una nueva sección `[Sin publicar]`.
- Archivos exentos: `CHANGELOG.md`, `README.md`, `CLAUDE.md`, `.gitignore`, `pubspec.lock`, `.metadata`.

Cumplimiento:

| Dónde | Cómo |
|---|---|
| Commit local | `.githooks/pre-commit` ejecuta `scripts/check_changelog.sh --staged`; falla si el `CHANGELOG.md` en stage no agrega al menos una viñeta `- ` |
| Pull request | El job `changelog` de `pr-validation.yml` ejecuta el mismo script contra el diff del PR; un mantenedor puede omitirlo con la etiqueta `skip-changelog` en cambios sin impacto para usuarios ni mantenedores |
| Asistentes de IA | `CLAUDE.md` hace que actualizar el changelog sea parte de cada tarea |

## Convenciones

- Todo el código, identificadores, pruebas, mensajes de commit, títulos de PR y workflows están en inglés. Los textos de la interfaz se escriben en `lib/l10n/app_en.arb` (inglés) y se traducen en `lib/l10n/app_es.arb`; ese es el único código con español. Toda la documentación (`*.md`: `README.md`, `CHANGELOG.md`, `CLAUDE.md` y la plantilla de PR) está en español.
- Sin comentarios en el código: el comportamiento y los contratos se documentan en este README.
- `CLAUDE.md` contiene el contexto y las reglas para asistentes de IA; mantenlo sincronizado con la arquitectura.

## Limitaciones conocidas y próximos pasos

- `ScannerScreen` y `GalleryPickerScreen` usan `camera` y `photo_manager` directamente. Siguiente paso: abstraerlos (`CameraService`, `GalleryService`) para poder probarlos con dobles.
- `OpenCvImageProcessor` no tiene pruebas automatizadas; se podrían agregar pruebas de integración en dispositivo con imágenes de muestra.
- Solo hay dos idiomas (inglés y español) y no existe un selector de idioma dentro de la app.
- No hay persistencia de metadatos más allá del sistema de archivos (sin búsqueda ni etiquetas).
- No están configurados la firma de release, la distribución en iOS ni el versionado automático.
