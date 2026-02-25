import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider_windows/path_provider_windows.dart';

import '../../exceptions/file_saver_exceptions.dart';
import '../../models/conflict_resolution.dart';
import '../../models/file_type.dart';
import '../../models/save_input.dart';
import '../../models/save_location.dart';
import '../../models/save_progress.dart';
import '../../platform_interface/file_saver_platform.dart';
import 'utils/conflict_resolver.dart';
import 'utils/folder_picker.dart';

// Windows Known Folder GUIDs — mirrors WindowsKnownFolder from path_provider_windows.
// Defined locally because the analyzer on non-Windows resolves the stub class
// (empty WindowsKnownFolder {}) instead of the real one with static getters.
const String _kDownloads = '{374DE290-123F-4565-9164-39C4925E467B}';
const String _kPictures = '{33E28130-4E1E-4676-835A-98395C3BC3BB}';
const String _kVideos = '{18989B1D-99B5-455B-841C-AB7C74E4DDFC}';
const String _kMusic = '{4BD8D571-6D19-48D3-BE97-422220080E43}';
const String _kDocuments = '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}';

/// 1MB chunk size for progress reporting.
const int _chunkSize = 1048576;

/// FileSaver implementation for Windows.
///
/// Uses Dart FFI throughout — no native C++ plugin code:
/// - [PathProviderWindows] resolves Known Folder paths via [SHGetKnownFolderPath] (dart:ffi)
/// - [dart:io] handles all file read/write operations
/// - [FolderPicker] calls COM [IFileOpenDialog] directly via dart:ffi
class FileSaverWindows extends FileSaverPlatform {
  final _pathProvider = PathProviderWindows();
  final _httpClient = HttpClient();
  int _nextTokenId = 1;
  final _activeTokens = <int, _CancellationToken>{};

