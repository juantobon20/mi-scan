# Mi Scan

Escáner de documentos para Android e iOS hecho con Flutter. Detecta los bordes del documento en vivo con OpenCV, corrige la perspectiva, aplica filtros y genera PDFs de varias páginas que se pueden compartir.

> Proyecto de portafolio: además de las funcionalidades, el foco está en una **arquitectura limpia, inyección de dependencias y una suite de pruebas** (unitarias, de widgets y de integración).

## Funcionalidades

- Cámara con **detección de bordes en vivo** (Canny + contornos, ejecutada en un isolate).
- **Zoom** (gesto de pellizco y deslizador), **flash** (apagado, automático, encendido) y **linterna**.
- **Cambio automático de lente al hacer zoom**, como la cámara original: ultra gran angular, principal y teleobjetivo, sin botones. Solo se usan las cámaras traseras (no hay cámara frontal).
- **Modo lote**: captura varias fotos seguidas sin interrupciones; al pulsar "Listo" se abre el editor de recorte foto por foto (con detección automática, esquinas ajustables y filtros), igual que en el modo individual, y al final se guarda el PDF.
- Importación desde la **galería** con selección múltiple (HEIC se convierte a JPEG en iOS).
- Editor de recorte con esquinas arrastrables, detección automática y **filtros**: Original, Enhanced, Grayscale, B&W (umbral adaptativo).
- Revisión de páginas: reordenar, rotar, eliminar y agregar más.
- Generación de **PDF** (A4, vertical u horizontal según la imagen) con miniatura.
- Lista de documentos: compartir, renombrar (se resuelven colisiones de nombre), mover a una carpeta y eliminar; cada documento muestra su fecha, tamaño y número de páginas.
- **Carpetas**: crear, renombrar y eliminar (los documentos de una carpeta eliminada se conservan, sin carpeta). Un escaneo nuevo se guarda en la carpeta que esté abierta.
- **Búsqueda** por nombre **y por el texto del documento**, sin distinguir mayúsculas ni acentos: todas las palabras deben coincidir (cada una en el nombre o en el contenido) y se combina con la carpeta elegida.
- **OCR en el dispositivo** (ML Kit, escritura latina: inglés, español y otros idiomas latinos): al guardar un escaneo, el texto de sus páginas se reconoce en segundo plano, sin enviar nada a internet. Cada documento con texto muestra «Texto buscable», se puede abrir con «Ver texto» y copiar.
- **Almacenamiento en SQLite**: los metadatos viven en una base de datos local; los PDFs que guardó una versión anterior sin base de datos se importan solos.
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
| OCR | `google_mlkit_text_recognition` (ML Kit, en el dispositivo) |
| Base de datos | `sqflite` (y `sqflite_common_ffi` en las pruebas) |
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
│   ├── entities/                 # Quad, ScanPage, ScanFilter, ScannedDocument, GrayFrame,
│   │                             # CameraInfo, ZoomRange, FlashSetting, GalleryImage
│   ├── repositories/             # DocumentRepository, FolderRepository (interfaces)
│   ├── services/                 # ImageProcessor, PdfGenerator, ThumbnailGenerator,
│   │                             # ShareService, SessionStorage, TextRecognizer, CameraService/CameraSession,
│   │                             # GalleryService (interfaces)
│   └── usecases/                 # ListDocuments, CreateDocument, RenameDocument, MoveDocument,
│                                 # DeleteDocument, ListFolders, CreateFolder, RenameFolder, DeleteFolder
├── data/
│   ├── repositories/             # SqliteDocumentRepository, SqliteFolderRepository
│   ├── storage/                  # AppDatabase (esquema y migraciones), DocumentFiles (PDFs y
│   │                             # miniaturas en disco), contador de páginas de PDF
│   └── services/                 # OpenCvImageProcessor, PdfPackageGenerator,
│       │                         # UiThumbnailGenerator, SharePlusService,
│       │                         # PathProviderDirectories, FileSessionStorage,
│       │                         # PhotoManagerGalleryService, MlKitTextRecognizer
│       └── camera/               # PluginCameraService, mapeos y frame_converter
└── presentation/
    ├── home/                     # HomeScreen + HomeController
    ├── navigation/               # ScreenFactory (fábrica de controladores y vista previa)
    ├── scanner/                  # ScannerScreen, ScannerController, ScanSession
    ├── crop/                     # CropScreen (editor de esquinas y filtros)
    ├── review/                   # ReviewScreen (páginas de la sesión)
    ├── gallery/                  # GalleryPickerScreen, GalleryController
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
- **SQLite para los metadatos, archivos para los PDFs.** Cada documento sigue siendo `nombre.pdf` + `nombre.pdf.jpg` (miniatura) en el directorio de la app, de modo que compartir conserva un nombre legible; la base `mi_scan.db` guarda nombre, ruta, tamaño, páginas, fechas y carpeta. `DocumentFiles` resuelve colisiones (`Doc`, `Doc (2)`, ...) y sanea los nombres.

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
| `ImageProcessor.applyFilter` | Aplica un filtro a una copia reducida (`maxSide`, por defecto 1600 px) y la guarda como JPEG. Usa la misma función de OpenCV que `crop`, así que la vista previa es el resultado real del filtro; en B/N el tamaño del bloque del umbral adaptativo se escala con la reducción para que se vea igual que en el archivo final. |
| `ScanSession.previewFilter` | Devuelve la imagen filtrada para la vista previa (la original si el filtro es Original). Guarda cada combinación imagen/filtro en el directorio de la sesión, comparte las peticiones simultáneas y no cachea los errores. `discardPreviews` las borra al cerrar el editor. |
| `DocumentRepository.list` | Recibe un `DocumentQuery` (carpeta y texto). Más reciente primero; las miniaturas no se listan como documentos. La búsqueda divide el texto en palabras, normaliza mayúsculas y acentos (`normalizeSearchText`) y exige que todas aparezcan en el nombre; `%`, `_` y `\` se buscan literalmente. |
| `DocumentRepository.move` | Cambia la carpeta (`null` = sin carpeta). Mover a una carpeta que no existe falla por la clave foránea. `MoveDocument` no toca el repositorio si la carpeta no cambia. |
| `FolderRepository` | Los nombres son únicos sin distinguir mayúsculas ni acentos: un repetido recibe un sufijo (`Work`, `Work (2)`). `list` devuelve cada carpeta con su número de documentos, ordenadas por nombre. Eliminar una carpeta deja sus documentos sin carpeta (`ON DELETE SET NULL`). |
| `AppDatabase` | Abre `mi_scan.db` de forma perezosa, activa las claves foráneas y aplica las migraciones en orden: una lista de pasos, donde el paso *n* lleva la base de la versión *n* a la *n+1*. Una base nueva ejecuta todos los pasos; una existente solo los que le faltan. `schemaVersion` es 2: la v1 crea `folders` y `documents`; la v2 añade `content_text` (texto reconocido) y `search_content` (el mismo texto normalizado para buscar). Una base de la fase anterior se actualiza conservando todas sus filas. |
| `TextRecognizer` | `recognize(imagePath)` devuelve un `RecognizedText`; `dispose` libera el motor (se puede volver a usar después). `MlKitTextRecognizer` usa el reconocedor de escritura latina de ML Kit. |
| `RecognizeDocumentText` | Reconoce las páginas una a una, recorta cada texto, descarta las páginas vacías y une el resto con una línea en blanco. Si una página falla, sigue con las demás y la cuenta en `failedPages`; solo guarda si hay texto. Devuelve un `OcrOutcome`. |
| Texto y búsqueda | `DocumentRepository.saveText(id, texto)` reemplaza el texto anterior y `getText(id)` lo lee; la lista no carga el texto completo, solo el indicador `hasText`. Al buscar, cada palabra debe aparecer en el nombre **o** en el contenido; renombrar, mover y reabrir la app conservan el texto, y eliminar el documento lo elimina. |
| OCR en segundo plano | Al volver del escáner con un documento nuevo, `HomeScreen` copia las páginas, abre la lista de inmediato y lanza `HomeController.recognizeText`. Las imágenes de la sesión se conservan hasta que termina el reconocimiento (con éxito o con error) y entonces se borran. Mientras corre, el documento muestra «Reconociendo texto...». Si falla por completo se avisa con un mensaje y el documento se conserva sin texto. |
| Sincronización con el disco | La primera vez que se usa el repositorio en cada arranque: los PDFs que hay en disco sin fila se importan (nombre, tamaño, fecha de modificación y número de páginas contado en el PDF) y las filas cuyo PDF ya no existe se eliminan. |
| `HomeController` | Mantiene documentos, carpetas, carpeta elegida y texto de búsqueda. La búsqueda espera 250 ms después de la última tecla, y una respuesta lenta anterior nunca pisa a una más reciente. `onDocumentScanned` mueve el escaneo nuevo a la carpeta abierta. |
| `ScanSession.move` | Misma semántica que `ReorderableListView.onReorderItem` (índice después de quitar el elemento). |
| `ScanSession.cropPage` | Devuelve la página recortada pero **no** la agrega; el escáner la agrega con `add`. |
| `saveSessionAsPdf` | Pide un nombre, muestra un diálogo de progreso y devuelve `null` si se cancela o falla (se muestra un snackbar). |
| `showNameDialog` | Devuelve el texto ingresado, o `null` si se cancela. |
| `GalleryPickerScreen` | Devuelve las rutas JPEG de las imágenes elegidas, en orden de selección. |
| `CameraService` | `listCameras()` devuelve las cámaras del teléfono (el escáner solo usa las traseras); `open(camera)` entrega una `CameraSession` o lanza `CameraAccessException` (`permissionDenied`, `unavailable`, `failed`). |
| `CameraSession` | Una cámara abierta: `frames` (cuadros en gris para detectar el documento, ~5 por segundo), `setZoom` (se ajusta a `zoomRange`), `setFlash`, `setTorch`, `takePicture` y `dispose`. La linterna tiene prioridad sobre el flash. |
| `GalleryService` | `requestAccess`, `loadPage` (paginado), `thumbnail`, `exportJpeg` (siempre JPEG, también convierte HEIC) y `openSettings`. |
| `ScannerController` | Estado del escáner: zoom, flash, linterna, documento detectado (suavizado), modo y captura. Elige la cámara trasera principal y gestiona el cambio de lente según el zoom (ver abajo). |
| Operaciones de cámara | Abrir, cerrar, reanudar y cambiar de lente se ejecutan **una a una** en una cola. Al pedir el permiso de cámara, Android pausa y reanuda la pantalla mientras la primera apertura sigue esperando; sin la cola se abría la cámara 0 dos veces y CameraX fallaba con "No supported surface combination". |
| Zoom y lentes | Si la cámara principal ya expone un rango que baja de 1x (multicámara lógica, por ejemplo 0,6x a 10x en un Galaxy S23), el teléfono cambia de lente solo y la app usa ese rango. Si los lentes se listan por separado, la app los combina en un único zoom: por debajo de 1x usa el ultra gran angular (factor 0,5x), de 1x a 2x el principal con zoom digital y desde 2x el teleobjetivo (factor 2x). Los cambios tienen histéresis (0,95x/1x y 1,9x/2x) para no alternar el lente al pellizcar; cada cambio reabre la cámara, conservando flash y linterna. |
| `ScanMode` | `single` abre el editor de recorte tras cada foto; `batch` guarda cada foto normalizada en la cola `ScanSession.shots` sin interrumpir la captura. "Listo" (o tocar la miniatura) vacía la cola con `takeShots()` y abre `CropScreen` para cada foto ("Siguiente", "Omitir", "Agregar" o "Guardar"); "Omitir" descarta esa foto. |
| `ScreenFactory` | Crea los controladores de escáner y galería y el constructor de la vista previa; se registra en el contenedor de DI y evita que las pantallas lo consulten. |
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
flutter test                                        # pruebas unitarias + de widgets
flutter test integration_test -d <id-dispositivo>   # integración en simulador/dispositivo
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart -d <id-dispositivo>   # lo mismo con flutter drive
flutter test --coverage
```

