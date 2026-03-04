import '../../exceptions/file_saver_exceptions.dart';
import '../../models/conflict_resolution.dart';
import 'file_entity.dart';

class ConflictResolver {
  const ConflictResolver(this._entity);

  final FileEntity _entity;

  /// Resolves the path/filename based on conflict mode.
  ///
  /// Returns the resolved path, or `null` if [ConflictResolution.skip].
  /// Throws [FileExistsException] if [ConflictResolution.fail] and file exists.
  Future<String?> resolve(String path, ConflictResolution mode) async {
    if (!await _entity.exists(path)) return path;

    return switch (mode) {
      ConflictResolution.skip => null,
      ConflictResolution.overwrite => path,
      ConflictResolution.autoRename => await _autoRename(path),
      ConflictResolution.fail => throw FileExistsException(path),
    };
  }

  /// Tries `name (1).ext`, `name (2).ext`, ... up to `name (1000).ext`.
  ///
  /// Works for both full paths (Desktop) and bare filenames (Web).
  Future<String> _autoRename(String path) async {
    final dotIndex = path.lastIndexOf('.');
    final base = dotIndex >= 0 ? path.substring(0, dotIndex) : path;
    final ext = dotIndex >= 0 ? path.substring(dotIndex) : '';

    for (int i = 1; i <= 1000; i++) {
      final candidate = '$base ($i)$ext';
      if (!await _entity.exists(candidate)) return candidate;
    }

    throw const FileIOException(
      'Could not find available filename after 1000 attempts',
    );
  }
}
