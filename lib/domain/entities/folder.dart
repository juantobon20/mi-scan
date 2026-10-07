class Folder {
  const Folder({required this.id, required this.name, required this.createdAt});

  final String id;
  final String name;
  final DateTime createdAt;

  Folder copyWith({String? name}) => Folder(id: id, name: name ?? this.name, createdAt: createdAt);

  @override
  bool operator ==(Object other) =>
      other is Folder && other.id == id && other.name == name && other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, createdAt);

  @override
  String toString() => 'Folder($id, $name)';
}

class FolderSummary {
  const FolderSummary(this.folder, this.documentCount);

  final Folder folder;
  final int documentCount;

  @override
  bool operator ==(Object other) =>
      other is FolderSummary && other.folder == folder && other.documentCount == documentCount;

  @override
  int get hashCode => Object.hash(folder, documentCount);
}
