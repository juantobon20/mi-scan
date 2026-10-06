import 'package:share_plus/share_plus.dart';

import '../../domain/services/share_service.dart';

class SharePlusService implements ShareService {
  @override
  Future<void> sharePdf(String path, {String? subject}) => SharePlus.instance.share(
        ShareParams(files: [XFile(path, mimeType: 'application/pdf')], subject: subject),
      );
}
