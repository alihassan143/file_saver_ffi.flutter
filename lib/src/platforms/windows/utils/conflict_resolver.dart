import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../exceptions/file_saver_exceptions.dart';
import '../../../models/conflict_resolution.dart';

class ConflictResolver {
  /// Resolves file path based on conflict mode.
  ///
  /// Returns the resolved file path, or `null` if [ConflictResolution.skip].
  /// Throws [FileExistsException] if [ConflictResolution.fail] and file exists.
  static Future<String?> resolve(
    String filePath,
    ConflictResolution mode,
  ) async {
    if (!await File(filePath).exists()) return filePath;

    return switch (mode) {
      ConflictResolution.autoRename => _autoRename(filePath),
      ConflictResolution.overwrite => _overwrite(filePath),
      ConflictResolution.fail =>
        throw FileExistsException(p.basename(filePath)),
      ConflictResolution.skip => null,
    };
  }

  static Future<String> _overwrite(String filePath) async {
    await File(filePath).delete();
    return filePath;
  }

  /// Tries `name (1).ext`, `name (2).ext`, ... up to `name (1000).ext`.
  static Future<String> _autoRename(String filePath) async {
    final dir = p.dirname(filePath);
    final nameWithoutExt = p.basenameWithoutExtension(filePath);
    final ext = p.extension(filePath); // includes dot, e.g. ".jpg"

    for (int i = 1; i <= 1000; i++) {
      final candidate = p.join(dir, '$nameWithoutExt ($i)$ext');
      if (!await File(candidate).exists()) return candidate;
    }

    throw const FileIOException(
      'Could not find available filename after 1000 attempts',
    );
  }
}
