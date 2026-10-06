abstract interface class ShareService {
  Future<void> sharePdf(String path, {String? subject});
}

abstract interface class SessionStorage {
  Future<String> createSessionDir();
}