| Tipo | Qué cubre |
|---|---|
| Unitarias de dominio | `Quad` (orden, convexidad, suavizado, serialización), casos de uso (con `mocktail`) |
| Unitarias de datos | Repositorios SQLite contra una base real (FFI en el equipo) y un directorio temporal: crear, listar, buscar (mayúsculas, acentos, varias palabras, comodines literales), carpetas, mover, renombrar, eliminar, importar PDFs existentes, persistencia al reabrir y esquema |
| Unitarias de presentación | `ScanSession`, `HomeController`, `downsampleToGray` (YUV/BGRA, `bytesPerRow`), formateadores, grafo de DI |
| Widgets | `HomeScreen` (vacío, carga, error/reintento, renombrar, eliminar, compartir), `ReviewScreen`, `CropScreen` (filtros, guardar/agregar/cancelar, lote, arrastre), `QuadPainter` |
| Localización | Claves y placeholders idénticos en los ARB, plurales, resolución de idioma (`es`, `es-MX`, idiomas no soportados → inglés) y pantallas en español |
| OpenCV real | `integration_test/opencv_filters_test.dart` ejecuta el procesador real en un simulador o dispositivo: Grises deja canales iguales, B/N deja solo píxeles blancos y negros, Mejorado aclara la imagen, la vista previa respeta `maxSide` sin ampliar, y el recorte aplica el mismo filtro que la vista previa |
| OCR real | `integration_test/ocr_test.dart` ejecuta ML Kit y la base real: lee las palabras de una imagen generada, devuelve vacío en una imagen en blanco, el reconocedor se puede reutilizar tras `dispose` y un documento escaneado se encuentra buscando por su contenido |
| SQLite real | `integration_test/storage_test.dart` ejecuta los mismos repositorios con el plugin nativo de `sqflite` en un simulador o dispositivo: CRUD, búsqueda, carpetas, claves foráneas, persistencia e importación |
| Integración | Flujo completo con el árbol real de widgets y el contenedor de DI en un simulador iOS: listar → renombrar → compartir → eliminar; abrir y cerrar el escáner |

