library;

import 'package:flutter/foundation.dart';

import 'src/exceptions/file_saver_exceptions.dart';
import 'src/models/conflict_resolution.dart';
import 'src/models/file_type.dart';
import 'src/models/save_input.dart';
import 'src/models/locations/save_location.dart';
import 'src/models/save_progress.dart';
import 'src/platform_interface/file_saver_platform.dart';
// Conditional imports — IO platforms on non-web, stubs on web.
import 'src/platforms/io_platforms.dart'
    if (dart.library.html) 'src/platforms/io_stub.dart';
import 'src/platforms/web/file_saver_web.dart'
    if (dart.library.io) 'src/platforms/web_stub.dart';

// Public API
export 'src/exceptions/file_saver_exceptions.dart';
export 'src/models/conflict_resolution.dart';
export 'src/models/file_type.dart';
export 'src/models/save_input.dart';
export 'src/models/locations/save_location.dart';
export 'src/models/save_progress.dart';
// Required for dartPluginClass / pluginClass: Flutter's dart_plugin_registrant.dart
// imports this library and calls the platform's registerWith() method.
export 'src/platforms/io_platforms.dart'
    if (dart.library.html) 'src/platforms/io_stub.dart';
export 'src/platforms/web/file_saver_web.dart'
    if (dart.library.io) 'src/platforms/web_stub.dart';

class FileSaver {
  FileSaver._() {
    // All platforms are initialized here on first access to FileSaver.instance.
    FileSaverPlatform.instance =
        kIsWeb
            ? FileSaverWeb()
            : switch (defaultTargetPlatform) {
              TargetPlatform.android => FileSaverAndroid(),
              TargetPlatform.iOS || TargetPlatform.macOS => FileSaverDarwin(),
              TargetPlatform.linux => FileSaverLinux(),
              TargetPlatform.windows => FileSaverWindows(),
              _ =>
                throw UnsupportedError(
                  'FileSaver is not supported on $defaultTargetPlatform',
                ),
            };
  }

  static final FileSaver instance = FileSaver._();

  FileSaverPlatform get _platform => FileSaverPlatform.instance;

  /// Resources are automatically released on app termination,
  /// but call dispose() for timely cleanup.
  void dispose() {
    _platform.dispose();
  }

