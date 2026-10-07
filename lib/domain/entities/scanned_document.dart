class ScannedDocument {
  const ScannedDocument({
    required this.id,
    required this.pdfPath,
    required this.name,
    required this.modified,
    required this.sizeBytes,
    this.thumbPath,
    this.folderId,
    this.pageCount = 0,
    this.createdAt,
    this.hasText = false,
  });

  final String id;
  final String pdfPath;
  final String name;
  final DateTime modified;
  final DateTime? createdAt;
  final int sizeBytes;
  final int pageCount;

  final String? thumbPath;

  final String? folderId;

  final bool hasText;

  ScannedDocument copyWith({
    String? name,
    String? pdfPath,
    String? thumbPath,
    bool clearThumb = false,
    DateTime? modified,
  }) =>
      ScannedDocument(
        id: id,
        pdfPath: pdfPath ?? this.pdfPath,
        name: name ?? this.name,
        modified: modified ?? this.modified,
        createdAt: createdAt,
        sizeBytes: sizeBytes,
        pageCount: pageCount,
        thumbPath: clearThumb ? null : (thumbPath ?? this.thumbPath),
        folderId: folderId,
        hasText: hasText,
      );

  ScannedDocument movedTo(String? folderId) => ScannedDocument(
        id: id,
        pdfPath: pdfPath,
        name: name,
        modified: modified,
        createdAt: createdAt,
        sizeBytes: sizeBytes,
        pageCount: pageCount,
        thumbPath: thumbPath,
        folderId: folderId,
        hasText: hasText,
      );

  ScannedDocument withText({required bool hasText}) => ScannedDocument(
        id: id,
        pdfPath: pdfPath,
        name: name,
        modified: modified,
        createdAt: createdAt,
        sizeBytes: sizeBytes,
        pageCount: pageCount,
        thumbPath: thumbPath,
        folderId: folderId,
        hasText: hasText,
      );

  @override
  bool operator ==(Object other) =>
      other is ScannedDocument &&
      other.id == id &&
      other.pdfPath == pdfPath &&
      other.name == name &&
      other.modified == modified &&
      other.createdAt == createdAt &&
      other.sizeBytes == sizeBytes &&
      other.pageCount == pageCount &&
      other.thumbPath == thumbPath &&
      other.folderId == folderId &&
      other.hasText == hasText;

  @override
  int get hashCode => Object.hash(id, pdfPath, name, modified, createdAt, sizeBytes, pageCount, thumbPath, folderId, hasText);

  @override
  String toString() => 'ScannedDocument($id, $name, folder: $folderId)';
}
