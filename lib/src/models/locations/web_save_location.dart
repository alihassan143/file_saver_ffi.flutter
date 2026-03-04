import 'package:web/web.dart';

import 'save_location.dart';

/// Web-only subtype of [UserSelectedLocation] carrying a
/// [FileSystemDirectoryHandle] from the File System Access API.
///
/// Returned by [FileSaverWeb.pickDirectory] on Chrome/Edge 86+.
/// Pass it to [FileSaver.saveAs] to write files directly into the chosen
/// directory — no dialog appears, no data is loaded into RAM for network files.
///
/// Example:
/// ```dart
/// final location = await FileSaver.instance.pickDirectory();
/// if (location == null) return; // cancelled or not supported
///
/// await FileSaver.instance.saveAsAsync(
///   input: SaveInput.bytes(imageBytes),
///   fileType: ImageType.png,
///   fileName: 'screenshot',
///   saveLocation: location, // WebSelectedLocation on web
/// );
/// ```
final class WebSelectedLocation extends UserSelectedLocation {
  WebSelectedLocation(this.directoryHandle)
    : super(uri: Uri(scheme: 'web-directory', path: directoryHandle.name));

  /// The [FileSystemDirectoryHandle] obtained from `window.showDirectoryPicker()`.
  final FileSystemDirectoryHandle directoryHandle;
}
