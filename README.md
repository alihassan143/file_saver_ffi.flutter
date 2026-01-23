<p align="center">
  <img alt="cover" src="https://raw.githubusercontent.com/vanvixi/file_saver_ffi.flutter/main/screenshots/cover.png" />
</p>

## File Saver FFI
<p align="left">
  <a href="https://pub.dev/packages/file_saver_ffi"><img src="https://img.shields.io/pub/v/file_saver_ffi.svg" alt="Pub"></a>
  <a href="https://github.com/vanvixi/file_saver_ffi"><img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue.svg" alt="Platform"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

A high-performance file saver for Flutter using FFI and JNI. Effortlessly save to gallery (images/videos) or device storage with original quality and custom album support..

## Features

- 🖼️ **One-Click Gallery Saving** – Save images and videos directly to **iOS Photos** or **Android Gallery** with full MediaStore and ALAssetsLibrary integration.
- 📁 **Universal File Storage** – Effortlessly save any file type (PDF, ZIP, DOCX, etc.) to device-specific storage using a unified, easy-to-use API.
- ⚡ **Native Performance** – Powered by **FFI (iOS/C++)** and **JNI (Android/Java)** for near-zero latency, bypassing the overhead of traditional MethodChannels.
- 🎯 **Smart Organization** – Full support for custom **Albums (iOS)** or **Subdirectories (Android)** to keep user files neatly organized.
- 💾 **Original Quality Guaranteed** – Files are saved bit-for-bit at their **Original Quality** without any forced compression or metadata loss.
- ⚙️ **Conflict Resolution** – Built-in logic to handle existing files: `Auto-rename`, `Overwrite`, `Skip`, or `Fail`.
- 📂 **Granular Location Control** – Explicitly define save paths (Downloads, Documents, etc.) using platform-specific options for maximum flexibility.
- 🔒 **Type-Safe API** – Leverages Dart 3.x **Sealed Classes** and pattern matching to ensure robust, compile-time safe code.

If you want to say thank you, star us on GitHub or like us on pub.dev.

## Supported Platforms

| Platform    | Minimum Version        | Notes                               |
|-------------|------------------------|-------------------------------------|
| **Android** | API 21+ (Android 5.0+) | Scoped storage for Android 10+      |
| **iOS**     | 13.0+                  | Photos framework with album support |

## Setup

### Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Only required for Android 9 (API 28) and below -->
<uses-permission
        android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28"/>
```

**Note:** Android 10+ (API 29+) uses scoped storage automatically and does not require this permission.

### iOS Configuration

Add to `ios/Runner/Info.plist`:

#### For Photos Library Access (Required for images/videos)

```xml

<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs permission to save photos and videos to your library</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs permission to access your photo library</string>

<!-- Prevent automatic "Select More Photos" prompt on iOS 14+ -->
<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>
<true/>
```

> **Note:** On iOS 14+, if the user selects "Limited Photos" access, iOS may automatically show a dialog prompting them to select more photos. The `PHPhotoLibraryPreventAutomaticLimitedAccessAlert` key prevents this automatic dialog, providing a better user experience.

#### For Files App Visibility (Optional for custom files)

Files are saved to the Application Documents Directory. To make them visible to users in the Files app, add:

```xml

<key>UIFileSharingEnabled</key>
<true/>

<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

## Quick Start

```dart
import 'package:file_saver_ffi/file_saver_ffi.dart';

try {
  // Save image bytes (simple API)
  final uri = await FileSaver.instance.saveBytesAsync(
    bytes: imageBytes,
    fileName: 'my_image',
    fileType: ImageType.jpg,
  );

  print('Saved to: $uri');
} on PermissionDeniedException catch (e) {
  print('Permission denied: ${e.message}');
} on FileSaverException catch (e) {
  print('Save failed: ${e.message}');
}
```

## Progress Tracking

Track save progress in real-time using the streaming API or callback-based API.

### Stream-Based API (Full Control)

