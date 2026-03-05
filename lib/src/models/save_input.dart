import 'dart:typed_data';

/// Base sealed class for save input types.
///
/// Defines the source of data to be saved:
/// - [SaveBytesInput]: Raw bytes in memory
/// - [SaveFileInput]: File path on disk
/// - [SaveNetworkInput]: URL to download from network
sealed class SaveInput {
  const SaveInput();

  static SaveBytesInput bytes(Uint8List fileBytes) => SaveBytesInput(fileBytes);

  static SaveFileInput file(String filePath) => SaveFileInput(filePath);

  static SaveNetworkInput network({
    required String url,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 60),
  }) => SaveNetworkInput(url: url, headers: headers, timeout: timeout);
}

/// Input from raw bytes in memory.
final class SaveBytesInput extends SaveInput {
  const SaveBytesInput(this.fileBytes);

  /// The file content as bytes.
  final Uint8List fileBytes;
}

/// Input from a file path on disk.
/// Does not support web, as browsers cannot access arbitrary file paths.
final class SaveFileInput extends SaveInput {
  const SaveFileInput(this.filePath);

  /// The source file path (file:// URI or content:// URI on Android).
  final String filePath;
}

/// Input from a network URL.
///
/// The file is downloaded natively to avoid double storage.
final class SaveNetworkInput extends SaveInput {
  const SaveNetworkInput({
    required this.url,
    this.headers,
    this.timeout = const Duration(seconds: 60),
  });

  /// The URL to download the file from.
  final String url;

  /// Optional HTTP headers for the request (e.g., Authorization).
  final Map<String, String>? headers;

  /// Inactivity timeout — how long to wait without receiving new data before
  /// aborting. Defaults to 60 seconds.
  ///
  /// On Web without custom headers, the browser controls the request and this
  /// value is ignored. On Web with custom headers, this is applied as a
  /// connection timeout (time until the server responds).
  final Duration timeout;
}
