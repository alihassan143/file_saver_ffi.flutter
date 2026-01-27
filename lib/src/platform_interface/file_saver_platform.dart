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

  /// Saves file bytes to device storage with optional progress callback.
  ///
  /// Convenience method that returns [Future<Uri>].
  ///
  /// Parameters:
  /// - [fileBytes]: The file data to save
  /// - [fileType]: The type of file being saved
  /// - [fileName]: The name of the file (without extension)
  /// - [saveLocation]: Where to save the file (platform-specific, optional)
  /// - [subDir]: Optional subdirectory within the standard save location
  /// - [conflictResolution]: How to handle filename conflicts
  /// - [onProgress]: Optional callback receiving progress from 0.0 to 1.0
  ///
  /// Returns the [Uri] where the file was saved.
  Future<Uri> saveBytesAsync({
    required Uint8List fileBytes,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
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

  /// Saves a file from source path with optional progress callback.
  ///
  /// Convenience method that returns [Future<Uri>].
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
  /// - [onProgress]: Optional callback receiving progress from 0.0 to 1.0
  ///
  /// Returns the [Uri] where the file was saved.
  ///
  /// Throws [SourceFileNotFoundException] if the source file does not exist.
  /// Throws [ICloudDownloadException] on iOS if iCloud file download fails.
  Future<Uri> saveFileAsync({
    required String filePath,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
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

  /// Checks if [SaveProgress] event is terminal.
  @protected
  bool isTerminal(SaveProgress e) =>
      e is SaveProgressComplete ||
      e is SaveProgressError ||
      e is SaveProgressCancelled;
}
