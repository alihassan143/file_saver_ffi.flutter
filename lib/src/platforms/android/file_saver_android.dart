import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:jni/jni.dart';

import '../../exceptions/file_saver_exceptions.dart';
import '../../models/conflict_resolution.dart';
import '../../models/file_type.dart';
import '../../models/save_input.dart';
import '../../models/locations/save_location.dart';
import '../../models/save_progress.dart';
import '../../platform_interface/file_saver_platform.dart';
import 'bindings.g.dart' as bindings;

class FileSaverAndroid extends FileSaverPlatform {
  FileSaverAndroid() {
    _fileSaver = bindings.FileSaver(Jni.androidApplicationContext);
  }

  /// Native FileSaver instance
  late final bindings.FileSaver _fileSaver;

  /// Registers this class as the default instance of [FileSaverPlatform].
  static void registerWith() {
    FileSaverPlatform.instance = FileSaverAndroid();
  }

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
    validateBytesInput(fileBytes, fileName);

    return Stream.multi((controller) {
      bool cleanedUp = false;
      late final bindings.ProgressCallback callback;

      final jByteArray = JByteArray.from(fileBytes);
      final jFileName = fileName.toJString();
      final jExtension = fileType.ext.toJString();
      final jMimeType = fileType.mimeType.toJString();
      final jConflictMode = conflictResolution.index;
      final jSaveLocationIndex = _saveLocationToIndex(saveLocation);
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

            if (isTerminal(event)) cleanup();
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
  Stream<SaveProgress> saveFile({
    required String filePath,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    validateFilePathInput(filePath, fileName);

    return Stream.multi((controller) {
      bool cleanedUp = false;
      late final bindings.ProgressCallback callback;

      final jFilePath = filePath.toJString();
      final jFileName = fileName.toJString();
      final jExtension = fileType.ext.toJString();
      final jMimeType = fileType.mimeType.toJString();
      final jConflictMode = conflictResolution.index;
      final jSaveLocationIndex = _saveLocationToIndex(saveLocation);
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

            if (isTerminal(event)) cleanup();
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

    return Stream.multi((controller) {
      bool cleanedUp = false;
      late final bindings.ProgressCallback callback;

      final jUrl = url.toJString();
      final jHeadersJson =
          headers != null ? jsonEncode(headers).toJString() : null;
      final jTimeoutMs = timeout.inMilliseconds;
      final jFileName = fileName.toJString();
      final jExtension = fileType.ext.toJString();
      final jMimeType = fileType.mimeType.toJString();
      final jConflictMode = conflictResolution.index;
      final jSaveLocationIndex = _saveLocationToIndex(saveLocation);
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

            if (isTerminal(event)) cleanup();
          },
          onEvent$async: true,
        ),
      );

      // Call native method - returns operationId for cancellation
      final operationId = _fileSaver.saveNetwork(
        jUrl,
        jHeadersJson,
        jTimeoutMs,
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
  Stream<SaveProgress> saveAs({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    required UserSelectedLocation saveLocation,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    return switch (input) {
      SaveBytesInput(:final fileBytes) => _saveBytesAs(
        fileBytes: fileBytes,
        directoryUri: saveLocation.uri.toString(),
        baseFileName: fileName,
        extension: fileType.ext,
        mimeType: fileType.mimeType,
        conflictResolution: conflictResolution,
      ),
      SaveFileInput(:final filePath) => _saveFileAs(
        filePath: filePath,
        directoryUri: saveLocation.uri.toString(),
        baseFileName: fileName,
        extension: fileType.ext,
        mimeType: fileType.mimeType,
        conflictResolution: conflictResolution,
      ),
      SaveNetworkInput(:final url, :final headers, :final timeout) =>
        _saveNetworkAs(
          url: url,
          headers: headers,
          timeout: timeout,
          directoryUri: saveLocation.uri.toString(),
          baseFileName: fileName,
          extension: fileType.ext,
          mimeType: fileType.mimeType,
          conflictResolution: conflictResolution,
        ),
    };
  }

  Stream<SaveProgress> _saveBytesAs({
    required Uint8List fileBytes,
    required String directoryUri,
    required String baseFileName,
    required String extension,
    required String mimeType,
    required ConflictResolution conflictResolution,
  }) {
    return Stream.multi((controller) {
      bool cleanedUp = false;
      late final bindings.ProgressCallback callback;

      final jByteArray = JByteArray.from(fileBytes);
      final jDirectoryUri = directoryUri.toJString();
      final jBaseFileName = baseFileName.toJString();
      final jExtension = extension.toJString();
      final jMimeType = mimeType.toJString();
      final jConflictMode = conflictResolution.index;

      void cleanup() {
        if (cleanedUp) return;
        cleanedUp = true;
        Future.microtask(() {
          if (!controller.isClosed) controller.closeSync();
          callback.release();
        });
      }

      callback = bindings.ProgressCallback.implement(
        bindings.$ProgressCallback(
          onEvent: (eventType, progress, data, message) {
            if (cleanedUp || controller.isClosed) return;
            final event = _parseEvent(eventType, progress, data, message);
            controller.addSync(event);
            if (isTerminal(event)) cleanup();
          },
          onEvent$async: true,
        ),
      );

      final operationId = _fileSaver.saveBytesAs(
        jByteArray,
        jDirectoryUri,
        jBaseFileName,
        jExtension,
        jMimeType,
        jConflictMode,
        callback,
      );

      controller.onCancel = () {
        _fileSaver.cancelOperation(operationId);
        Future.delayed(const Duration(milliseconds: 500), cleanup);
      };
    });
  }

  Stream<SaveProgress> _saveFileAs({
    required String filePath,
    required String directoryUri,
    required String baseFileName,
    required String extension,
    required String mimeType,
    required ConflictResolution conflictResolution,
  }) {
    return Stream.multi((controller) {
      bool cleanedUp = false;
      late final bindings.ProgressCallback callback;

      final jFilePath = filePath.toJString();
      final jDirectoryUri = directoryUri.toJString();
      final jBaseFileName = baseFileName.toJString();
      final jExtension = extension.toJString();
      final jMimeType = mimeType.toJString();
      final jConflictMode = conflictResolution.index;

      void cleanup() {
        if (cleanedUp) return;
        cleanedUp = true;
        Future.microtask(() {
          if (!controller.isClosed) controller.closeSync();
          callback.release();
        });
      }

      callback = bindings.ProgressCallback.implement(
        bindings.$ProgressCallback(
          onEvent: (eventType, progress, data, message) {
            if (cleanedUp || controller.isClosed) return;
            final event = _parseEvent(eventType, progress, data, message);
            controller.addSync(event);
            if (isTerminal(event)) cleanup();
          },
          onEvent$async: true,
        ),
      );

      final operationId = _fileSaver.saveFileAs(
        jFilePath,
        jDirectoryUri,
        jBaseFileName,
        jExtension,
        jMimeType,
        jConflictMode,
        callback,
      );

      controller.onCancel = () {
        _fileSaver.cancelOperation(operationId);
        Future.delayed(const Duration(milliseconds: 500), cleanup);
      };
    });
  }

  Stream<SaveProgress> _saveNetworkAs({
    required String url,
    required Map<String, String>? headers,
    required Duration timeout,
    required String directoryUri,
    required String baseFileName,
    required String extension,
    required String mimeType,
    required ConflictResolution conflictResolution,
  }) {
    return Stream.multi((controller) {
      bool cleanedUp = false;
      late final bindings.ProgressCallback callback;

      final jUrl = url.toJString();
      final jHeadersJson =
          headers != null ? jsonEncode(headers).toJString() : null;
      final jTimeoutMs = timeout.inMilliseconds;
      final jDirectoryUri = directoryUri.toJString();
      final jBaseFileName = baseFileName.toJString();
      final jExtension = extension.toJString();
      final jMimeType = mimeType.toJString();
      final jConflictMode = conflictResolution.index;

      void cleanup() {
        if (cleanedUp) return;
        cleanedUp = true;
        Future.microtask(() {
          if (!controller.isClosed) controller.closeSync();
          callback.release();
        });
      }

      callback = bindings.ProgressCallback.implement(
        bindings.$ProgressCallback(
          onEvent: (eventType, progress, data, message) {
            if (cleanedUp || controller.isClosed) return;
            final event = _parseEvent(eventType, progress, data, message);
            controller.addSync(event);
            if (isTerminal(event)) cleanup();
          },
          onEvent$async: true,
        ),
      );

      final operationId = _fileSaver.saveNetworkAs(
        jUrl,
        jHeadersJson,
        jTimeoutMs,
        jDirectoryUri,
        jBaseFileName,
        jExtension,
        jMimeType,
        jConflictMode,
        callback,
      );

      controller.onCancel = () {
        _fileSaver.cancelOperation(operationId);
        Future.delayed(const Duration(milliseconds: 500), cleanup);
      };
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private Methods
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the native index for a [SaveLocation].
  ///
  /// Maps [AndroidSaveLocation] to its index value.
  /// Defaults to [AndroidSaveLocation.downloads] index.
  int _saveLocationToIndex(SaveLocation? saveLocation) {
    return switch (saveLocation) {
      AndroidSaveLocation location => location.index,
      _ => AndroidSaveLocation.downloads.index,
    };
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
}
