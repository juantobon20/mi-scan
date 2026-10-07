// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Mi Scan';

  @override
  String get homeTitle => 'Recientes';

  @override
  String get homeEmpty =>
      'Aún no tienes documentos.\nToca la cámara para escanear el primero.';

  @override
  String get homeLoadError => 'No se pudieron cargar los documentos';

  @override
  String get menuShare => 'Compartir';

  @override
  String get menuRename => 'Renombrar';

  @override
  String get menuDelete => 'Eliminar';

  @override
  String get renameTitle => 'Renombrar';

  @override
  String get deleteDocumentTitle => '¿Eliminar documento?';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionAdd => 'Agregar';

  @override
  String get actionNext => 'Siguiente';

  @override
  String get actionSkip => 'Omitir';

  @override
  String get actionDiscard => 'Descartar';

  @override
  String get actionKeepScanning => 'Seguir escaneando';

  @override
  String get actionCreatePdf => 'Crear PDF';

  @override
  String get actionRotate => 'Rotar';

  @override
  String get actionOpenSettings => 'Abrir ajustes';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get pdfNameTitle => 'Nombre del PDF';

  @override
  String pdfCreateError(String error) {
    return 'No se pudo crear el PDF: $error';
  }

  @override
  String scanDefaultName(String timestamp) {
    return 'Escaneo $timestamp';
  }

  @override
  String get cameraPermissionDenied =>
      'Permiso de cámara denegado. Actívalo en Ajustes para escanear.';

  @override
  String cameraError(String details) {
    return 'Error de cámara: $details';
  }

  @override
  String get cameraOpenError => 'No se pudo abrir la cámara';

  @override
  String takePhotoError(String error) {
    return 'No se pudo tomar la foto: $error';
  }

  @override
  String get discardScanTitle => '¿Descartar el escaneo?';

  @override
  String discardScanMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se perderán $count páginas sin guardar.',
      one: 'Se perderá 1 página sin guardar.',
    );
    return '$_temp0';
  }

  @override
  String get galleryButton => 'Galería';

  @override
  String get cropTitle => 'Ajustar bordes';

  @override
  String cropTitleProgress(int current, int total) {
    return 'Ajustar bordes ($current/$total)';
  }

  @override
  String get cropSelectAll => 'Seleccionar todo';

  @override
  String get cropDetectEdges => 'Detectar bordes';

  @override
  String get cropNotDetected => 'No se detectó el documento';

  @override
  String get cropHint => 'Mueve las esquinas para ajustar el documento';

  @override
  String cropError(String error) {
    return 'No se pudo recortar: $error';
  }

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterEnhanced => 'Mejorado';

  @override
  String get filterGrayscale => 'Grises';

  @override
  String get filterBlackAndWhite => 'B/N';

  @override
  String reviewTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count páginas',
      one: '1 página',
    );
    return '$_temp0';
  }

  @override
  String get reviewEmpty => 'No hay páginas';

  @override
  String reviewPage(int number) {
    return 'Página $number';
  }

  @override
  String get reviewReorderHint => 'Mantén pulsado para reordenar';

  @override
  String get galleryTitle => 'Elegir imágenes';

  @override
  String gallerySelected(int count) {
    return '$count seleccionada(s)';
  }

  @override
  String get galleryEmpty => 'No hay imágenes';

  @override
  String get galleryNoPermission => 'Sin permiso para acceder a las fotos.';

  @override
  String galleryAdd(int count) {
    return 'Agregar ($count)';
  }

  @override
  String get flashTooltip => 'Flash';

  @override
  String get torchTooltip => 'Linterna';

  @override
  String get modeSingle => 'Individual';

  @override
  String get modeBatch => 'Lote';

  @override
  String get batchDone => 'Listo';

  @override
  String get zoomTooltip => 'Zoom';

  @override
  String get searchTooltip => 'Buscar';

  @override
  String get searchClearTooltip => 'Borrar búsqueda';

  @override
  String get searchHint => 'Buscar documentos';

  @override
  String searchNoResults(String query) {
    return 'Ningún documento coincide con \"$query\".';
  }

  @override
  String get folderAll => 'Todos';

  @override
  String get folderNew => 'Nueva carpeta';

  @override
  String get folderNameTitle => 'Nombre de la carpeta';

  @override
  String get folderEmpty =>
      'Esta carpeta está vacía.\nMueve un documento aquí o escanea uno nuevo.';

  @override
  String get folderRename => 'Renombrar carpeta';

  @override
  String get folderDelete => 'Eliminar carpeta';

  @override
  String get folderDeleteTitle => '¿Eliminar carpeta?';

  @override
  String folderDeleteMessage(String name) {
    return 'Se eliminará \"$name\". Sus documentos se conservan y quedan fuera de la carpeta.';
  }

  @override
  String get menuMove => 'Mover a carpeta';

  @override
  String get moveTitle => 'Mover a';

  @override
  String get moveNoFolder => 'Sin carpeta';

  @override
  String genericError(String error) {
    return 'Algo salió mal: $error';
  }
}
