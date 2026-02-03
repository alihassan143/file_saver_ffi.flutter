import 'package:flutter/foundation.dart';

import '../../file_saver_ffi.dart';
import '../platforms/android/file_saver_android.dart';
import '../platforms/ios/file_saver_ios.dart';

/// Platform interface for file saver implementations.
///
/// This abstract class defines the contract that platform-specific
/// implementations (iOS and Android) must implement.
///
/// Platform implementations:
/// - iOS: Uses FFI to call Objective-C code
/// - Android: Uses JNI to call Kotlin code
abstract class FileSaverPlatform {
  static FileSaverPlatform? _instance;

  /// Get the appropriate platform instance based on the current platform.
  static FileSaverPlatform get instance {
    _instance ??= switch (defaultTargetPlatform) {
      TargetPlatform.android => FileSaverAndroid(),
      TargetPlatform.iOS => FileSaverIos(),
      _ =>
        throw UnsupportedError(
          'FileSaver is not supported on ${defaultTargetPlatform.toString()}',
        ),
    };
    return _instance!;
  }

  /// Disposes resources
  void dispose();

  /// Saves file bytes to device storage with progress streaming.
  ///
  /// Parameters:
  /// - [fileBytes]: The file data to save
  /// - [fileType]: The type of file being saved
  /// - [fileName]: The name of the file (without extension)
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

  /// Saves a file from source path to device storage with progress streaming.
  ///
  /// This method reads the source file in chunks without loading it entirely
  /// into memory, making it suitable for large files.
  ///
  /// Parameters:
  /// - [filePath]: Source file path (file:// URI or content:// URI on Android)
  /// - [fileName]: Target file name without extension
  /// - [fileType]: The type of file being saved (determines extension and MIME type)
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

  /// Saves a file from a network URL to device storage with progress streaming.
  ///
  /// The file is downloaded at the native level to avoid double storage:
  /// - Android: Streams directly from network to MediaStore OutputStream
  /// - iOS Documents: Downloads directly to the target path
  /// - iOS Photos: Downloads to tmp, saves to Photos Library, then deletes tmp
  ///
  /// Parameters:
  /// - [url]: The URL to download the file from
  /// - [fileName]: Target file name without extension
  /// - [fileType]: The type of file being saved (determines extension and MIME type)
  /// - [headers]: Optional HTTP headers for the request
  /// - [timeout]: Timeout for the network request (defaults to 60 seconds)
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
  // Protected helpers for subclasses
  // ─────────────────────────────────────────────────────────────────────────

  /// Validates input for [saveBytes] and [saveBytesAsync].
  @protected
  void validateBytesInput(Uint8List bytes, String fileName) {
    if (bytes.isEmpty) {
      throw const InvalidFileException('File bytes cannot be empty');
    }
    if (fileName.isEmpty) {
      throw const InvalidFileException('File name cannot be empty');
    }
  }

  /// Validates input for [saveFile] and [saveFileAsync].
  @protected
  void validateFilePathInput(String filePath, String fileName) {
    if (filePath.isEmpty) {
      throw const InvalidFileException('File path cannot be empty');
    }
    if (fileName.isEmpty) {
      throw const InvalidFileException('File name cannot be empty');
    }
  }

  /// Validates input for [saveNetwork] and [saveNetworkAsync].
  @protected
  void validateNetworkInput(String url, String fileName) {
    if (url.isEmpty) {
      throw const InvalidFileException('URL cannot be empty');
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw const InvalidFileException(
        'URL must use http or https scheme',
      );
    }
    if (fileName.isEmpty) {
      throw const InvalidFileException('File name cannot be empty');
    }
  }

  /// Checks if [SaveProgress] event is terminal.
  @protected
  bool isTerminal(SaveProgress e) =>
      e is SaveProgressComplete ||
      e is SaveProgressError ||
      e is SaveProgressCancelled;
}
