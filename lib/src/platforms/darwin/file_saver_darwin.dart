import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../exceptions/file_saver_exceptions.dart';
import '../../models/conflict_resolution.dart';
import '../../models/file_type.dart';
import '../../models/save_input.dart';
import '../../models/save_location.dart';
import '../../models/save_progress.dart';
import '../../platform_interface/file_saver_platform.dart';
import 'bindings.g.dart';

/// FileSaver implementation for Apple platforms (iOS and macOS).
///
/// Uses shared darwin code with platform-specific behaviors:
/// - iOS: Supports Photos Library and Documents
/// - macOS: Supports Documents, Downloads, and Desktop
class FileSaverDarwin extends FileSaverPlatform implements Finalizable {
  FileSaverDarwin() {
    final dylib = DynamicLibrary.process();
    _bindings = FileSaverFfiBindings(dylib);

    // Initialize Dart API DL for NativePort communication
    final initResult = _bindings.file_saver_init_dart_api_dl(
      NativeApi.initializeApiDLData,
    );
    if (initResult != 0) {
      throw const PlatformException(
        'Failed to initialize Dart API DL',
        'INIT_FAILED',
      );
    }

    _saverInstance = _bindings.file_saver_init();

    if (_saverInstance.address != 0) {
      _finalizer.attach(this, _saverInstance.cast());
    }
  }

  late final FileSaverFfiBindings _bindings;
  late final Pointer<Void> _saverInstance;

