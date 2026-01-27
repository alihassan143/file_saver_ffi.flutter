import 'dart:async';
import 'dart:typed_data';

import 'package:jni/jni.dart';

import '../../exceptions/file_saver_exceptions.dart';
import '../../models/conflict_resolution.dart';
import '../../models/file_type.dart';
import '../../models/save_location.dart';
import '../../models/save_progress.dart';
import '../../platform_interface/file_saver_platform.dart';
import 'bindings.g.dart' as bindings;

class FileSaverAndroid extends FileSaverPlatform {
  FileSaverAndroid() {
    _fileSaver = bindings.FileSaver(Jni.androidApplicationContext);
  }

  /// Native FileSaver instance
  late final bindings.FileSaver _fileSaver;

  @override
  void dispose() {
    _fileSaver.release();
  }

  @override
  Stream<SaveProgress> saveBytes({
    required Uint8List fileBytes,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    _validateInput(fileBytes, fileName);

    return Stream.multi((controller) {
      bool cleanedUp = false;
      late final bindings.ProgressCallback callback;

      final jByteArray = JByteArray.from(fileBytes);
      final jFileName = fileName.toJString();
      final jExtension = fileType.ext.toJString();
      final jMimeType = fileType.mimeType.toJString();
      final jConflictMode = conflictResolution.index;
      final jSaveLocationIndex = switch (saveLocation) {
        AndroidSaveLocation location => location.index,
        _ => AndroidSaveLocation.downloads.index,
      };
      final jSubDir = subDir?.toJString();

      void cleanup() {
        if (cleanedUp) return;
        cleanedUp = true;

        // Defer release out of [callback] stack
        Future.microtask(() {
          if (!controller.isClosed) controller.closeSync();
          callback.release();
        });
      }

      // Create callback - cleanup happens on terminal events
      callback = bindings.ProgressCallback.implement(
        bindings.$ProgressCallback(
          onEvent: (eventType, progress, data, message) {
            if (cleanedUp || controller.isClosed) return;

            final event = _parseEvent(eventType, progress, data, message);
            controller.addSync(event);

            if (event is SaveProgressComplete ||
                event is SaveProgressError ||
                event is SaveProgressCancelled) {
              cleanup();
            }
          },
          onEvent$async: true,
        ),
      );

      // Call native method - returns operationId for cancellation
      final operationId = _fileSaver.saveBytes(
        jByteArray,
        jFileName,
        jExtension,
        jMimeType,
        jSaveLocationIndex,
        jSubDir,
        jConflictMode,
        callback,
      );

      controller.onCancel = () {
        _fileSaver.cancelOperation(operationId);
        // Fallback cleanup if native doesn't respond with Cancelled event
        Future.delayed(const Duration(milliseconds: 500), cleanup);
      };
    });
  }

  @override
  Future<Uri> saveBytesAsync({
    required Uint8List fileBytes,
    required String fileName,
    required FileType fileType,
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
          throw const PlatformException('Operation cancelled', 'CANCELLED');
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

  @override
  Stream<SaveProgress> saveFile({
    required String filePath,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    _validateFilePath(filePath, fileName);

    return Stream.multi((controller) {
      bool cleanedUp = false;
      late final bindings.ProgressCallback callback;

      final jFilePath = filePath.toJString();
      final jFileName = fileName.toJString();
      final jExtension = fileType.ext.toJString();
      final jMimeType = fileType.mimeType.toJString();
      final jConflictMode = conflictResolution.index;
      final jSaveLocationIndex = switch (saveLocation) {
        AndroidSaveLocation location => location.index,
        _ => AndroidSaveLocation.downloads.index,
      };
      final jSubDir = subDir?.toJString();

      void cleanup() {
        if (cleanedUp) return;
        cleanedUp = true;

        // Defer release out of [callback] stack
        Future.microtask(() {
          if (!controller.isClosed) controller.closeSync();
          callback.release();
        });
      }

      // Create callback - cleanup happens on terminal events
      callback = bindings.ProgressCallback.implement(
        bindings.$ProgressCallback(
          onEvent: (eventType, progress, data, message) {
            if (cleanedUp || controller.isClosed) return;

            final event = _parseEvent(eventType, progress, data, message);
            controller.addSync(event);

            if (event is SaveProgressComplete ||
                event is SaveProgressError ||
                event is SaveProgressCancelled) {
              cleanup();
            }
          },
          onEvent$async: true,
        ),
      );

      // Call native method - returns operationId for cancellation
      final operationId = _fileSaver.saveFile(
        jFilePath,
        jFileName,
        jExtension,
        jMimeType,
        jSaveLocationIndex,
        jSubDir,
        jConflictMode,
        callback,
      );

      controller.onCancel = () {
        _fileSaver.cancelOperation(operationId);
        // Fallback cleanup if native doesn't respond with Cancelled event
        Future.delayed(const Duration(milliseconds: 500), cleanup);
      };
    });
  }

  @override
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
          throw const PlatformException('Operation cancelled', 'CANCELLED');
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

  /// Parses event from native callback
  /// - eventType 0: Started
  /// - eventType 1: Progress (progress = 0.0-1.0)
  /// - eventType 2: Error (data = errorCode, message = errorMessage)
  /// - eventType 3: Success (data = fileUri)
  /// - eventType 4: Cancelled
  SaveProgress _parseEvent(
    int eventType,
    double progress,
    JString? data,
    JString? message,
  ) {
    switch (eventType) {
      case 0: // Started
        return const SaveProgressStarted();

      case 1: // Progress
        return SaveProgressUpdate(progress);

      case 2: // Error
        final errorCode =
            data?.toDartString(releaseOriginal: true) ?? 'UNKNOWN';
        final errorMsg =
            message?.toDartString(releaseOriginal: true) ?? 'Unknown error';
        return SaveProgressError(
          FileSaverException.fromErrorResult(errorCode, errorMsg),
        );

      case 3: // Success
        final fileUri = data?.toDartString(releaseOriginal: true) ?? '';
        return SaveProgressComplete(Uri.parse(fileUri));

      case 4: // Cancelled
        return const SaveProgressCancelled();

      default:
        return SaveProgressError(
          PlatformException('Unknown event type: $eventType', 'UNKNOWN_TYPE'),
        );
    }
  }

  void _validateInput(Uint8List bytes, String fileName) {
    if (bytes.isEmpty) {
      throw const InvalidFileException('File bytes cannot be empty');
    }
    if (fileName.isEmpty) {
      throw const InvalidFileException('File name cannot be empty');
    }
  }

  void _validateFilePath(String filePath, String fileName) {
    if (filePath.isEmpty) {
      throw const InvalidFileException('File path cannot be empty');
    }
    if (fileName.isEmpty) {
      throw const InvalidFileException('File name cannot be empty');
    }
  }
}
