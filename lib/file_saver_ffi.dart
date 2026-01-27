library;

import 'dart:typed_data';

import '/src/exceptions/file_saver_exceptions.dart';
import 'src/models/conflict_resolution.dart';
import 'src/models/file_type.dart';
import 'src/models/save_location.dart';
import 'src/models/save_progress.dart';
import 'src/platform_interface/file_saver_platform.dart';

// Public API - FileSaver class
export 'src/exceptions/file_saver_exceptions.dart';
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
  /// - [fileBytes]: The file content to save
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

  /// Convenience wrapper around [saveBytes] that returns a [Future].
  ///
  /// This method listens to the progress stream from [saveBytes] and converts it
  /// into an optional [onProgress] callback.
  ///
  /// Parameters:
  /// - See [saveBytes] for all parameters except [onProgress].
  /// - [onProgress]: Optional callback receiving progress from 0.0 to 1.0
  ///
  /// Returns the [Uri] where the file was saved.
  ///
  /// Throws:
  /// - [FileSaverException] or subclass if the save operation fails
  ///
  /// See also:
  /// - [saveBytes] for stream-based progress handling.
  ///
  /// Example:
  /// ```dart
  /// final uri = await FileSaver.instance.saveBytesAsync(
  ///   fileBytes: imageBytes,
  ///   fileName: 'photo',
  ///   fileType: ImageType.jpg,
  ///   onProgress: (progress) => print('${(progress * 100).toInt()}%'),
  /// );
  /// ```
  Future<Uri> saveBytesAsync({
    required Uint8List fileBytes,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
  }) async {
    Uri? result;

    await for (final event in saveBytes(
      fileBytes: fileBytes,
      fileName: fileName,
      fileType: fileType,
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

  /// Saves a file from source path to device storage with progress streaming.
  ///
  /// This method reads the source file in chunks without loading it entirely
  /// into memory, making it suitable for large files (100MB+).
  ///
  /// Yields progress events during save operation:
  /// - [SaveProgressStarted]: Operation began
  /// - [SaveProgressUpdate]: Progress from 0.0 to 1.0
  /// - [SaveProgressComplete]: Success with URI
  /// - [SaveProgressError]: Failed with exception
  /// - [SaveProgressCancelled]: User cancelled
  ///
  /// Parameters:
  /// - [filePath]: Source file path (file:// URI or content:// URI on Android)
  /// - [fileName]: Target file name without extension
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
  /// await for (final event in FileSaver.instance.saveFile(
  ///   filePath: '/path/to/large_video.mp4',
  ///   fileName: 'my_video',
  ///   fileType: VideoType.mp4,
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
  Stream<SaveProgress> saveFile({
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

  /// Convenience wrapper around [saveFile] that returns a [Future].
  ///
  /// This method listens to the progress stream from [saveFile] and converts it
  /// into an optional [onProgress] callback.
  ///
  /// Parameters:
  /// - See [saveFile] for all parameters except [onProgress].
  /// - [onProgress]: Optional callback receiving progress from 0.0 to 1.0
  ///
  /// Returns the [Uri] where the file was saved.
  ///
  /// Throws:
  /// - [FileSaverException] or subclass if the save operation fails
  ///
  /// See also:
  /// - [saveFile] for stream-based progress handling.
  ///
  /// Example:
  /// ```dart
  /// final uri = await FileSaver.instance.saveFileAsync(
  ///   filePath: pickedFile.path,
  ///   fileName: 'document',
  ///   fileType: CustomFileType(ext: 'pdf', mimeType: 'application/pdf'),
  ///   onProgress: (progress) => print('${(progress * 100).toInt()}%'),
  /// );
  /// ```
  Future<Uri> saveFileAsync({
    required String filePath,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
  }) async {
    Uri? result;

    await for (final event in saveFile(
      filePath: filePath,
      fileName: fileName,
      fileType: fileType,
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
}