```dart
await for (final event in FileSaver.instance.saveBytes(
  bytes: largeVideoBytes,
  fileName: 'video',
  fileType: VideoType.mp4,
)) {
  switch (event) {
    case SaveProgressStarted():
      showLoadingIndicator();
    case SaveProgressUpdate(:final progress):
      updateProgressBar(progress); // 0.0 to 1.0
    case SaveProgressComplete(:final uri):
      hideLoadingIndicator();
      showSuccess('Saved to: $uri');
    case SaveProgressError(:final exception):
      hideLoadingIndicator();
      showError(exception.message);
    case SaveProgressCancelled():
      hideLoadingIndicator();
  }
}
```

### Callback-Based API (Simple)

```dart
final uri = await FileSaver.instance.saveBytesAsync(
  bytes: largeVideoBytes,
  fileName: 'video',
  fileType: VideoType.mp4,
  onProgress: (progress) {
    print('Progress: ${(progress * 100).toInt()}%');
  },
);
```

> **Note:** Progress is reported as chunked writes (1MB chunks). For Photos Library saves on iOS, progress jumps from 0% to 100% due to API limitations.

## Supported File Types

### Images (12 formats)

`PNG`, `JPG`, `JPEG`, `GIF`, `WebP`, `BMP`, `HEIC`, `HEIF`, `TIFF`, `TIF`, `ICO`, `DNG`

```dart
ImageType.png
ImageType.jpg
ImageType.gif
ImageType.webp
// ... and more
```

### Videos (12 formats)

`MP4`, `3GP`, `WebM`, `M4V`, `MKV`, `MOV`, `AVI`, `FLV`, `WMV`, `HEVC`, `VP9`, `AV1`

```dart
VideoType.mp4
VideoType.mov
VideoType.mkv
// ... and more
```

### Audio (11 formats)

`MP3`, `AAC`, `WAV`, `AMR`, `3GP`, `M4A`, `OGG`, `FLAC`, `Opus`, `AIFF`, `CAF`

```dart
AudioType.mp3
AudioType.aac
AudioType.wav
// ... and more
```

### Custom File Types

Support any file format by specifying extension and MIME type:

```dart
CustomFileType(
  ext: 'pdf',
  mimeType: 'application/pdf'
)
CustomFileType(
  ext: 'docx', 
  mimeType:'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
)
```

## Save Locations

Control where files are saved with platform-specific save location options. Each platform has different storage directories optimized for different file types.

### Default Behavior

If you don't specify a save location, the library uses sensible defaults:

- **Android**: `AndroidSaveLocation.downloads` - Files go to the Downloads folder
- **iOS**: `IosSaveLocation.documents` - Files go to the app's Documents directory (no permission required)

### Android Save Locations

```dart
AndroidSaveLocation.pictures   // Pictures/ (for images)
AndroidSaveLocation.movies     // Movies/ (for videos)
AndroidSaveLocation.music      // Music/ (for audio)
AndroidSaveLocation.downloads  // Downloads/ (default, for any file type)
AndroidSaveLocation.dcim       // DCIM/ (for camera photos)
```

### iOS Save Locations

```dart
IosSaveLocation.photos     // Photos Library (requires Photos permission)
IosSaveLocation.documents  // Documents/ directory (default, no permission)
```

### Examples

```dart
import 'dart:io' show Platform;

// Save image to Photos Library on iOS, Pictures on Android
final uri = await FileSaver.instance.saveBytesAsync(
  bytes: imageBytes,
  fileName: 'photo',
  fileType: ImageType.jpg,
  saveLocation: Platform.isAndroid
    ? AndroidSaveLocation.pictures
    : IosSaveLocation.photos,
);

// Save video to DCIM (Android) or Photos (iOS)
final uri = await FileSaver.instance.saveBytesAsync(
  bytes: videoBytes,
  fileName: 'camera_video',
  fileType: VideoType.mp4,
  saveLocation: Platform.isAndroid
    ? AndroidSaveLocation.dcim
    : IosSaveLocation.photos,
);

// Use default location (no saveLocation specified)
// Android → Downloads/, iOS → Documents/
final uri = await FileSaver.instance.saveBytesAsync(
  bytes: pdfBytes,
  fileName: 'document',
  fileType: CustomFileType(ext: 'pdf', mimeType: 'application/pdf'),
);
```

### Platform Compatibility

