import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/foundation.dart';

import '../exceptions/file_saver_exceptions.dart';
import '../models/conflict_resolution.dart';
import '../models/file_type.dart';
import '../models/save_input.dart';
import '../models/locations/save_location.dart';
import '../models/save_progress.dart';

/// Platform interface for file saver implementations.
///
/// This abstract class defines the contract that platform-specific
/// implementations must implement.
///
/// Platform implementations:
/// - iOS/macOS: Uses FFI to call Swift code (shared darwin source)
/// - Android: Uses JNI to call Kotlin code
/// - Windows: Dart FFI via path_provider_windows (SHGetKnownFolderPath) + dart:io
/// - Linux: Dart FFI via xdg-user-dir + dart:io
/// - Web: Uses browser APIs via dart:web + dart:js_interop
abstract class FileSaverPlatform {
  static FileSaverPlatform? _instance;

  /// The current platform implementation.
  ///
  /// Set automatically before [runApp] via each platform's [registerWith] method,
  /// which is invoked by Flutter's generated plugin registrant.
  static FileSaverPlatform get instance {
    assert(_instance != null, 'FileSaverPlatform.instance is not set.');
    return _instance!;
  }

  /// Used by each platform's [registerWith] to register itself.
  static set instance(FileSaverPlatform value) {
    _instance = value;
  }

  /// Saves file bytes to device storage with progress streaming.
  ///
  /// **Platforms:** Android · iOS · macOS · Windows · Linux · Web
  ///
  /// - [saveLocation]: Where to save the file (platform-specific, optional)
  /// - [subDir]: Optional subdirectory within the standard save location
  /// - [conflictResolution]: How to handle filename conflicts
  ///
  /// Yields [SaveProgress] events during save operation.
  Stream<SaveProgress> saveBytes({
    required Uint8List fileBytes,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  });

  /// Saves a file from [filePath] to device storage with progress streaming.
  ///
  /// **Platforms:** Android · iOS · macOS · Windows · Linux
  /// (Web: not supported — browsers cannot access arbitrary file paths)
  ///
  /// Streams in chunks — suitable for large files.
  ///
  /// - [filePath]: Source path (file:// URI or content:// URI on Android)
  /// - [saveLocation]: Where to save the file (platform-specific, optional)
  /// - [subDir]: Optional subdirectory within the standard save location
  /// - [conflictResolution]: How to handle filename conflicts
  ///
  /// Yields [SaveProgress] events during save operation.
  ///
  /// Throws [SourceFileNotFoundException] if the source file does not exist.
  /// Throws [ICloudDownloadException] on iOS if iCloud file download fails.
  Stream<SaveProgress> saveFile({
    required String filePath,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  });

  /// Downloads from [url] and saves to device storage with progress streaming.
  ///
  /// **Platforms:** Android · iOS · macOS · Windows · Linux · Web
  ///
  /// Downloaded natively to avoid double storage:
  /// - Android: streams directly to MediaStore (zero temp files)
  /// - iOS Documents: downloads directly to target path
  /// - iOS Photos: temp → Photos Library → delete temp
  ///
  /// - [headers]: Optional HTTP headers for the request
  /// - [timeout]: Network timeout (default 60s)
  /// - [saveLocation]: Where to save the file (platform-specific, optional)
  /// - [subDir]: Optional subdirectory within the standard save location
  /// - [conflictResolution]: How to handle filename conflicts
  ///
  /// Yields [SaveProgress] events during save operation.
  ///
  /// Throws [NetworkException] if the download fails.
  Stream<SaveProgress> saveNetwork({
    required String url,
    required String fileName,
    required FileType fileType,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 60),
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  });

  // ─────────────────────────────────────────────────────────────────────────
  // User-Selected Location
  // ─────────────────────────────────────────────────────────────────────────

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
  Future<UserSelectedLocation?> pickDirectory({
    bool shouldPersist = true,
  }) async {
    try {
      final location = await DirPicker.pick(
        androidOptions: AndroidOptions(shouldPersist: shouldPersist),
      );
      if (location == null) return null;
      return UserSelectedLocation(uri: location.uri!);
    } on FileSaverException {
      rethrow;
    } catch (e) {
      throw PlatformException('Pick directory failed: $e');
    }
  }

  /// Saves to a user-selected directory with progress streaming.
  ///
  /// **Platforms:** Android · iOS · macOS · Windows · Linux · Web
  ///
  /// - [saveLocation]: User-selected directory from [pickDirectory]
  /// - [conflictResolution]: How to handle filename conflicts
  ///
  /// Yields [SaveProgress] events during save operation.
  Stream<SaveProgress> saveAs({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    required UserSelectedLocation saveLocation,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Protected helpers for subclasses
  // ─────────────────────────────────────────────────────────────────────────

  /// Validates input for [saveBytes] and [saveBytesAsync].
  @protected
  void validateBytesInput(Uint8List bytes, String fileName) {
    if (bytes.isEmpty) {
      throw const InvalidInputException('File bytes cannot be empty');
    }
    if (fileName.isEmpty) {
      throw const InvalidInputException('File name cannot be empty');
    }
  }

  /// Validates input for [saveFile] and [saveFileAsync].
  @protected
  void validateFilePathInput(String filePath, String fileName) {
    if (filePath.isEmpty) {
      throw const InvalidInputException('File path cannot be empty');
    }
    if (fileName.isEmpty) {
      throw const InvalidInputException('File name cannot be empty');
    }
  }

  /// Validates input for [saveNetwork] and [saveNetworkAsync].
  @protected
  void validateNetworkInput(String url, String fileName) {
    if (url.isEmpty) {
      throw const InvalidInputException('URL cannot be empty');
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw const InvalidInputException('URL must use http or https scheme');
    }
    if (fileName.isEmpty) {
      throw const InvalidInputException('File name cannot be empty');
    }
  }

  /// Checks if [SaveProgress] event is terminal.
  @protected
  bool isTerminal(SaveProgress e) =>
      e is SaveProgressComplete ||
      e is SaveProgressError ||
      e is SaveProgressCancelled;
}