  static final int _disposeAddress =
      DynamicLibrary.process()
          .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
            'file_saver_dispose',
          )
          .address;

  static final Pointer<NativeFinalizerFunction> _nativeFinalizerPtr =
      Pointer.fromAddress(_disposeAddress);

  static final _finalizer = NativeFinalizer(_nativeFinalizerPtr);

  @override
  void dispose() {
    if (_saverInstance.address != 0) {
      _bindings.file_saver_dispose(_saverInstance);
      _finalizer.detach(this);
    }
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
      final receivePort = ReceivePort();
      final arena = Arena();
      final nativePort = receivePort.sendPort.nativePort;
      bool cleanedUp = false;

      void cleanup() {
        if (cleanedUp) return;
        cleanedUp = true;
        receivePort.close();
        arena.releaseAll();
        controller.closeSync();
      }

      // Allocate in arena - all freed together with arena.releaseAll()
      final dataPointer = arena<Uint8>(fileBytes.length);
      dataPointer.asTypedList(fileBytes.length).setAll(0, fileBytes);

      final fileNameCStr = fileName.toNativeUtf8(allocator: arena);
      final extCStr = fileType.ext.toNativeUtf8(allocator: arena);
      final mimeCStr = fileType.mimeType.toNativeUtf8(allocator: arena);
      final saveLocationIndex = switch (saveLocation) {
        IosSaveLocation location => location.index,
        MacosSaveLocation location => location.index,
        _ => 0, // Default to documents
      };
      final subDirCStr = subDir?.toNativeUtf8(allocator: arena);

      // Listen to native port - cleanup happens here on terminal events
      receivePort.listen((message) {
        if (cleanedUp || controller.isClosed) return;

        final event = _parseMessage(message);
        controller.addSync(event);

        if (isTerminal(event)) cleanup();
      });

      // Call native function - returns tokenId for cancellation
      final tokenId = _bindings.file_saver_save_bytes(
        _saverInstance,
        dataPointer,
        fileBytes.length,
        fileNameCStr.cast(),
        extCStr.cast(),
        mimeCStr.cast(),
        saveLocationIndex,
        subDirCStr?.cast() ?? nullptr,
        conflictResolution.index,
        nativePort,
      );

      controller.onCancel = () {
        _bindings.file_saver_cancel(tokenId);
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
      final receivePort = ReceivePort();
      final arena = Arena();
      final nativePort = receivePort.sendPort.nativePort;
      bool cleanedUp = false;

      void cleanup() {
        if (cleanedUp) return;
        cleanedUp = true;
        receivePort.close();
        arena.releaseAll();
        controller.closeSync();
      }

      // Allocate in arena - all freed together with arena.releaseAll()
      final filePathCStr = filePath.toNativeUtf8(allocator: arena);
      final fileNameCStr = fileName.toNativeUtf8(allocator: arena);
      final extCStr = fileType.ext.toNativeUtf8(allocator: arena);
      final mimeCStr = fileType.mimeType.toNativeUtf8(allocator: arena);
      final saveLocationIndex = switch (saveLocation) {
        IosSaveLocation location => location.index,
        MacosSaveLocation location => location.index,
        _ => 0, // Default to documents
      };
      final subDirCStr = subDir?.toNativeUtf8(allocator: arena);

      // Listen to native port - cleanup happens here on terminal events
      receivePort.listen((message) {
        if (cleanedUp || controller.isClosed) return;

        final event = _parseMessage(message);
        controller.addSync(event);

        if (isTerminal(event)) cleanup();
      });

      // Call native function - returns tokenId for cancellation
      final tokenId = _bindings.file_saver_save_file(
        _saverInstance,
        filePathCStr.cast(),
        fileNameCStr.cast(),
        extCStr.cast(),
        mimeCStr.cast(),
        saveLocationIndex,
        subDirCStr?.cast() ?? nullptr,
        conflictResolution.index,
        nativePort,
      );

      controller.onCancel = () {
        _bindings.file_saver_cancel(tokenId);
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
      final receivePort = ReceivePort();
      final arena = Arena();
      final nativePort = receivePort.sendPort.nativePort;
      bool cleanedUp = false;

      void cleanup() {
        if (cleanedUp) return;
        cleanedUp = true;
        receivePort.close();
        arena.releaseAll();
        controller.closeSync();
      }

      // Allocate in arena - all freed together with arena.releaseAll()
      final urlCStr = url.toNativeUtf8(allocator: arena);
      final headersJsonCStr =
          headers != null
              ? jsonEncode(headers).toNativeUtf8(allocator: arena)
              : null;
      final fileNameCStr = fileName.toNativeUtf8(allocator: arena);
      final extCStr = fileType.ext.toNativeUtf8(allocator: arena);
      final mimeCStr = fileType.mimeType.toNativeUtf8(allocator: arena);
      final saveLocationIndex = switch (saveLocation) {
        IosSaveLocation location => location.index,
        MacosSaveLocation location => location.index,
        _ => 0, // Default to documents
      };
      final subDirCStr = subDir?.toNativeUtf8(allocator: arena);

      // Listen to native port - cleanup happens here on terminal events
      receivePort.listen((message) {
        if (cleanedUp || controller.isClosed) return;

        final event = _parseMessage(message);
        controller.addSync(event);

        if (isTerminal(event)) cleanup();
      });

      // Call native function - returns tokenId for cancellation
      final tokenId = _bindings.file_saver_save_network(
        _saverInstance,
        urlCStr.cast(),
        headersJsonCStr?.cast() ?? nullptr,
        timeout.inSeconds,
        fileNameCStr.cast(),
        extCStr.cast(),
        mimeCStr.cast(),
        saveLocationIndex,
        subDirCStr?.cast() ?? nullptr,
        conflictResolution.index,
        nativePort,
      );

      controller.onCancel = () {
        _bindings.file_saver_cancel(tokenId);
        // Fallback cleanup if native doesn't respond with Cancelled event
        Future.delayed(const Duration(milliseconds: 500), cleanup);
      };
    });
  }

  /// Parses message from native code according to protocol:
  /// - Started:    [0]
  /// - Progress:   [1, progress]    (progress is 0.0 to 1.0)
  /// - Error:      [2, errorCode, errorMessage]
  /// - Success:    [3, fileUri]
  /// - Cancelled:  [4]
  SaveProgress _parseMessage(dynamic message) {
    if (message is! List || message.isEmpty) {
      return SaveProgressError(
        const PlatformException('Invalid message format', 'INVALID_MESSAGE'),
      );
    }

    final type = message[0] as int;

    switch (type) {
      case 0: // Started
        return const SaveProgressStarted();

      case 1: // Progress
        final progress = (message[1] as num).toDouble();
        return SaveProgressUpdate(progress);

      case 2: // Error
        final errorCode = message[1] as String;
        final errorMessage = message[2] as String;
        return SaveProgressError(
          FileSaverException.fromErrorResult(errorCode, errorMessage),
        );

      case 3: // Success
        final fileUri = message[1] as String;
        return SaveProgressComplete(Uri.parse(fileUri));

      case 4: // Cancelled
        return const SaveProgressCancelled();

      default:
        return SaveProgressError(
          PlatformException('Unknown message type: $type', 'UNKNOWN_TYPE'),
        );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // User-Selected Location (Document Picker)
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<UserSelectedLocation?> pickDirectory({
    bool shouldPersist = true,
  }) async {
    // Note: shouldPersist is ignored on iOS - no persistent URI permissions support
    final completer = Completer<UserSelectedLocation?>();
    final receivePort = ReceivePort();
    final nativePort = receivePort.sendPort.nativePort;

    receivePort.listen((message) {
      receivePort.close();

      if (message is! List || message.isEmpty) {
        completer.completeError(
          const PlatformException('Invalid message format', 'INVALID_MESSAGE'),
        );
        return;
      }

      final type = message[0] as int;
      switch (type) {
        case 3: // Success
          final dirUri = message[1] as String;
          completer.complete(UserSelectedLocation(uri: Uri.parse(dirUri)));
        case 4: // Cancelled
          completer.complete(null);
        case 2: // Error
          final errorCode = message[1] as String;
          final errorMessage = message[2] as String;
          completer.completeError(
            FileSaverException.fromErrorResult(errorCode, errorMessage),
          );
        default:
          completer.completeError(
            PlatformException('Unknown message type: $type', 'UNKNOWN_TYPE'),
          );
      }
    });

    _bindings.file_saver_pick_directory(_saverInstance, nativePort);

    return completer.future;
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
        conflictResolution: conflictResolution,
      ),
      SaveFileInput(:final filePath) => _saveFileAs(
        filePath: filePath,
        directoryUri: saveLocation.uri.toString(),
        baseFileName: fileName,
        extension: fileType.ext,
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
          conflictResolution: conflictResolution,
        ),
    };
  }

  Stream<SaveProgress> _saveBytesAs({
    required Uint8List fileBytes,
    required String directoryUri,
    required String baseFileName,
    required String extension,
    required ConflictResolution conflictResolution,
  }) {
    return Stream.multi((controller) {
      final receivePort = ReceivePort();
      final arena = Arena();
      final nativePort = receivePort.sendPort.nativePort;
      bool cleanedUp = false;

      void cleanup() {
        if (cleanedUp) return;
        cleanedUp = true;
        receivePort.close();
        arena.releaseAll();
        controller.closeSync();
      }

      final dataPointer = arena<Uint8>(fileBytes.length);
      dataPointer.asTypedList(fileBytes.length).setAll(0, fileBytes);
      final dirUriCStr = directoryUri.toNativeUtf8(allocator: arena);
      final baseFileNameCStr = baseFileName.toNativeUtf8(allocator: arena);
      final extCStr = extension.toNativeUtf8(allocator: arena);

      receivePort.listen((message) {
        if (cleanedUp || controller.isClosed) return;
        final event = _parseMessage(message);
        controller.addSync(event);
        if (isTerminal(event)) cleanup();
      });

      final tokenId = _bindings.file_saver_save_bytes_as(
        _saverInstance,
        dataPointer,
        fileBytes.length,
        dirUriCStr.cast(),
        baseFileNameCStr.cast(),
        extCStr.cast(),
        conflictResolution.index,
        nativePort,
      );

      controller.onCancel = () {
        _bindings.file_saver_cancel(tokenId);
        Future.delayed(const Duration(milliseconds: 500), cleanup);
      };
    });
  }

  Stream<SaveProgress> _saveFileAs({
    required String filePath,
    required String directoryUri,
    required String baseFileName,
    required String extension,
    required ConflictResolution conflictResolution,
  }) {
    return Stream.multi((controller) {
      final receivePort = ReceivePort();
      final arena = Arena();
      final nativePort = receivePort.sendPort.nativePort;
      bool cleanedUp = false;

      void cleanup() {
        if (cleanedUp) return;
        cleanedUp = true;
        receivePort.close();
        arena.releaseAll();
        controller.closeSync();
      }

      final filePathCStr = filePath.toNativeUtf8(allocator: arena);
      final dirUriCStr = directoryUri.toNativeUtf8(allocator: arena);
      final baseFileNameCStr = baseFileName.toNativeUtf8(allocator: arena);
      final extCStr = extension.toNativeUtf8(allocator: arena);

      receivePort.listen((message) {
        if (cleanedUp || controller.isClosed) return;
        final event = _parseMessage(message);
        controller.addSync(event);
        if (isTerminal(event)) cleanup();
      });

      final tokenId = _bindings.file_saver_save_file_as(
        _saverInstance,
        filePathCStr.cast(),
        dirUriCStr.cast(),
        baseFileNameCStr.cast(),
        extCStr.cast(),
        conflictResolution.index,
        nativePort,
      );

      controller.onCancel = () {
        _bindings.file_saver_cancel(tokenId);
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
    required ConflictResolution conflictResolution,
  }) {
    return Stream.multi((controller) {
      final receivePort = ReceivePort();
      final arena = Arena();
      final nativePort = receivePort.sendPort.nativePort;
      bool cleanedUp = false;

      void cleanup() {
        if (cleanedUp) return;
        cleanedUp = true;
        receivePort.close();
        arena.releaseAll();
        controller.closeSync();
      }

      final urlCStr = url.toNativeUtf8(allocator: arena);
      final headersJsonCStr =
          headers != null
              ? jsonEncode(headers).toNativeUtf8(allocator: arena)
              : null;
      final dirUriCStr = directoryUri.toNativeUtf8(allocator: arena);
      final baseFileNameCStr = baseFileName.toNativeUtf8(allocator: arena);
      final extCStr = extension.toNativeUtf8(allocator: arena);

      receivePort.listen((message) {
        if (cleanedUp || controller.isClosed) return;
        final event = _parseMessage(message);
        controller.addSync(event);
        if (isTerminal(event)) cleanup();
      });

      final tokenId = _bindings.file_saver_save_network_as(
        _saverInstance,
        urlCStr.cast(),
        headersJsonCStr?.cast() ?? nullptr,
        timeout.inSeconds,
        dirUriCStr.cast(),
        baseFileNameCStr.cast(),
        extCStr.cast(),
        conflictResolution.index,
        nativePort,
      );

      controller.onCancel = () {
        _bindings.file_saver_cancel(tokenId);
        Future.delayed(const Duration(milliseconds: 500), cleanup);
      };
    });
  }
}