| SaveLocation | File Types | Android | iOS |
|--------------|------------|---------|-----|
| `pictures` | Images | ✅ Pictures/ | ✅ Photos Library (if `.photos`) or Documents/ (if `.documents`) |
| `movies` | Videos | ✅ Movies/ | ✅ Photos Library (if `.photos`) or Documents/ (if `.documents`) |
| `music` | Audio | ✅ Music/ | ✅ Documents/ only |
| `downloads` | Any | ✅ Downloads/ | ✅ Documents/ only |
| `dcim` | Images/Videos | ✅ DCIM/ | ✅ Photos Library (if `.photos`) or Documents/ (if `.documents`) |
| `photos` | Images/Videos | N/A | ✅ Photos Library (requires permission) |
| `documents` | Any | N/A | ✅ Documents/ directory (no permission) |

**Note:** On iOS, only image and video files can be saved to Photos Library (`.photos`). Audio and custom files always use Documents directory regardless of the saveLocation parameter.

## Conflict Resolution Strategies

Control what happens when a file with the same name already exists:

| Strategy               | Behavior                                       | Use Case                 |
|------------------------|------------------------------------------------|--------------------------|
| `autoRename` (default) | Appends (1), (2), etc. to filename             | Safe, prevents data loss |
| `overwrite`            | Replaces existing file                         | Update existing files    |
| `fail`                 | Returns `SaveFailure` with "FILE_EXISTS" error | Strict validation        |
| `skip`                 | Returns `SaveSuccess` with existing file path  | Idempotent saves         |

### Overwrite Behavior (Platform-Specific)

The `overwrite` strategy behaves differently across platforms:

#### iOS

**Images & Videos (Photos Library):**
- ✅ **Files owned by your app** - Successfully overwritten (deletes old, adds new)
- ⚠️ **Files from other apps** - Cannot be deleted; iOS allows duplicate names to coexist
  - iOS Photos Library has built-in mechanisms to keep files with the same name from different apps
  - Your file will be added alongside the existing file (both will exist)

**Custom Files (Documents Directory):**
- ✅ **Full overwrite capability** - Each app has its own sandbox
- Files from other apps are isolated and inaccessible due to iOS sandbox security

#### Android 9 and Below (API 28-)
- ✅ **Full overwrite capability** - Can replace any existing file
- Requires `WRITE_EXTERNAL_STORAGE` permission

#### Android 10+ (API 29+)

**All File Types (MediaStore):**
- ✅ **Files owned by your app** - Successfully overwritten
- ⚠️ **Files from other apps** - Cannot be detected; will be auto-renamed instead

**Important Platform Limitation:**

