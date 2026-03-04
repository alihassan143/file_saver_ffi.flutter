abstract interface class FileEntity {
  Future<bool> exists(String path);
  Future<void> delete(String path);
}
