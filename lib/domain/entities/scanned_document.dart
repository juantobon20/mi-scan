class ScannedDocument {
  const ScannedDocument({
    required this.pdfPath,
    required this.name,
    required this.modified,
    required this.sizeBytes,
    this.thumbPath,
  });

  final String pdfPath;
  final String name;
  final DateTime modified;
  final int sizeBytes;

  final String? thumbPath;

  @override
  bool operator ==(Object other) =>
      other is ScannedDocument &&
      other.pdfPath == pdfPath &&
      other.name == name &&
      other.modified == modified &&
      other.sizeBytes == sizeBytes &&
      other.thumbPath == thumbPath;

  @override
  int get hashCode => Object.hash(pdfPath, name, modified, sizeBytes, thumbPath);
}