Due to [Scoped Storage](https://developer.android.com/about/versions/11/privacy/storage) security, **files created by other apps cannot be detected** before saving. The library can only detect and handle conflicts for files owned by your app.

**What happens when a file from another app exists:**
- With `autoRename`: MediaStore automatically renames your file (e.g., `photo.jpg` → `photo (1).jpg`)
- With `overwrite`: Your file will be auto-renamed instead of overwriting (same as `autoRename`)
- With `fail` or `skip`: Behavior is unpredictable as the conflict cannot be detected

**Why this happens:**
Android's Scoped Storage uses different APIs with different scopes:
- **Query API** (used for conflict detection): Scoped to your app's files only
- **Insert API** (used for saving): Has global check to prevent overwrites

This is Android's platform design for security, not a library limitation.

---

### Platform Comparison Summary

| Scenario | iOS Photos | iOS Documents | Android 9- | Android 10+ |
|----------|-----------|---------------|------------|-------------|
| **Own files** | ✅ Overwrite | ✅ Overwrite | ✅ Overwrite | ✅ Overwrite |
| **Other apps' files** | ⚠️ Duplicate | N/A (sandboxed) | ✅ Overwrite | ⚠️ Auto-rename |

### Example

```dart
try {
  final uri = await FileSaver.instance.saveBytesAsync(
    bytes: fileBytes,
    fileName: 'document',
    fileType: CustomFileType(ext: 'pdf', mimeType: 'application/pdf'),
    conflictResolution: ConflictResolution.autoRename,
  );

  // If "document.pdf" exists, saves as "document (1).pdf"
  print('Saved to: $uri');
} on FileSaverException catch (e) {
  print('Error: ${e.message}');
}
```

## Advanced Usage

### Save with Subdirectory/Album

```dart
try {
  final uri = await FileSaver.instance.saveBytesAsync(
    bytes: videoBytes,
    fileName: 'vacation_video',
    fileType: VideoType.mp4,
    saveLocation: Platform.isAndroid
      ? AndroidSaveLocation.movies
      : IosSaveLocation.photos,
    subDir: 'My Vacations', // Creates album on iOS, folder on Android
  );

  print('Video saved to: $uri');
} on FileSaverException catch (e) {
  print('Error: ${e.message}');
}
```

### Save to Specific Location

```dart
import 'dart:io' show Platform;

// Save to Photos Library (iOS) or Pictures folder (Android)
try {
  final uri = await FileSaver.instance.saveBytesAsync(
    bytes: imageBytes,
    fileName: 'screenshot',
    fileType: ImageType.png,
    saveLocation: Platform.isAndroid
      ? AndroidSaveLocation.pictures
      : IosSaveLocation.photos,
  );

  print('Image saved to: $uri');
} on FileSaverException catch (e) {
  print('Error: ${e.message}');
}

// Save to Downloads (Android) or Documents (iOS) - using defaults
try {
  final uri = await FileSaver.instance.saveBytesAsync(
    bytes: pdfBytes,
    fileName: 'report',
    fileType: CustomFileType(ext: 'pdf', mimeType: 'application/pdf'),
    // No saveLocation specified - uses platform defaults
  );

  print('PDF saved to: $uri');
} on FileSaverException catch (e) {
  print('Error: ${e.message}');
}
```

### Complete Example with Error Handling

```dart
import 'dart:io' show Platform;

try {
  final uri = await FileSaver.instance.saveBytesAsync(
    bytes: pdfBytes,
    fileName: 'invoice_${DateTime.now().millisecondsSinceEpoch}',
    fileType: CustomFileType(ext: 'pdf', mimeType: 'application/pdf'),
    saveLocation: Platform.isAndroid
      ? AndroidSaveLocation.downloads
      : IosSaveLocation.documents,
    subDir: 'Invoices',
    conflictResolution: ConflictResolution.autoRename,
  );

  print('✅ Saved successfully!');
  print('URI: $uri');

} on PermissionDeniedException catch (e) {
  print('❌ Permission denied: ${e.message}');
  // Request permissions

} on FileExistsException catch (e) {
  print('❌ File already exists: ${e.fileName}');
  // Handle conflict

} on StorageFullException catch (e) {
  print('❌ Storage full: ${e.message}');
  // Show storage full message

} on InvalidFileException catch (e) {
  print('❌ Invalid file: ${e.message}');
  // Validate file data

} on FileSaverException catch (e) {
  print('❌ Save failed: ${e.message}');
  // Generic error handling
}
```

## Platform-Specific Behavior

### File Storage Locations

Storage locations are now controlled by the `saveLocation` parameter. Below are the default locations when `saveLocation` is not specified:

#### Android (Default: `downloads`)

| File Type    | Default Location      | URI Format                      |
|--------------|----------------------|---------------------------------|
| All Files    | `Downloads/[subDir]/`| `content://media/external/...`  |

You can override this with any `AndroidSaveLocation`:
- `pictures` → `Pictures/[subDir]/`
- `movies` → `Movies/[subDir]/`
- `music` → `Music/[subDir]/`
- `dcim` → `DCIM/[subDir]/`

#### iOS (Default: `documents`)

| File Type    | Default Location               | URI Format  |
|--------------|--------------------------------|-------------|
| All Files    | `Documents/[subDir]/`          | `file://`   |

You can override with `IosSaveLocation.photos` for images and videos:
- `photos` → Photos Library album `[subDir]` (requires permission) → `ph://`
- `documents` → `Documents/[subDir]/` (no permission required) → `file://`

### SubDir Parameter

- **iOS:** Creates an album in the Photos app with the specified name
- **Android:** Creates a folder in the appropriate MediaStore collection

**Example:**

```dart
// iOS: Creates "My App" album in Photos
// Android: Creates Pictures/My App/ folder
subDir: 'My App'
```

## Error Handling

The library provides specific exception types for different failure scenarios:

| Exception                    | Description                         | Error Code              |
|------------------------------|-------------------------------------|-------------------------|
| `PermissionDeniedException`  | Storage access denied               | `PERMISSION_DENIED`     |
| `FileExistsException`        | File exists with `fail` strategy    | `FILE_EXISTS`           |
| `StorageFullException`       | Insufficient device storage         | `STORAGE_FULL`          |
| `InvalidFileException`       | Empty bytes or invalid filename     | `INVALID_FILE`          |
| `FileIOException`            | File system error                   | `FILE_IO`               |
| `UnsupportedFormatException` | Format not supported on platform    | `UNSUPPORTED_FORMAT`    |
| `PlatformException`          | Generic platform-specific error     | `PLATFORM_ERROR`        |

### Handling Errors

```dart
try {
  final uri = await FileSaver.instance.saveBytesAsync(...);
  print('Saved to: $uri');

} on PermissionDeniedException catch (e) {
  // Request permissions
  print('Permission denied: ${e.message}');

} on FileExistsException catch (e) {
  // File already exists with fail strategy
  print('File already exists: ${e.fileName}');

} on StorageFullException catch (e) {
  // Show storage full message
  print('Storage full: ${e.message}');

} on FileSaverException catch (e) {
  // Generic error handling
  print('Save failed: ${e.message}');
}
```

## API Reference

### FileSaver

Singleton API class for saving files.

#### saveBytesAsync (Recommended)

Simple Future-based API with optional progress callback.

```dart
Future<Uri> saveBytesAsync({
  required Uint8List bytes,
  required String fileName,
  required FileType fileType,
  SaveLocation? saveLocation,
  String? subDir,
  ConflictResolution conflictResolution = ConflictResolution.autoRename,
  void Function(double progress)? onProgress,
})
```

**Parameters:**
- `bytes` - File content as byte array
- `fileName` - File name without extension
- `fileType` - Type of file (ImageType, VideoType, AudioType, CustomFileType)
- `saveLocation` - (Optional) Platform-specific save location
  - Android: `AndroidSaveLocation.downloads` (default)
  - iOS: `IosSaveLocation.documents` (default)
- `subDir` - (Optional) Subdirectory/album name
- `conflictResolution` - Strategy for handling name conflicts (default: `autoRename`)
- `onProgress` - (Optional) Progress callback (0.0 to 1.0)

**Returns:** `Uri` of the saved file

**Throws:** `FileSaverException` or subtypes on failure

#### saveBytes (Stream API)

Stream-based API for full control over progress events.

```dart
Stream<SaveProgress> saveBytes({
  required Uint8List bytes,
  required String fileName,
  required FileType fileType,
  SaveLocation? saveLocation,
  String? subDir,
  ConflictResolution conflictResolution = ConflictResolution.autoRename,
})
```

**Returns:** `Stream<SaveProgress>` with events:
- `SaveProgressStarted` - Operation started
- `SaveProgressUpdate(double progress)` - Progress 0.0 to 1.0
- `SaveProgressComplete(Uri uri)` - Success with file URI
- `SaveProgressError(FileSaverException exception)` - Error occurred
- `SaveProgressCancelled` - User cancelled

### SaveLocation

Sealed class with platform-specific implementations:

```dart
// Android options
enum AndroidSaveLocation implements SaveLocation {
  pictures,   // Pictures/
  movies,     // Movies/
  music,      // Music/
  downloads,  // Downloads/ (default)
  dcim,       // DCIM/
}

// iOS options
enum IosSaveLocation implements SaveLocation {
  photos,     // Photos Library (requires permission)
  documents,  // Documents/ (default, no permission)
}
```

### ConflictResolution

Enum for conflict resolution strategies:

```dart
enum ConflictResolution {
  autoRename, // Append (1), (2), etc.
  overwrite,  // Replace existing file
  fail,       // Throw FileExistsException
  skip,       // Return existing file URI
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Future Features
* File Input Methods
* Save from Network URL
* User-Selected Location Android (SAF), iOS (Document Picker)
* Custom Path Support
* ~~Progress Tracking~~
* MacOS Support
* Windows Support
* Web Support
