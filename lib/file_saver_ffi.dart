library;

import 'package:flutter/foundation.dart';

import 'src/exceptions/file_saver_exceptions.dart';
import 'src/models/conflict_resolution.dart';
import 'src/models/file_type.dart';
import 'src/models/save_input.dart';
import 'src/models/locations/save_location.dart';
import 'src/models/save_progress.dart';
import 'src/platform_interface/file_saver_platform.dart';

// Public API
export 'src/exceptions/file_saver_exceptions.dart';
export 'src/models/conflict_resolution.dart';
export 'src/models/file_type.dart';
export 'src/models/save_input.dart';
export 'src/models/locations/save_location.dart';
export 'src/models/save_progress.dart';

export 'src/platforms/io_platforms.dart'
    if (dart.library.html) 'src/platforms/io_stub.dart';
export 'src/platforms/web/file_saver_web.dart'
    if (dart.library.io) 'src/platforms/web_stub.dart';

class FileSaver {
  FileSaver._();

  static FileSaverPlatform get _platform => FileSaverPlatform.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // Active API
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves a file to device storage with progress streaming.
  ///
  /// **Platforms:** Android · iOS · macOS · Windows · Linux · Web
  ///
  /// Selects the save strategy based on [input]:
  /// - [SaveBytesInput]: write bytes directly
  /// - [SaveFileInput]: stream from source path (memory-efficient for large files)
  /// - [SaveNetworkInput]: download then save natively
  ///
  /// Yields [SaveProgress] events:
  /// - [SaveProgressStarted]: operation began
  /// - [SaveProgressUpdate]: progress 0.0–1.0
  /// - [SaveProgressComplete]: success with [Uri]
  /// - [SaveProgressError]: failed with exception
  /// - [SaveProgressCancelled]: cancelled
  ///
  /// [saveLocation] defaults by platform:
  /// - Android: [AndroidSaveLocation.downloads]
  /// - iOS: [IosSaveLocation.documents]
  /// - macOS / Windows / Linux: user's Downloads folder
  /// - Web: ignored (browser controls the destination)
  static Stream<SaveProgress> save({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    return switch (input) {
      SaveBytesInput(:final fileBytes) => _platform.saveBytes(
        fileBytes: fileBytes,
        fileType: fileType,
        fileName: fileName,
        saveLocation: saveLocation,
        subDir: subDir,
        conflictResolution: conflictResolution,
      ),
      SaveFileInput(:final filePath) => _platform.saveFile(
        filePath: filePath,
        fileType: fileType,
        fileName: fileName,
        saveLocation: saveLocation,
        subDir: subDir,
        conflictResolution: conflictResolution,
      ),
      SaveNetworkInput(:final url, :final headers, :final timeout) => _platform
          .saveNetwork(
            url: url,
            fileType: fileType,
            fileName: fileName,
            headers: headers,
            timeout: timeout,
            saveLocation: saveLocation,
            subDir: subDir,
            conflictResolution: conflictResolution,
          ),
    };
  }

  /// [Future] wrapper for [save] with an optional [onProgress] callback.
  ///
  /// **Platforms:** Android · iOS · macOS · Windows · Linux · Web
  ///
  /// Returns the saved [Uri]. Throws on error; throws [CancelledException] if cancelled.
  static Future<Uri> saveAsync({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
  }) async {
    Uri? result;

    await for (final event in save(
      input: input,
      fileType: fileType,
      fileName: fileName,
      saveLocation: saveLocation,
      subDir: subDir,
      conflictResolution: conflictResolution,
    )) {
      switch (event) {
        case SaveProgressStarted():
          break;
        case SaveProgressUpdate(:final progress):
          onProgress?.call(progress);
        case SaveProgressComplete(:final uri):
          result = uri;
        case SaveProgressError(:final exception):
          throw exception;
        case SaveProgressCancelled():
          throw const CancelledException();
      }
    }

    if (result == null) {
      throw const PlatformException(
        'Save operation did not complete',
        'INCOMPLETE',
      );
    }
    return result;
  }

  /// Shows the system directory picker.
  ///
  /// **Platforms:** Android · iOS · macOS · Windows · Linux · Web
  ///
  /// [shouldPersist] is Android-only: if true, calls takePersistableUriPermission
  /// so the app can write to the selected directory across restarts without re-picking.
  /// Ignored on all other platforms.
  ///
  /// Returns [UserSelectedLocation], or null if cancelled.
  /// Throws [UnsupportedError] on browsers that do not support the File System Access API.
  static Future<UserSelectedLocation?> pickDirectory({
    bool shouldPersist = true,
  }) {
    return _platform.pickDirectory(shouldPersist: shouldPersist);
  }

  /// Saves to a user-selected directory with progress streaming.
  ///
  /// **Platforms:** Android · iOS · macOS · Windows · Linux · Web
  ///
  /// If [saveLocation] is null, shows the directory picker first.
  /// Yields [SaveProgressCancelled] if the picker is dismissed.
  ///
  /// Web: falls back to anchor-download if the browser does not support FSA.
  static Stream<SaveProgress> saveAs({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    UserSelectedLocation? saveLocation,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) async* {
    UserSelectedLocation? resolvedLocation = saveLocation;
    if (resolvedLocation == null) {
      try {
        final picked = await pickDirectory();
        if (picked == null) {
          yield const SaveProgressCancelled();
          return;
        }
        resolvedLocation = picked;
      } catch (e) {
        if (kIsWeb) {
          // Browser doesn't support FSA (Firefox / Safari).
          // Pass a plain UserSelectedLocation so FileSaverWeb.saveAs()
          // falls through to its anchor-download fallback.
          resolvedLocation = UserSelectedLocation(uri: Uri());
        } else {
          yield SaveProgressError(PlatformException(e.toString()));
          return;
        }
      }
    }

    yield* _platform.saveAs(
      input: input,
      fileType: fileType,
      fileName: fileName,
      saveLocation: resolvedLocation,
      conflictResolution: conflictResolution,
    );
  }

  /// [Future] wrapper for [saveAs] with an optional [onProgress] callback.
  ///
  /// **Platforms:** Android · iOS · macOS · Windows · Linux · Web
  ///
  /// Returns the saved [Uri], or null if the picker was cancelled.
  /// Throws on error.
  static Future<Uri?> saveAsAsync({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    UserSelectedLocation? saveLocation,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
  }) async {
    Uri? result;

    await for (final event in saveAs(
      input: input,
      fileType: fileType,
      fileName: fileName,
      saveLocation: saveLocation,
      conflictResolution: conflictResolution,
    )) {
      switch (event) {
        case SaveProgressStarted():
          break;
        case SaveProgressUpdate(:final progress):
          onProgress?.call(progress);
        case SaveProgressComplete(:final uri):
          result = uri;
        case SaveProgressError(:final exception):
          throw exception;
        case SaveProgressCancelled():
          return null;
      }
    }

    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Deprecated API — will be removed in 1.0.0
  // ─────────────────────────────────────────────────────────────────────────

  @Deprecated(
    'Use save(input: SaveInput.bytes(...)) instead. '
    'Will be removed in 1.0.0.',
  )
  static Stream<SaveProgress> saveBytes({
    required Uint8List fileBytes,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    return _platform.saveBytes(
      fileBytes: fileBytes,
      fileType: fileType,
      fileName: fileName,
      saveLocation: saveLocation,
      subDir: subDir,
      conflictResolution: conflictResolution,
    );
  }

  @Deprecated(
    'Use saveAsync(input: SaveInput.bytes(...)) instead. '
    'Will be removed in 1.0.0.',
  )
  static Future<Uri> saveBytesAsync({
    required Uint8List fileBytes,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
  }) {
    return saveAsync(
      input: SaveInput.bytes(fileBytes),
      fileType: fileType,
      fileName: fileName,
      saveLocation: saveLocation,
      subDir: subDir,
      conflictResolution: conflictResolution,
      onProgress: onProgress,
    );
  }

  @Deprecated(
    'Use save(input: SaveInput.file(...)) instead. '
    'Will be removed in 1.0.0.',
  )
  static Stream<SaveProgress> saveFile({
    required String filePath,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    return _platform.saveFile(
      filePath: filePath,
      fileName: fileName,
      fileType: fileType,
      saveLocation: saveLocation,
      subDir: subDir,
      conflictResolution: conflictResolution,
    );
  }

  @Deprecated(
    'Use saveAsync(input: SaveInput.file(...)) instead. '
    'Will be removed in 1.0.0.',
  )
  static Future<Uri> saveFileAsync({
    required String filePath,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
  }) {
    return saveAsync(
      input: SaveInput.file(filePath),
      fileType: fileType,
      fileName: fileName,
      saveLocation: saveLocation,
      subDir: subDir,
      conflictResolution: conflictResolution,
      onProgress: onProgress,
    );
  }

  @Deprecated(
    'Use save(input: SaveInput.network(...)) instead. '
    'Will be removed in 1.0.0.',
  )
  static Stream<SaveProgress> saveNetwork({
    required String url,
    required String fileName,
    required FileType fileType,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 60),
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    return _platform.saveNetwork(
      url: url,
      fileName: fileName,
      fileType: fileType,
      headers: headers,
      timeout: timeout,
      saveLocation: saveLocation,
      subDir: subDir,
      conflictResolution: conflictResolution,
    );
  }

  @Deprecated(
    'Use saveAsync(input: SaveInput.network(...)) instead. '
    'Will be removed in 1.0.0.',
  )
  static Future<Uri> saveNetworkAsync({
    required String url,
    required String fileName,
    required FileType fileType,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 60),
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
  }) {
    return saveAsync(
      input: SaveInput.network(url: url, headers: headers, timeout: timeout),
      fileType: fileType,
      fileName: fileName,
      saveLocation: saveLocation,
      subDir: subDir,
      conflictResolution: conflictResolution,
      onProgress: onProgress,
    );
  }
}
