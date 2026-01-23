library;

import 'dart:typed_data';

// Public API - FileSaver class
import 'src/models/conflict_resolution.dart';
import 'src/models/file_type.dart';
import 'src/models/save_location.dart';
import 'src/models/save_progress.dart';
import 'src/platform_interface/file_saver_platform.dart';

// Exceptions
export 'src/exceptions/file_saver_exceptions.dart';
// Models
export 'src/models/conflict_resolution.dart';
export 'src/models/file_type.dart';
export 'src/models/save_location.dart';
export 'src/models/save_progress.dart';

class FileSaver {
  FileSaver._();

  static final FileSaver instance = FileSaver._();

  FileSaverPlatform get _platform => FileSaverPlatform.instance;

  /// Resources are automatically released on app termination,
  /// but call dispose() for timely cleanup.
  void dispose() {
    _platform.dispose();
  }

  /// Saves file bytes to device storage with progress streaming.
  ///
  /// Yields progress events during save operation:
  /// - [SaveProgressStarted]: Operation began
  /// - [SaveProgressUpdate]: Progress from 0.0 to 1.0
  /// - [SaveProgressComplete]: Success with URI
  /// - [SaveProgressError]: Failed with exception
  /// - [SaveProgressCancelled]: User cancelled
  ///
  /// Parameters:
  /// - [bytes]: The file content to save
  /// - [fileName]: The name of the file without extension
  /// - [fileType]: The file type (determines extension and MIME type)
  /// - [saveLocation]: Where to save the file (platform-specific, optional)
  ///   - If not specified, defaults to:
  ///     - Android: [AndroidSaveLocation.downloads]
  ///     - iOS: [IosSaveLocation.documents] (app's Documents directory)
  /// - [subDir]: Optional subdirectory within the save location
  /// - [conflictResolution]: How to handle filename conflicts
  ///
  /// Example:
  /// ```dart
  /// await for (final event in FileSaver.instance.saveBytes(
  ///   bytes: imageBytes,
  ///   fileName: 'photo',
  ///   fileType: ImageType.jpg,
  /// )) {
  ///   switch (event) {
  ///     case SaveProgressStarted():
  ///       showLoadingIndicator();
  ///     case SaveProgressUpdate(:final progress):
  ///       updateProgressBar(progress);
  ///     case SaveProgressComplete(:final uri):
  ///       handleSuccess(uri);
  ///     case SaveProgressError(:final exception):
  ///       handleError(exception);
  ///     case SaveProgressCancelled():
  ///       handleCancel();
  ///   }
  /// }
  /// ```
  Stream<SaveProgress> saveBytes({
    required Uint8List bytes,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    return _platform.saveBytes(
      fileBytes: bytes,
      fileType: fileType,
      fileName: fileName,
      saveLocation: saveLocation,
      subDir: subDir,
      conflictResolution: conflictResolution,
    );
  }

  /// Saves file bytes to device storage with optional progress callback.
  ///
  /// Parameters:
  /// - [bytes]: The file content to save
  /// - [fileName]: The name of the file without extension
  /// - [fileType]: The file type (determines extension and MIME type)
  /// - [saveLocation]: Where to save the file (platform-specific, optional)
  /// - [subDir]: Optional subdirectory within the save location
  /// - [conflictResolution]: How to handle filename conflicts
  /// - [onProgress]: Optional callback receiving progress from 0.0 to 1.0
  ///
  /// Returns the [Uri] where the file was saved.
  ///
  /// Throws [FileSaverException] or one of its subtypes on failure.
  ///
  /// Example:
  /// ```dart
  /// final uri = await FileSaver.instance.saveBytesAsync(
  ///   bytes: imageBytes,
  ///   fileName: 'photo',
  ///   fileType: ImageType.jpg,
  ///   onProgress: (progress) => print('${(progress * 100).toInt()}%'),
  /// );
  /// ```
  Future<Uri> saveBytesAsync({
    required Uint8List bytes,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
  }) {
    return _platform.saveBytesAsync(
      fileBytes: bytes,
      fileType: fileType,
      fileName: fileName,
      saveLocation: saveLocation,
      subDir: subDir,
      conflictResolution: conflictResolution,
      onProgress: onProgress,
    );
  }
}
