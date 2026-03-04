import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dir_picker/dir_picker.dart' as dp;
import 'package:web/web.dart';

import '../../exceptions/file_saver_exceptions.dart';
import '../../models/conflict_resolution.dart';
import '../../models/file_type.dart';
import '../../models/locations/save_location.dart';
import '../../models/locations/web_save_location.dart';
import '../../models/save_input.dart';
import '../../models/save_progress.dart';
import '../../platform_interface/file_saver_platform.dart';

class FileSaverWeb extends FileSaverPlatform {
  static void registerWith(dynamic registrar) =>
      FileSaverPlatform.instance = FileSaverWeb();

  @override
  void dispose() {}

  // ─────────────────────────────────────────────────────────────────────────
  // pickDirectory
  // ─────────────────────────────────────────────────────────────────────────

  /// Shows `window.showDirectoryPicker()` via `dir_picker` and returns a
  /// [WebSelectedLocation] wrapping the chosen [FileSystemDirectoryHandle].
  ///
  /// Returns `null` if the user cancels.
  /// Throws [PlatformException] if the browser does not support the
  /// File System Access API (Firefox / Safari).
  @override
  Future<UserSelectedLocation?> pickDirectory({
    bool shouldPersist = true,
  }) async {
    try {
      final location = await dp.DirPicker.pick();
      if (location == null) return null; // user cancelled
      if (location is! dp.WebSelectedLocation) {
        throw const PlatformException('Unexpected picker result on web.');
      }

      return WebSelectedLocation(location.handle);
    } catch (e) {
      // dir_picker is an external package and will not throw FileSaverException.
      // Any error here means the browser doesn't support showDirectoryPicker.
      throw PlatformException(
        'Directory picker unavailable. '
        'File System Access API not supported in this browser. ($e)',
      );
    }
  }

  // ─────────────────────────────────────────────
  // saveBytes (browser controlled)
  // ─────────────────────────────────────────────

