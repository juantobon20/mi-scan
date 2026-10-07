import '../entities/folder.dart';

abstract interface class FolderRepository {
  Future<List<FolderSummary>> list();

  Future<Folder> create(String name);

  Future<Folder> rename(Folder folder, String newName);

  Future<void> delete(Folder folder);
}
