import '../entities/folder.dart';
import '../repositories/folder_repository.dart';

class ListFolders {
  ListFolders(this._repo);
  final FolderRepository _repo;
  Future<List<FolderSummary>> call() => _repo.list();
}

class CreateFolder {
  CreateFolder(this._repo);
  final FolderRepository _repo;

  Future<Folder> call(String name) {
    if (name.trim().isEmpty) throw ArgumentError('The folder name cannot be empty');
    return _repo.create(name);
  }
}

class RenameFolder {
  RenameFolder(this._repo);
  final FolderRepository _repo;

  Future<Folder> call(Folder folder, String name) {
    if (name.trim().isEmpty) throw ArgumentError('The folder name cannot be empty');
    return _repo.rename(folder, name);
  }
}

class DeleteFolder {
  DeleteFolder(this._repo);
  final FolderRepository _repo;
  Future<void> call(Folder folder) => _repo.delete(folder);
}
