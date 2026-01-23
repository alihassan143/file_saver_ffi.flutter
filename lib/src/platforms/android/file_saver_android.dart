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
  }) async* {
    _validateInput(fileBytes, fileName);

    final controller = StreamController<SaveProgress>();

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

    // Create callback implementation
    final callback = bindings.ProgressCallback.implement(
      bindings.$ProgressCallback(
        onEvent: (eventType, progress, data, message) {
          final event = _parseEvent(eventType, progress, data, message);
          controller.add(event);

          // Close stream on terminal events
          if (event is SaveProgressComplete ||
              event is SaveProgressError ||
              event is SaveProgressCancelled) {
            controller.close();
          }
        },
        onEvent$async: true,
      ),
    );

    try {
      // Call native method with callback
      _fileSaver.saveBytes(
        jByteArray,
        jFileName,
        jExtension,
        jMimeType,
        jSaveLocationIndex,
        jSubDir,
        jConflictMode,
        callback,
      );

      // Yield events from stream
      await for (final event in controller.stream) {
        yield event;
      }
    } finally {
      callback.release();
    }
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
        final errorCode = data?.toDartString(releaseOriginal: true) ?? 'UNKNOWN';
        final errorMsg = message?.toDartString(releaseOriginal: true) ?? 'Unknown error';
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
}
