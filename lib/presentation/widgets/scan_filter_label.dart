import '../../core/l10n/l10n.dart';
import '../../domain/entities/scan_filter.dart';

extension ScanFilterLabel on ScanFilter {
  String label(AppLocalizations l10n) => switch (this) {
        ScanFilter.original => l10n.filterOriginal,
        ScanFilter.enhanced => l10n.filterEnhanced,
        ScanFilter.grayscale => l10n.filterGrayscale,
        ScanFilter.blackAndWhite => l10n.filterBlackAndWhite,
      };
}