  /// Unified save entrypoint for all input sources.
  ///
  /// Delegates to [saveBytes], [saveFile], or [saveNetwork] based on [input].
  /// See those APIs for detailed behavior and platform notes.
  Stream<SaveProgress> save({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) {
    return switch (input) {
      SaveBytesInput(:final fileBytes) => saveBytes(
        fileBytes: fileBytes,
        fileType: fileType,
        fileName: fileName,
        saveLocation: saveLocation,
        subDir: subDir,
        conflictResolution: conflictResolution,
      ),
      SaveFileInput(:final filePath) => saveFile(
        filePath: filePath,
        fileType: fileType,
        fileName: fileName,
        saveLocation: saveLocation,
        subDir: subDir,
        conflictResolution: conflictResolution,
      ),
      SaveNetworkInput(:final url, :final headers, :final timeout) =>
        saveNetwork(
          url: url,
          fileType: fileType,
          fileName: fileName,
          headers: headers,
          timeout: timeout,
          saveLocation: saveLocation,
          subDir: subDir,
          conflictResolution: conflictResolution,
        ),
    };
  }

  /// Async wrapper for [save] with optional progress callback.
  ///
  /// Delegates to [saveBytesAsync], [saveFileAsync], or [saveNetworkAsync]
  /// based on [input]. See those APIs for detailed behavior and errors.
  Future<Uri> saveAsync({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
  }) async {
    return switch (input) {
      SaveBytesInput(:final fileBytes) => saveBytesAsync(
        fileBytes: fileBytes,
        fileType: fileType,
        fileName: fileName,
        saveLocation: saveLocation,
        subDir: subDir,
        conflictResolution: conflictResolution,
        onProgress: onProgress,
      ),
      SaveFileInput(:final filePath) => saveFileAsync(
        filePath: filePath,
        fileType: fileType,
        fileName: fileName,
        saveLocation: saveLocation,
        subDir: subDir,
        conflictResolution: conflictResolution,
        onProgress: onProgress,
      ),
      SaveNetworkInput(:final url, :final headers, :final timeout) =>
        saveNetworkAsync(
          url: url,
          fileType: fileType,
          fileName: fileName,
          headers: headers,
          timeout: timeout,
          saveLocation: saveLocation,
          subDir: subDir,
          conflictResolution: conflictResolution,
          onProgress: onProgress,
        ),
    };
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
  ///   fileBytes: imageBytes,
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

  /// Downloads a file from a network URL and saves to device storage with progress streaming.
  ///
  /// The file is downloaded at the native level to avoid double storage:
  /// - Android: Streams directly from network to MediaStore OutputStream (zero temp files)
  /// - iOS Documents: Downloads directly to the target path (zero temp files)
  /// - iOS Photos: Downloads to tmp, saves to Photos Library, then deletes tmp
  ///
  /// Yields progress events during download and save operation:
  /// - [SaveProgressStarted]: Operation began
  /// - [SaveProgressUpdate]: Progress from 0.0 to 1.0
  /// - [SaveProgressComplete]: Success with URI
  /// - [SaveProgressError]: Failed with exception
  /// - [SaveProgressCancelled]: User cancelled
  ///
  /// Parameters:
  /// - [url]: The URL to download the file from
  /// - [fileName]: The name of the file without extension
  /// - [fileType]: The file type (determines extension and MIME type)
  /// - [headers]: Optional HTTP headers for the request
  /// - [timeout]: Timeout for the network request (defaults to 60 seconds)
  /// - [saveLocation]: Where to save the file (platform-specific, optional)
  ///   - If not specified, defaults to:
  ///     - Android: [AndroidSaveLocation.downloads]
  ///     - iOS: [IosSaveLocation.documents] (app's Documents directory)
  /// - [subDir]: Optional subdirectory within the save location
  /// - [conflictResolution]: How to handle filename conflicts
  ///
  /// Example:
  /// ```dart
  /// await for (final event in FileSaver.instance.saveNetwork(
  ///   url: 'https://example.com/photo.jpg',
  ///   headers: {'Authorization': 'Bearer token'},
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
    return _platform.saveNetwork(
      url: url,
      fileName: fileName,
      fileType: fileType,
      headers: headers,
      timeout: timeout,
      saveLocation: saveLocation,
      subDir: subDir,
      conflictResolution: conflictResolution,
    );
  }

  /// Convenience wrapper around [saveNetwork] that returns a [Future].
  ///
  /// This method listens to the progress stream from [saveNetwork] and converts it
  /// into an optional [onProgress] callback.
  ///
  /// Parameters:
  /// - See [saveNetwork] for all parameters except [onProgress].
  /// - [onProgress]: Optional callback receiving progress from 0.0 to 1.0
  ///
  /// Returns the [Uri] where the file was saved.
  ///
  /// Throws:
  /// - [FileSaverException] or subclass if the save operation fails
  /// - [NetworkException] if the download fails
  ///
  /// See also:
  /// - [saveNetwork] for stream-based progress handling.
  ///
  /// Example:
  /// ```dart
  /// final uri = await FileSaver.instance.saveNetworkAsync(
  ///   url: 'https://example.com/photo.jpg',
  ///   fileName: 'photo',
  ///   fileType: ImageType.jpg,
  ///   onProgress: (progress) => print('${(progress * 100).toInt()}%'),
  /// );
  /// ```
  Future<Uri> saveNetworkAsync({
    required String url,
    required String fileName,
    required FileType fileType,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 60),
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
  }) async {
    Uri? result;

    await for (final event in saveNetwork(
      url: url,
      fileName: fileName,
      fileType: fileType,
      headers: headers,
      timeout: timeout,
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

  // ─────────────────────────────────────────────────────────────────────────
  // User-Selected Location (SAF / Document Picker)
  // ─────────────────────────────────────────────────────────────────────────

  /// Pick a directory for saving files.
  ///
  /// Shows the system directory picker:
  /// - **Android**: Storage Access Framework (ACTION_OPEN_DOCUMENT_TREE)
  /// - **iOS**: UIDocumentPickerViewController
  ///
  /// Parameters:
  /// - [shouldPersist]: Whether to persist write permission to the selected
  ///   directory. Defaults to `true`.
  ///   - **Android**: If `true`, calls `takePersistableUriPermission` so the
  ///     app can write to this directory across app restarts without re-picking.
  ///   - **iOS**: Ignored (iOS doesn't support persistent URI permissions).
  ///
  /// Returns [UserSelectedLocation] with the selected directory URI,
  /// or `null` if the user cancelled.
  ///
  /// Example:
  /// ```dart
  /// final location = await FileSaver.instance.pickDirectory();
  /// if (location == null) {
  ///   print('User cancelled');
  ///   return;
  /// }
  ///
  /// // Save a file to the selected directory
  /// await FileSaver.instance.saveAsAsync(
  ///   input: SaveInput.bytes(imageBytes),
  ///   fileType: ImageType.png,
  ///   fileName: 'screenshot',
  ///   saveLocation: location,
  /// );
  /// ```
  Future<UserSelectedLocation?> pickDirectory({bool shouldPersist = true}) {
    return _platform.pickDirectory(shouldPersist: shouldPersist);
  }

  /// Save to user-selected directory with progress streaming.
  ///
  /// If [saveLocation] is null, shows the system picker first (auto pickDirectory).
  /// Returns [SaveProgressCancelled] if picker is cancelled.
  ///
  /// Parameters:
  /// - [input]: The save input (bytes, file path, or network URL)
  /// - [fileType]: The type of file being saved
  /// - [fileName]: The file name without extension
  /// - [saveLocation]: Optional user-selected directory. If null, shows picker.
  /// - [conflictResolution]: How to handle filename conflicts
  ///
  /// Yields [SaveProgress] events during save operation.
  ///
  /// Example (auto picker):
  /// ```dart
  /// await for (final event in FileSaver.instance.saveAs(
  ///   input: SaveInput.bytes(imageBytes),
  ///   fileType: ImageType.png,
  ///   fileName: 'screenshot',
  ///   // saveLocation: null → shows picker first
  /// )) {
  ///   switch (event) {
  ///     case SaveProgressStarted():
  ///       showLoading();
  ///     case SaveProgressUpdate(:final progress):
  ///       updateProgressBar(progress);
  ///     case SaveProgressComplete(:final uri):
  ///       showSuccess('Saved to $uri');
  ///     case SaveProgressCancelled():
  ///       showMessage('Cancelled');
  ///     case SaveProgressError(:final exception):
  ///       showError(exception.message);
  ///   }
  /// }
  /// ```
  ///
  /// Example (batch save with picked location):
  /// ```dart
  /// final location = await FileSaver.instance.pickDirectory();
  /// if (location == null) return;
  ///
  /// for (final file in files) {
  ///   await for (final event in FileSaver.instance.saveAs(
  ///     input: SaveInput.bytes(file.bytes),
  ///     fileType: file.type,
  ///     fileName: file.name,
  ///     saveLocation: location,  // Reuse picked location
  ///   )) {
  ///     // handle events...
  ///   }
  /// }
  /// ```
  Stream<SaveProgress> saveAs({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    UserSelectedLocation? saveLocation,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) async* {
    yield const SaveProgressStarted();

    // Resolve location
    UserSelectedLocation? resolvedLocation = saveLocation;
    if (resolvedLocation == null) {
      try {
        final picked = await pickDirectory();
        if (picked == null) {
          yield const SaveProgressCancelled();
          return;
        }
        resolvedLocation = picked;
      } on FileSaverException catch (e) {
        yield SaveProgressError(e);
        return;
      } catch (e) {
        if (kIsWeb) {
          // Browser doesn't support FSA (Firefox / Safari).
          // Pass a plain UserSelectedLocation so FileSaverWeb.saveAs()
          // falls through to its anchor-download fallback.
          resolvedLocation = UserSelectedLocation(uri: Uri());
        } else {
          yield SaveProgressError(PlatformException(e.toString()));
          return;
        }
      }
    }

    // Delegate to platform
    yield* _platform.saveAs(
      input: input,
      fileType: fileType,
      fileName: fileName,
      saveLocation: resolvedLocation,
      conflictResolution: conflictResolution,
    );
  }

  /// Async wrapper for [saveAs] with optional progress callback.
  ///
  /// If [saveLocation] is null, shows the system picker first (auto pickDirectory).
  /// Returns `null` if picker is cancelled.
  ///
  /// Parameters:
  /// - [input]: The save input (bytes, file path, or network URL)
  /// - [fileType]: The type of file being saved
  /// - [fileName]: The file name without extension
  /// - [saveLocation]: Optional user-selected directory. If null, shows picker.
  /// - [conflictResolution]: How to handle filename conflicts
  /// - [onProgress]: Optional callback receiving progress from 0.0 to 1.0
  ///
  /// Returns the [Uri] where the file was saved, or `null` if cancelled.
  ///
  /// Example:
  /// ```dart
  /// final uri = await FileSaver.instance.saveAsAsync(
  ///   input: SaveInput.bytes(imageBytes),
  ///   fileType: ImageType.png,
  ///   fileName: 'screenshot',
  ///   onProgress: (p) => print('${(p * 100).toInt()}%'),
  /// );
  ///
  /// if (uri == null) {
  ///   print('User cancelled');
  /// } else {
  ///   print('Saved to: $uri');
  /// }
  /// ```
  Future<Uri?> saveAsAsync({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    UserSelectedLocation? saveLocation,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
    void Function(double progress)? onProgress,
  }) async {
    Uri? result;

    await for (final event in saveAs(
      input: input,
      fileType: fileType,
      fileName: fileName,
      saveLocation: saveLocation,
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
          return null;
      }
    }

    return result;
  }
}