  @override
  void dispose() {
    for (final token in _activeTokens.values) {
      token.cancel();
    }
    _activeTokens.clear();
    _httpClient.close();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save operations
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Stream<SaveProgress> saveBytes({
    required Uint8List fileBytes,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    validateBytesInput(fileBytes, fileName);

    return _executeSave((token, controller) async {
      final dir = await _resolveDirectory(saveLocation, subDir);
      final filePath = p.join(dir, '$fileName.${fileType.ext}');
      final resolved = await ConflictResolver.resolve(
        filePath,
        conflictResolution,
      );
      if (resolved == null) {
        controller.add(SaveProgressComplete(Uri.file(filePath)));
        return;
      }

      await _writeBytes(resolved, fileBytes, token, controller);
      controller.add(SaveProgressComplete(Uri.file(resolved)));
    });
  }

  @override
  Stream<SaveProgress> saveFile({
    required String filePath,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    validateFilePathInput(filePath, fileName);

    return _executeSave((token, controller) async {
      final sourcePath = _toFilePath(filePath);
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw SourceFileNotFoundException(sourcePath);
      }

      final dir = await _resolveDirectory(saveLocation, subDir);
      final destPath = p.join(dir, '$fileName.${fileType.ext}');
      final resolved = await ConflictResolver.resolve(
        destPath,
        conflictResolution,
      );
      if (resolved == null) {
        controller.add(SaveProgressComplete(Uri.file(destPath)));
        return;
      }

      await _copyFile(source, resolved, token, controller);
      controller.add(SaveProgressComplete(Uri.file(resolved)));
    });
  }

  @override
  Stream<SaveProgress> saveNetwork({
    required String url,
    required String fileName,
    required FileType fileType,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 60),
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    validateNetworkInput(url, fileName);

    return _executeSave((token, controller) async {
      final dir = await _resolveDirectory(saveLocation, subDir);
      final destPath = p.join(dir, '$fileName.${fileType.ext}');
      final resolved = await ConflictResolver.resolve(
        destPath,
        conflictResolution,
      );
      if (resolved == null) {
        controller.add(SaveProgressComplete(Uri.file(destPath)));
        return;
      }

      await _downloadToFile(url, headers, timeout, resolved, token, controller);
      controller.add(SaveProgressComplete(Uri.file(resolved)));
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // User-Selected Location (Folder Picker)
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<UserSelectedLocation?> pickDirectory({
    bool shouldPersist = true,
  }) async {
    final path = await FolderPicker.pick();
    if (path == null) return null;
    return UserSelectedLocation(uri: Uri.directory(path));
  }

  @override
  Stream<SaveProgress> saveAs({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    required UserSelectedLocation saveLocation,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    final dirPath = saveLocation.uri.toFilePath();
    return switch (input) {
      SaveBytesInput(:final fileBytes) => _saveBytesTo(
        fileBytes: fileBytes,
        dirPath: dirPath,
        fileName: fileName,
        ext: fileType.ext,
        conflictResolution: conflictResolution,
      ),
      SaveFileInput(:final filePath) => _saveFileTo(
        filePath: filePath,
        dirPath: dirPath,
        fileName: fileName,
        ext: fileType.ext,
        conflictResolution: conflictResolution,
      ),
      SaveNetworkInput(:final url, :final headers, :final timeout) =>
        _saveNetworkTo(
          url: url,
          headers: headers,
          timeout: timeout,
          dirPath: dirPath,
          fileName: fileName,
          ext: fileType.ext,
          conflictResolution: conflictResolution,
        ),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SaveAs helpers
  // ─────────────────────────────────────────────────────────────────────────

  Stream<SaveProgress> _saveBytesTo({
    required Uint8List fileBytes,
    required String dirPath,
    required String fileName,
    required String ext,
    required ConflictResolution conflictResolution,
  }) {
    return _executeSave((token, controller) async {
      final filePath = p.join(dirPath, '$fileName.$ext');
      final resolved = await ConflictResolver.resolve(
        filePath,
        conflictResolution,
      );
      if (resolved == null) {
        controller.add(SaveProgressComplete(Uri.file(filePath)));
        return;
      }

      await _writeBytes(resolved, fileBytes, token, controller);
      controller.add(SaveProgressComplete(Uri.file(resolved)));
    });
  }

  Stream<SaveProgress> _saveFileTo({
    required String filePath,
    required String dirPath,
    required String fileName,
    required String ext,
    required ConflictResolution conflictResolution,
  }) {
    return _executeSave((token, controller) async {
      final sourcePath = _toFilePath(filePath);
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw SourceFileNotFoundException(sourcePath);
      }

      final destPath = p.join(dirPath, '$fileName.$ext');
      final resolved = await ConflictResolver.resolve(
        destPath,
        conflictResolution,
      );
      if (resolved == null) {
        controller.add(SaveProgressComplete(Uri.file(destPath)));
        return;
      }

      await _copyFile(source, resolved, token, controller);
      controller.add(SaveProgressComplete(Uri.file(resolved)));
    });
  }

  Stream<SaveProgress> _saveNetworkTo({
    required String url,
    required Map<String, String>? headers,
    required Duration timeout,
    required String dirPath,
    required String fileName,
    required String ext,
    required ConflictResolution conflictResolution,
  }) {
    return _executeSave((token, controller) async {
      final destPath = p.join(dirPath, '$fileName.$ext');
      final resolved = await ConflictResolver.resolve(
        destPath,
        conflictResolution,
      );
      if (resolved == null) {
        controller.add(SaveProgressComplete(Uri.file(destPath)));
        return;
      }

      await _downloadToFile(url, headers, timeout, resolved, token, controller);
      controller.add(SaveProgressComplete(Uri.file(resolved)));
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Core I/O operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _writeBytes(
    String filePath,
    Uint8List bytes,
    _CancellationToken token,
    StreamController<SaveProgress> controller,
  ) async {
    final file = File(filePath);
    final sink = file.openWrite();
    final total = bytes.length;
    int written = 0;

    try {
      for (int offset = 0; offset < total; offset += _chunkSize) {
        if (token.isCancelled) {
          await sink.close();
          await file.delete();
          return;
        }
        final end = (offset + _chunkSize).clamp(0, total);
        sink.add(bytes.sublist(offset, end));
        written = end;
        controller.add(SaveProgressUpdate(written / total));
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<void> _copyFile(
    File source,
    String destPath,
    _CancellationToken token,
    StreamController<SaveProgress> controller,
  ) async {
    final total = await source.length();
    final dest = File(destPath);
    final sink = dest.openWrite();
    int copied = 0;

    try {
      await for (final chunk in source.openRead()) {
        if (token.isCancelled) {
          await sink.close();
          await dest.delete();
          return;
        }
        sink.add(chunk);
        copied += chunk.length;
        controller.add(SaveProgressUpdate(copied / total));
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      await sink.close();
      if (await dest.exists()) await dest.delete();
      rethrow;
    }
  }

  Future<void> _downloadToFile(
    String url,
    Map<String, String>? headers,
    Duration timeout,
    String destPath,
    _CancellationToken token,
    StreamController<SaveProgress> controller,
  ) async {
    _httpClient.connectionTimeout = timeout;

    final request = await _httpClient.getUrl(Uri.parse(url));
    token.activeRequest = request;
    headers?.forEach(request.headers.add);

    final response = await request.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw NetworkException(
        'HTTP ${response.statusCode}',
        response.statusCode,
      );
    }

    final total = response.contentLength;
    final dest = File(destPath);
    final sink = dest.openWrite();
    int downloaded = 0;

    try {
      await for (final chunk in response) {
        if (token.isCancelled) {
          await sink.close();
          await dest.delete();
          return;
        }
        sink.add(chunk);
        downloaded += chunk.length;
        if (total > 0) {
          controller.add(SaveProgressUpdate(downloaded / total));
        }
      }
      await sink.flush();
      await sink.close();
      token.activeRequest = null;
    } catch (e) {
      await sink.close();
      if (await dest.exists()) await dest.delete();
      if (token.isCancelled) return;
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────────────────────────────────

  Stream<SaveProgress> _executeSave(
    Future<void> Function(
      _CancellationToken token,
      StreamController<SaveProgress> controller,
    )
    operation,
  ) {
    return Stream.multi((controller) {
      final tokenId = _nextTokenId++;
      final token = _CancellationToken();
      _activeTokens[tokenId] = token;

      controller.addSync(const SaveProgressStarted());

      operation(token, controller)
          .then((_) {
            _activeTokens.remove(tokenId);
            if (!controller.isClosed) controller.closeSync();
          })
          .catchError((Object e) {
            _activeTokens.remove(tokenId);
            if (token.isCancelled) {
              if (!controller.isClosed) {
                controller.addSync(const SaveProgressCancelled());
                controller.closeSync();
              }
              return;
            }
            if (!controller.isClosed) {
              controller.addSync(
                SaveProgressError(FileSaverException.fromObj(e)),
              );
              controller.closeSync();
            }
          });

      controller.onCancel = () {
        token.cancel();
        _activeTokens.remove(tokenId);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!controller.isClosed) {
            controller.addSync(const SaveProgressCancelled());
            controller.closeSync();
          }
        });
      };
    });
  }

  Future<String> _resolveDirectory(
    SaveLocation? saveLocation,
    String? subDir,
  ) async {
    final folderGuid = switch (saveLocation) {
      WindowsSaveLocation.downloads => _kDownloads,
      WindowsSaveLocation.pictures => _kPictures,
      WindowsSaveLocation.videos => _kVideos,
      WindowsSaveLocation.music => _kMusic,
      WindowsSaveLocation.documents => _kDocuments,
      _ => _kDownloads,
    };

    final basePath = await _pathProvider.getPath(folderGuid);
    // The stub PathProviderWindows (used by the analyzer on non-Windows) declares
    // getPath() as Future<String> (non-nullable), but the real implementation
    // returns Future<String?> (nullable). The null check is necessary at runtime.
    // ignore: unnecessary_null_comparison
    if (basePath == null || basePath.isEmpty) {
      throw const PlatformException(
        'Could not resolve save directory',
        'PLATFORM_ERROR',
      );
    }

    final dirPath = subDir != null ? p.join(basePath, subDir) : basePath;
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dirPath;
  }

  String _toFilePath(String filePath) {
    if (filePath.startsWith('file://')) {
      return Uri.parse(filePath).toFilePath();
    }
    return filePath;
  }
}

class _CancellationToken {
  bool isCancelled = false;
  HttpClientRequest? activeRequest;

  void cancel() {
    isCancelled = true;
    activeRequest?.abort();
  }
}
