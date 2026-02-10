/// Base sealed class for all save locations.
///
/// This class provides a type-safe way to specify where files should be saved
/// on different platforms. Each platform has its own set of supported locations
/// through platform-specific enum implementations.
sealed class SaveLocation {
  const SaveLocation();
}

/// Android-specific save locations.
///
/// These locations map to Android's MediaStore collections and storage directories.
///
/// Platform mappings:
/// - [pictures]: MediaStore.Images.Media (Pictures/ directory)
/// - [movies]: MediaStore.Video.Media (Movies/ directory)
/// - [music]: MediaStore.Audio.Media (Music/ directory)
/// - [downloads]: MediaStore.Downloads (Downloads/ directory)
/// - [dcim]: MediaStore.Images.Media (DCIM/ directory - camera photos)
enum AndroidSaveLocation implements SaveLocation {
  /// Save to Pictures/ directory via MediaStore.Images
  pictures,

  /// Save to Movies/ directory via MediaStore.Video
  movies,

  /// Save to Music/ directory via MediaStore.Audio
  music,

  /// Save to Downloads/ directory via MediaStore.Downloads (default)
  downloads,

  /// Save to DCIM/ directory (camera photos) via MediaStore.Images
  dcim;

  const AndroidSaveLocation();
}

/// iOS-specific save locations.
///
/// These locations map to iOS's Photos Library and FileManager directories.
///
/// Platform mappings:
/// - [photos]: Photos Library (requires Photos permission)
/// - [documents]: Documents/ directory in app's container (default, no permission required)
enum IosSaveLocation implements SaveLocation {
  /// Save to app's Documents/ directory (default)
  ///
  /// Files are saved to the app's Documents directory and are visible in
  /// the Files app under "On My iPhone/iPad" → [App Name].
  /// No special permissions required.
  documents,

  /// Save to Photos Library
  ///
  /// Requires Photos permission. Files are saved to the user's Photos app
  /// and can optionally be organized into albums using the subDir parameter.
  photos;

  const IosSaveLocation();
}

/// macOS-specific save locations.
///
/// Behavior depends on whether the app has `com.apple.security.app-sandbox` enabled:
///
/// - **With Sandbox**: Can only save to [documents] (App Container) and other locations
///   if the corresponding entitlement is set.
/// - **Without Sandbox**: Can save to any user-accessible directory.
enum MacosSaveLocation implements SaveLocation {
  /// Save to the standard ~/Downloads directory.
  ///
  /// In Sandbox: Requires `com.apple.security.files.downloads.read-write` entitlement.
  downloads,

  /// Save to the standard ~/Pictures directory.
  ///
  /// In Sandbox: Requires `com.apple.security.assets.pictures.read-write` entitlement.
  pictures,

  /// Save to the standard ~/Movies directory.
  ///
  /// In Sandbox: Requires `com.apple.security.assets.movies.read-write` entitlement.
  movies,

  /// Save to the standard ~/Music directory.
  ///
  /// In Sandbox: Requires `com.apple.security.assets.music.read-write` entitlement.
  music,

  /// Save to the app's specific Documents directory.
  ///
  /// In Sandbox: This is inside the App Container (`~/Library/Containers/<bundle-id>/Data/Documents/`).
  /// Without Sandbox: This is the global `~/Documents` directory.
  documents;

  const MacosSaveLocation();
}

/// User-selected directory location.
///
/// This represents a directory chosen by the user through the system picker:
/// - **Android**: Storage Access Framework (ACTION_OPEN_DOCUMENT_TREE)
/// - **iOS**: UIDocumentPickerViewController
///
/// Use [FileSaver.pickDirectory] to obtain a [UserSelectedLocation], then
/// pass it to [FileSaver.saveAs] or [FileSaver.saveAsAsync].
///
/// Example:
/// ```dart
/// // Pick once, save multiple files
/// final location = await FileSaver.instance.pickDirectory();
/// if (location == null) return; // User cancelled
///
/// // Save files to the selected location
/// await FileSaver.instance.saveAsAsync(
///   input: SaveInput.bytes(imageBytes),
///   fileType: ImageType.png,
///   fileName: 'screenshot',
///   saveLocation: location,
/// );
/// ```
final class UserSelectedLocation implements SaveLocation {
  const UserSelectedLocation({required this.uri});

  /// Directory URI from the system picker.
  ///
  /// - **Android**: Content URI from SAF (e.g., `content://...`)
  /// - **iOS**: File URL from Document Picker (e.g., `file://...`)
  final Uri uri;
}
