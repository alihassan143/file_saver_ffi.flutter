import 'dart:io';

import 'file_entity.dart';

class IOFileEntity implements FileEntity {
  const IOFileEntity();

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<void> delete(String path) => File(path).delete();
}
