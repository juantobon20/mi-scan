// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Mi Scan';

  @override
  String get homeTitle => 'Recent';

  @override
  String get homeEmpty =>
      'You have no documents yet.\nTap the camera to scan your first one.';

  @override
  String get homeLoadError => 'Could not load documents';

  @override
  String get menuShare => 'Share';

  @override
  String get menuRename => 'Rename';

  @override
  String get menuDelete => 'Delete';

  @override
  String get renameTitle => 'Rename';

  @override
  String get deleteDocumentTitle => 'Delete document?';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionSave => 'Save';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionNext => 'Next';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionDiscard => 'Discard';

  @override
  String get actionKeepScanning => 'Keep scanning';

  @override
  String get actionCreatePdf => 'Create PDF';

  @override
  String get actionRotate => 'Rotate';

  @override
  String get actionOpenSettings => 'Open settings';

  @override
  String get actionRetry => 'Retry';

  @override
  String get pdfNameTitle => 'PDF name';

  @override
  String pdfCreateError(String error) {
    return 'Could not create the PDF: $error';
  }

  @override
  String scanDefaultName(String timestamp) {
    return 'Scan $timestamp';
  }

  @override
  String get cameraPermissionDenied =>
      'Camera permission denied. Enable it in Settings to scan.';

  @override
  String cameraError(String details) {
    return 'Camera error: $details';
  }

  @override
  String get cameraOpenError => 'Could not open the camera';

  @override
  String takePhotoError(String error) {
    return 'Could not take the photo: $error';
  }

  @override
  String get discardScanTitle => 'Discard this scan?';

  @override
  String discardScanMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unsaved pages will be lost.',
      one: '1 unsaved page will be lost.',
    );
    return '$_temp0';
  }

  @override
  String get galleryButton => 'Gallery';

  @override
  String get cropTitle => 'Adjust edges';

  @override
  String cropTitleProgress(int current, int total) {
    return 'Adjust edges ($current/$total)';
  }

  @override
  String get cropSelectAll => 'Select all';

  @override
  String get cropDetectEdges => 'Detect edges';

  @override
  String get cropNotDetected => 'Document not detected';

  @override
  String get cropHint => 'Move the corners to fit the document';

  @override
  String cropError(String error) {
    return 'Could not crop: $error';
  }

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterEnhanced => 'Enhanced';

  @override
  String get filterGrayscale => 'Grayscale';

  @override
  String get filterBlackAndWhite => 'B&W';

  @override
  String reviewTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get reviewEmpty => 'No pages';

  @override
  String reviewPage(int number) {
    return 'Page $number';
  }

  @override
  String get reviewReorderHint => 'Long-press to reorder';

  @override
  String get galleryTitle => 'Choose images';

  @override
  String gallerySelected(int count) {
    return '$count selected';
  }

  @override
  String get galleryEmpty => 'No images';

  @override
  String get galleryNoPermission => 'No permission to access photos.';

  @override
  String galleryAdd(int count) {
    return 'Add ($count)';
  }
}
