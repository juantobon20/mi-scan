import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Mi Scan'**
  String get appName;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get homeTitle;

  /// No description provided for @homeEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no documents yet.\nTap the camera to scan your first one.'**
  String get homeEmpty;

  /// No description provided for @homeLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load documents'**
  String get homeLoadError;

  /// No description provided for @menuShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get menuShare;

  /// No description provided for @menuRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get menuRename;

  /// No description provided for @menuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get menuDelete;

  /// No description provided for @renameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameTitle;

  /// No description provided for @deleteDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete document?'**
  String get deleteDocumentTitle;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get actionDiscard;

  /// No description provided for @actionKeepScanning.
  ///
  /// In en, this message translates to:
  /// **'Keep scanning'**
  String get actionKeepScanning;

  /// No description provided for @actionCreatePdf.
  ///
  /// In en, this message translates to:
  /// **'Create PDF'**
  String get actionCreatePdf;

  /// No description provided for @actionRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get actionRotate;

  /// No description provided for @actionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get actionOpenSettings;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @pdfNameTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF name'**
  String get pdfNameTitle;

  /// No description provided for @pdfCreateError.
  ///
  /// In en, this message translates to:
  /// **'Could not create the PDF: {error}'**
  String pdfCreateError(String error);

  /// No description provided for @scanDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Scan {timestamp}'**
  String scanDefaultName(String timestamp);

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission denied. Enable it in Settings to scan.'**
  String get cameraPermissionDenied;

  /// No description provided for @cameraError.
  ///
  /// In en, this message translates to:
  /// **'Camera error: {details}'**
  String cameraError(String details);

  /// No description provided for @cameraOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera'**
  String get cameraOpenError;

  /// No description provided for @takePhotoError.
  ///
  /// In en, this message translates to:
  /// **'Could not take the photo: {error}'**
  String takePhotoError(String error);

  /// No description provided for @discardScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this scan?'**
  String get discardScanTitle;

  /// No description provided for @discardScanMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unsaved page will be lost.} other{{count} unsaved pages will be lost.}}'**
  String discardScanMessage(int count);

  /// No description provided for @galleryButton.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryButton;

  /// No description provided for @cropTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust edges'**
  String get cropTitle;

  /// No description provided for @cropTitleProgress.
  ///
  /// In en, this message translates to:
  /// **'Adjust edges ({current}/{total})'**
  String cropTitleProgress(int current, int total);

  /// No description provided for @cropSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get cropSelectAll;

  /// No description provided for @cropDetectEdges.
  ///
  /// In en, this message translates to:
  /// **'Detect edges'**
  String get cropDetectEdges;

  /// No description provided for @cropNotDetected.
  ///
  /// In en, this message translates to:
  /// **'Document not detected'**
  String get cropNotDetected;

  /// No description provided for @cropHint.
  ///
  /// In en, this message translates to:
  /// **'Move the corners to fit the document'**
  String get cropHint;

  /// No description provided for @cropError.
  ///
  /// In en, this message translates to:
  /// **'Could not crop: {error}'**
  String cropError(String error);

  /// No description provided for @filterOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get filterOriginal;

  /// No description provided for @filterEnhanced.
  ///
  /// In en, this message translates to:
  /// **'Enhanced'**
  String get filterEnhanced;

  /// No description provided for @filterGrayscale.
  ///
  /// In en, this message translates to:
  /// **'Grayscale'**
  String get filterGrayscale;

  /// No description provided for @filterBlackAndWhite.
  ///
  /// In en, this message translates to:
  /// **'B&W'**
  String get filterBlackAndWhite;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String reviewTitle(int count);

  /// No description provided for @reviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pages'**
  String get reviewEmpty;

  /// No description provided for @reviewPage.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String reviewPage(int number);

  /// No description provided for @reviewReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press to reorder'**
  String get reviewReorderHint;

  /// No description provided for @galleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose images'**
  String get galleryTitle;

  /// No description provided for @gallerySelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String gallerySelected(int count);

  /// No description provided for @galleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No images'**
  String get galleryEmpty;

  /// No description provided for @galleryNoPermission.
  ///
  /// In en, this message translates to:
  /// **'No permission to access photos.'**
  String get galleryNoPermission;

  /// No description provided for @galleryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add ({count})'**
  String galleryAdd(int count);

  /// No description provided for @flashTooltip.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get flashTooltip;

  /// No description provided for @torchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Flashlight'**
  String get torchTooltip;

  /// No description provided for @modeSingle.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get modeSingle;

  /// No description provided for @modeBatch.
  ///
  /// In en, this message translates to:
  /// **'Batch'**
  String get modeBatch;

  /// No description provided for @batchDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get batchDone;

  /// No description provided for @zoomTooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get zoomTooltip;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
