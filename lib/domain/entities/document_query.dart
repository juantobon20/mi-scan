class DocumentQuery {
  const DocumentQuery({this.folderId, this.text = ''});

  final String? folderId;

  final String text;

  bool get hasText => text.trim().isNotEmpty;

  DocumentQuery copyWith({String? folderId, bool clearFolder = false, String? text}) => DocumentQuery(
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        text: text ?? this.text,
      );

  @override
  bool operator ==(Object other) => other is DocumentQuery && other.folderId == folderId && other.text == text;

  @override
  int get hashCode => Object.hash(folderId, text);
}
