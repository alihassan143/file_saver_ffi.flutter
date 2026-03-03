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
    } on FileSaverException {
      rethrow;
    } catch (e) {
      // dir_picker throws if the browser doesn't support showDirectoryPicker
      // (Firefox / Safari). Surface this as an explicit PlatformException.
      throw PlatformException('Directory picker unavailable: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // saveBytes
  // ─────────────────────────────────────────────────────────────────────────

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
    yield const SaveProgressStarted();
    _triggerDownload(fileBytes, '$fileName.${fileType.ext}', fileType.mimeType);
    yield SaveProgressComplete(Uri(path: '$fileName.${fileType.ext}'));
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

  // ─────────────────────────────────────────────────────────────────────────
  // saveNetwork — silent download, no dialog
  // ─────────────────────────────────────────────────────────────────────────

  /// Downloads [url] and triggers a browser download — no save dialog appears.
  ///
  /// - No custom [headers]: anchor element with the direct URL; the browser
  ///   streams the file natively without loading it into RAM.
  /// - With custom [headers]: `fetch()` + `arrayBuffer()` (loaded into RAM).
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
      if (headers == null) {
        // No custom headers: browser streams natively.
        _triggerUrlDownload(url, fullName);
      } else {
        // Custom headers: fetch and stream chunks into RAM, then trigger download.
        Response response;
        try {
          final reqInit = RequestInit(headers: _headersToJs(headers));
          response = await window.fetch(url.toJS, reqInit).toDart;
        } catch (e) {
          yield SaveProgressError(NetworkException(e.toString()));
          return;
        }

        if (!response.ok) {
          yield SaveProgressError(
            NetworkException('HTTP ${response.status}: ${response.statusText}'),
          );
          return;
        }

        final totalBytes = int.tryParse(
          response.headers.get('content-length') ?? '',
        );
        final reader =
            response.body!.getReader() as ReadableStreamDefaultReader;
        final chunks = <Uint8List>[];
        var received = 0;
        while (true) {
          final result = await reader.read().toDart;
          if (result.done) break;
          final chunk = (result.value! as JSUint8Array).toDart;
          chunks.add(chunk);
          received += chunk.lengthInBytes;
          if (totalBytes != null && totalBytes > 0) {
            yield SaveProgressUpdate(received / totalBytes);
          }
        }
        final allBytes = Uint8List(received);
        var offset = 0;
        for (final chunk in chunks) {
          allBytes.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }
        _triggerDownload(allBytes, fullName, fileType.mimeType);
      }
      yield SaveProgressComplete(Uri.parse(url));
    } catch (e) {
      yield SaveProgressError(NetworkException(e.toString()));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // saveAs
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Stream<SaveProgress> saveAs({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    required UserSelectedLocation saveLocation,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    if (saveLocation is WebSelectedLocation) {
      // FSA path: write directly into the user-chosen directory.
      return switch (input) {
        SaveBytesInput(:final fileBytes) => _saveToDirectory(
          handle: saveLocation.directoryHandle,
          fileBytes: fileBytes,
          fileType: fileType,
          fileName: fileName,
        ),
        SaveNetworkInput(:final url, :final headers) => _saveNetworkToDirectory(
          handle: saveLocation.directoryHandle,
          url: url,
          headers: headers,
          fileType: fileType,
          fileName: fileName,
        ),
        SaveFileInput() =>
          throw const InvalidInputException(
            'saveFile is not supported on web.',
          ),
      };
    }

    // Fallback: browser-controlled download (no directory choice).
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

  // ─────────────────────────────────────────────────────────────────────────
  // FSA helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Writes [fileBytes] to [fileName] inside [handle].
  /// Zero RAM beyond the byte buffer already in memory.
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

  /// Streams [url] directly to [fileName] inside [handle] via `pipeTo` —
  /// the response body never enters JavaScript/Dart heap.
  ///
  /// Falls back to anchor-element download when the server does not send CORS
  /// headers and no custom [headers] are required. In that case the file lands
  /// in the browser's default Downloads folder, not the chosen directory.
  Stream<SaveProgress> _saveNetworkToDirectory({
    required FileSystemDirectoryHandle handle,
    required String url,
    Map<String, String>? headers,
    required FileType fileType,
    required String fileName,
  }) async* {
    validateNetworkInput(url, fileName);

    final fullName = '$fileName.${fileType.ext}';
    final reqInit =
        headers != null
            ? RequestInit(headers: _headersToJs(headers))
            : RequestInit();

    Response response;
    try {
      response = await window.fetch(url.toJS, reqInit).toDart;
    } catch (e) {
      yield SaveProgressError(NetworkException(e.toString()));
      return;
    }

    if (!response.ok) {
      yield SaveProgressError(
        NetworkException('HTTP ${response.status}: ${response.statusText}'),
      );
      return;
    }

    // Response is ready — stream chunks into the chosen directory.
    try {
      final fileHandle =
          await handle
              .getFileHandle(fullName, FileSystemGetFileOptions(create: true))
              .toDart;
      final writable = await fileHandle.createWritable().toDart;
      final totalBytes = int.tryParse(
        response.headers.get('content-length') ?? '',
      );
      final reader = response.body!.getReader() as ReadableStreamDefaultReader;
      var bytesWritten = 0;
      while (true) {
        final result = await reader.read().toDart;
        if (result.done) break;
        final chunk = (result.value! as JSUint8Array).toDart;
        await writable.write(chunk.toJS as FileSystemWriteChunkType).toDart;
        bytesWritten += chunk.lengthInBytes;
        if (totalBytes != null && totalBytes > 0) {
          yield SaveProgressUpdate(bytesWritten / totalBytes);
        }
      }
      await writable.close().toDart;
      yield SaveProgressComplete(Uri.parse(url));
    } catch (e) {
      yield SaveProgressError(FileIOException(e.toString()));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Anchor-based download helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _triggerDownload(Uint8List bytes, String fullName, String mimeType) {
    final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: mimeType));
    final objectUrl = URL.createObjectURL(blob);
    final anchor =
        document.createElement('a') as HTMLAnchorElement
          ..href = objectUrl
          ..download = fullName;
    document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(objectUrl);
  }

  void _triggerUrlDownload(String url, String fullName) {
    final anchor =
        document.createElement('a') as HTMLAnchorElement
          ..href = url
          ..download = fullName
          ..target = '_blank'
          ..rel = 'noopener noreferrer';
    document.body!.append(anchor);
    anchor.click();
    anchor.remove();
  }

  Headers _headersToJs(Map<String, String> headers) {
    final h = Headers();
    headers.forEach((key, value) => h.append(key, value));
    return h;
  }
}