  @override
  Stream<SaveProgress> saveBytes({
    required Uint8List fileBytes,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) async* {
    validateBytesInput(fileBytes, fileName);
    _triggerDownload(fileBytes, '$fileName.${fileType.ext}', fileType.mimeType);
    yield SaveProgressComplete(
      Uri(scheme: 'browser-download', path: '$fileName.${fileType.ext}'),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // saveFile
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Stream<SaveProgress> saveFile({
    required String filePath,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) async* {
    throw const InvalidInputException(
      'saveFile is not supported on web. Use saveBytes or saveNetwork instead.',
    );
  }

  // ─────────────────────────────────────────────
  // saveNetwork (browser controlled)
  // ─────────────────────────────────────────────

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
  }) async* {
    validateNetworkInput(url, fileName);

    yield const SaveProgressStarted();

    final fullName = '$fileName.${fileType.ext}';

    try {
      // No custom headers → let browser stream natively.
      if (headers == null || headers.isEmpty) {
        _triggerUrlDownload(url, fullName, fileType.mimeType);
        yield SaveProgressComplete(
          Uri(scheme: 'browser-download', path: fullName),
        );
        return;
      }

      // Custom headers require fetch() — loads file into memory (browser limitation).
      final controller = AbortController();
      final timer = Timer(timeout, () => controller.abort());
      try {
        final response = await _fetch(url, controller, headers: headers);

        if (!response.ok) {
          yield SaveProgressError(
            NetworkException('HTTP ${response.status}: ${response.statusText}'),
          );
          return;
        }

        final blob = await response.blob().toDart;
        _triggerBlobDownload(blob, fullName);
        yield SaveProgressComplete(
          Uri(scheme: 'browser-download', path: fullName),
        );
      } finally {
        timer.cancel();
      }
    } on FileSaverException catch (e) {
      yield SaveProgressError(e);
    } catch (e) {
      if (e.toString().contains('AbortError')) {
        yield SaveProgressError(
          NetworkException('Download timed out or aborted'),
        );
      } else {
        yield SaveProgressError(NetworkException(e.toString()));
      }
    }
  }

  // ─────────────────────────────────────────────
  // saveAs (FSA zero-RAM streaming)
  // ─────────────────────────────────────────────
  @override
  Stream<SaveProgress> saveAs({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    required UserSelectedLocation saveLocation,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    // If FSA is supported and we have a valid WebSelectedLocation
    if (saveLocation is WebSelectedLocation) {
      return switch (input) {
        SaveBytesInput(:final fileBytes) => _saveToDirectory(
          handle: saveLocation.directoryHandle,
          fileBytes: fileBytes,
          fileType: fileType,
          fileName: fileName,
        ),
        SaveNetworkInput(:final url, :final headers, :final timeout) =>
          _saveNetworkToDirectory(
            handle: saveLocation.directoryHandle,
            url: url,
            headers: headers,
            timeout: timeout,
            fileType: fileType,
            fileName: fileName,
          ),
        SaveFileInput() =>
          throw const InvalidInputException(
            'saveFile is not supported on web.',
          ),
      };
    }

    // ─────────────────────────────────────────
    // Fallback for browsers WITHOUT FSA
    // ─────────────────────────────────────────

    // ⚠ Browser will control download location.
    return switch (input) {
      SaveBytesInput(:final fileBytes) => saveBytes(
        fileBytes: fileBytes,
        fileType: fileType,
        fileName: fileName,
      ),
      SaveNetworkInput(:final url, :final headers, :final timeout) =>
        saveNetwork(
          url: url,
          fileName: fileName,
          fileType: fileType,
          headers: headers,
          timeout: timeout,
        ),
      SaveFileInput() =>
        throw const InvalidInputException('saveFile is not supported on web.'),
    };
  }

  // ─────────────────────────────────────────────
  // FSA: Save Bytes
  // ─────────────────────────────────────────────

  Stream<SaveProgress> _saveToDirectory({
    required FileSystemDirectoryHandle handle,
    required Uint8List fileBytes,
    required FileType fileType,
    required String fileName,
  }) async* {
    validateBytesInput(fileBytes, fileName);

    final fullName = '$fileName.${fileType.ext}';

    try {
      final fileHandle =
          await handle
              .getFileHandle(fullName, FileSystemGetFileOptions(create: true))
              .toDart;

      final writable = await fileHandle.createWritable().toDart;

      await writable.write(fileBytes.toJS as FileSystemWriteChunkType).toDart;

      await writable.close().toDart;

      yield SaveProgressComplete(Uri(scheme: 'web-directory', path: fullName));
    } catch (e) {
      yield SaveProgressError(FileIOException(e.toString()));
    }
  }

  // ─────────────────────────────────────────────
  // FSA: Zero-RAM streaming download
  // ─────────────────────────────────────────────

  Stream<SaveProgress> _saveNetworkToDirectory({
    required FileSystemDirectoryHandle handle,
    required String url,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 60),
    required FileType fileType,
    required String fileName,
  }) async* {
    validateNetworkInput(url, fileName);

    final fullName = '$fileName.${fileType.ext}';
    final controller = AbortController();

    Timer? idleTimer;

    void resetIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(timeout, () {
        controller.abort();
      });
    }

    try {
      resetIdleTimer();
      final response = await _fetch(url, controller, headers: headers);

      if (!response.ok) {
        yield SaveProgressError(
          NetworkException('HTTP ${response.status}: ${response.statusText}'),
        );
        return;
      }

      final fileHandle =
          await handle
              .getFileHandle(fullName, FileSystemGetFileOptions(create: true))
              .toDart;

      final writable = await fileHandle.createWritable().toDart;

      final total = int.tryParse(response.headers.get('content-length') ?? '');

      final reader = response.body!.getReader() as ReadableStreamDefaultReader;

      int written = 0;

      resetIdleTimer();

      while (true) {
        final result = await reader.read().toDart;
        if (result.done) break;

        resetIdleTimer();

        final chunk = (result.value! as JSUint8Array).toDart;

        await writable.write(chunk.toJS as FileSystemWriteChunkType).toDart;

        written += chunk.lengthInBytes;

        if (total != null && total > 0) {
          yield SaveProgressUpdate(written / total);
        }
      }

      idleTimer?.cancel();
      await writable.close().toDart;

      yield SaveProgressComplete(Uri(scheme: 'web-directory', path: fullName));
    } on FileSaverException catch (e) {
      yield SaveProgressError(e);
    } catch (e) {
      idleTimer?.cancel();

      if (e.toString().contains('AbortError')) {
        yield SaveProgressError(
          NetworkException('Download timed out or aborted'),
        );
      } else {
        yield SaveProgressError(FileIOException(e.toString()));
      }
    }
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  void _triggerDownload(Uint8List bytes, String fullName, String mimeType) {
    final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: mimeType));
    _triggerBlobDownload(blob, fullName);
  }

  void _triggerBlobDownload(Blob blob, String fullName) {
    final objectUrl = URL.createObjectURL(blob);
    _anchorClick(
      document.createElement('a') as HTMLAnchorElement
        ..href = objectUrl
        ..download = fullName,
    );
    URL.revokeObjectURL(objectUrl);
  }

  void _triggerUrlDownload(String url, String fullName, String mimeType) {
    _anchorClick(
      document.createElement('a') as HTMLAnchorElement
        ..href = url
        ..type = mimeType
        ..download = fullName,
    );
  }

  void _anchorClick(HTMLAnchorElement anchor) {
    document.body!.append(anchor);
    anchor.click();
    anchor.remove();
  }

  Headers _headersToJs(Map<String, String>? headers) {
    final h = Headers();
    headers?.forEach((key, value) => h.append(key, value));
    return h;
  }

  Future<Response> _fetch(
    String url,
    AbortController controller, {
    Map<String, String>? headers,
  }) async {
    try {
      return await window
          .fetch(
            url.toJS,
            RequestInit(
              method: 'GET',
              headers: _headersToJs(headers),
              signal: controller.signal,
            ),
          )
          .toDart;
    } catch (e) {
      // fetch() will throw on network errors or CORS issues.
      throw NetworkException(e.toString());
    }
  }
}
