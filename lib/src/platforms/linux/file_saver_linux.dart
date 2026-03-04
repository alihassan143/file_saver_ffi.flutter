import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xdg_directories/xdg_directories.dart' as xdg;

import '../../models/locations/save_location.dart';
import '../../platform_interface/file_saver_platform.dart';
import '../shared/desktop_file_saver.dart';

/// FileSaver implementation for Linux.
///
/// Extends [DesktopFileSaver] — only [resolveDirectory] is platform-specific.
/// Directory resolution uses the XDG Base Directory Specification (`xdg-user-dirs`).
/// Falls back to `~/.cache/Downloads` if the XDG variable is not configured.
class FileSaverLinux extends DesktopFileSaver {
  /// Registers this class as the default instance of [FileSaverPlatform].
  static void registerWith() {
    FileSaverPlatform.instance = FileSaverLinux();
  }

  @override
  Future<String> resolveDirectory(
    SaveLocation? saveLocation,
    String? subDir,
  ) async {
    final xdgKey = switch (saveLocation) {
      LinuxSaveLocation.downloads => 'DOWNLOAD',
      LinuxSaveLocation.pictures => 'PICTURES',
      LinuxSaveLocation.videos => 'VIDEOS',
      LinuxSaveLocation.music => 'MUSIC',
      LinuxSaveLocation.documents => 'DOCUMENTS',
      _ => 'DOWNLOAD',
    };

    final basePath =
        xdg.getUserDirectory(xdgKey)?.path ??
        p.join(Platform.environment['HOME'] ?? '', 'Downloads');

    final dirPath = subDir != null ? p.join(basePath, subDir) : basePath;
    await Directory(dirPath).create(recursive: true);
    return dirPath;
  }
}