Los dobles de prueba están en `test/helpers/fakes.dart` (repositorio en memoria, procesador de imágenes, servicio de compartir, etc.).

**Zoom fluido.** El gesto y el deslizador solo reconstruyen la etiqueta y el propio deslizador (no toda la pantalla), el documento detectado se repinta aparte, el deslizador usa escala logarítmica (cada tramo multiplica el zoom por el mismo factor, como la cámara original) y la detección se pausa mientras el zoom cambia, reanudándose 350 ms después de soltar. La detección no es necesaria mientras haces zoom y así la cámara deja de enviar ~30 fotogramas por segundo a Dart durante el gesto.

**Cobertura:** la lógica de dominio, repositorio, controladores (incluidos `ScannerController` y `GalleryController`), sesión y pantallas está cubierta con dobles de cámara y galería (`FakeCameraService`, `FakeGalleryService`). No se cubren `OpenCvImageProcessor` ni las clases que hablan con los plugins reales (`PluginCameraSession`, `PhotoManagerGalleryService`): dependen de OpenCV nativo, de la cámara y de la galería del dispositivo; se validan a mano en un teléfono.

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

Requisitos: Flutter 3.44+ (Dart ^3.12). Para compilar iOS hace falta **CocoaPods** (`brew install cocoapods`), porque ML Kit solo existe como pod; el iOS mínimo es **15.5**.

> **Simuladores de iOS:** los pods de ML Kit no incluyen la arquitectura arm64 para simulador, y los simuladores de iOS 26 en Apple Silicon solo ejecutan arm64, así que la app **no se puede ejecutar en un simulador de iOS** en un Mac con Apple Silicon. Usa un iPhone real o un emulador/teléfono Android; las pruebas de integración se ejecutan en Android (`flutter test integration_test -d <emulador>`). Para comprobar que iOS compila: `flutter build ios --no-codesign`.

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

Los títulos de PR y los mensajes de commit siguen la [convención de títulos](#convención-de-títulos-de-pr-y-commits).

**Publicar una versión en Firebase App Distribution:** la app de Firebase, el grupo de testers `testers` y los secretos del environment `release` ya están configurados (ver [Firma de release](#firma-de-release-android)). Para publicar, ejecuta el workflow manualmente desde `main` (eligiendo grupos y notas de versión) o sube un tag desde `main`, por ejemplo `v1.0.0`. El job espera tu aprobación del environment `release` antes de usar los secretos.

**Verificación del tag:** antes de compilar, el workflow comprueba con `scripts/check_release_version.sh` que la versión del tag (`v1.1.0`) coincida con la de `pubspec.yaml` y que `CHANGELOG.md` tenga la sección `[1.1.0]`. Si no coinciden, por ejemplo porque el tag se creó sobre un `main` desactualizado, el run falla antes de gastar tiempo de compilación y no se publica nada. En ejecuciones manuales no se aplica.

**Notas de la versión:** se generan solas desde `CHANGELOG.md` con `scripts/release_notes.sh`. Con un tag `vX.Y.Z` se usa la sección `[X.Y.Z]`; en una ejecución manual se usa la versión de `pubspec.yaml`. Si esa sección no existe se usa `[Sin publicar]`, y si tampoco hay contenido, el texto `Build X.Y.Z`. En una ejecución manual también puedes escribir las notas a mano en el campo `release_notes`, que tiene prioridad. Firebase muestra las notas en la consola y en el correo a los testers, con un máximo de 5000 caracteres (el script recorta a 4000).

Notas: la firma de release se describe en la sección siguiente. La distribución en iOS no está configurada porque requiere certificados de firma y perfiles de aprovisionamiento.

## Convención de títulos de PR y commits

Los títulos de PR y la primera línea de cada commit usan **Conventional Commits**, siempre en inglés y solo con caracteres ASCII:

```
<type>(<scope>): <description>
```

El alcance `(<scope>)` es opcional, y un `!` antes de los dos puntos marca un cambio que rompe compatibilidad.

| Tipo | Cuándo usarlo |
|---|---|
| `feat` | Funcionalidad nueva |
| `fix` | Corrección de un bug |
| `docs` | Solo documentación |
| `refactor` | Cambio interno sin cambio funcional |
| `test` | Solo pruebas |
| `chore` | Mantenimiento, dependencias, configuración, releases |
| `ci` | Workflows, hooks y scripts |
| `build` | Sistema de build, Gradle, `pubspec.yaml` |
| `perf` | Mejora de rendimiento |
| `style` | Formato, sin cambio de lógica |
| `revert` | Revierte un cambio anterior |

Reglas:

- El tipo va en minúsculas; el alcance, en minúsculas con letras, números o guiones (`scanner`, `android`, `crop-screen`).
- Después de los dos puntos va un espacio y una descripción de al menos 3 caracteres, en imperativo y sin punto final: `add flash toggle`, no `added` ni `Se agregó`.
- Con squash merge, el título del PR pasa a ser el mensaje del commit en `develop`.

```
feat(scanner): add flash toggle          ✔ válido
fix(crop): keep corners inside the image ✔ válido
chore(release): prepare version 1.0.0    ✔ válido
feat(android)!: require minSdk 26        ✔ válido
Release/1.0.0                            ✘ título automático de GitHub
Add flash toggle                         ✘ falta el tipo
feat: Agregar flash                      ✘ no está en inglés
feat(Scanner): add flash                 ✘ alcance con mayúscula
feat(scanner):add flash                  ✘ falta el espacio
```

> GitHub rellena el título del PR con el nombre de la rama. **Cámbialo antes de crear el PR**: `PR validation` lo rechaza si no cumple el patrón.

El patrón exacto que valida el workflow es:

```
^(feat|fix|chore|docs|refactor|test|ci|perf|build|style|revert)(\([a-z0-9-]+\))?!?: .{3,}$
```

El hook `commit-msg` aplica la misma regla a los commits locales. Los nombres de rama usan `<tipo>/<kebab-case>` (ver [Estrategia de ramas](#estrategia-de-ramas)).

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

- El zoom máximo es el que Android entrega a las apps de terceros: en un Galaxy S23 Ultra es 10x (`zoomRatioRange` 0,6 a 10), mientras que la app de cámara de Samsung llega a 100x con APIs propias del fabricante que el plugin `camera` no puede usar.
- Los factores 0,5x y 2x del cambio de lente en teléfonos con lentes separados son estimaciones: el plugin `camera` no expone las distancias focales, por lo que el encuadre puede dar un pequeño salto al cambiar. Solo se validó en un Galaxy S23 Ultra, que expone la multicámara lógica.
- La detección de bordes de `OpenCvImageProcessor` (`detectInFile`, `detectInFrame`) no tiene pruebas automatizadas; los filtros, el recorte y la reducción sí se verifican con OpenCV real en el simulador (`integration_test/opencv_filters_test.dart`).
- Solo hay dos idiomas (inglés y español) y no existe un selector de idioma dentro de la app.
- El OCR solo conoce la escritura latina (inglés, español, francés, etc.); no reconoce chino, japonés, coreano, devanagari ni árabe. La precisión depende de la calidad de la foto.
- Los PDFs importados de versiones anteriores y los documentos ya guardados no tienen texto: el OCR se hace al guardar un escaneo nuevo, mientras las imágenes todavía existen. No hay forma de reconocer el texto después.
- El texto reconocido no se incrusta en el PDF: sirve para buscar y copiar dentro de la app, pero al compartir el PDF no es seleccionable.
- No hay etiquetas.
- Las carpetas son un solo nivel (no hay subcarpetas) y un documento pertenece a una sola carpeta.
- No están configurados la firma de release, la distribución en iOS ni el versionado automático.
