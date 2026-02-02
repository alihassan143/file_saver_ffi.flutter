<p align="center">
  <img alt="cover" src="https://raw.githubusercontent.com/vanvixi/file_saver_ffi.flutter/main/screenshots/cover.png" />
</p>

## File Saver FFI
<p align="left">
  <a href="https://pub.dev/packages/file_saver_ffi"><img src="https://img.shields.io/pub/v/file_saver_ffi.svg" alt="Pub"></a>
  <a href="https://github.com/vanvixi/file_saver_ffi"><img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue.svg" alt="Platform"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

A high-performance file saver for Flutter using FFI and JNI. Effortlessly save to gallery (images/videos) or device storage with original quality and custom album support.

## Features

- 🖼️ **Gallery Saving** – Save images and videos to iOS Photos or Android Gallery with custom albums
- ⚡ **Native Performance** – Powered by FFI (iOS) and JNI (Android) for near-zero latency
- 📁 **Universal Storage** – Save any file type (PDF, ZIP, DOCX, etc.) to device storage
- 💾 **Original Quality** – Files saved bit-for-bit without compression or metadata loss
- 📊 **Progress & Cancellation** – Real-time progress tracking with cancellable operations
- ⚙️ **Conflict Resolution** – Auto-rename, overwrite, skip, or fail on existing files

If you want to say thank you, star us on GitHub or like us on pub.dev.

## 🤖 Ask AI About This Library

Have questions about `file_saver_ffi`? Get instant AI-powered answers about the library's features, usage, and best practices.

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/vanvixi/file_saver_ffi.flutter)

**[→ Chat with AI Documentation Assistant](https://deepwiki.com/vanvixi/file_saver_ffi.flutter)**

Ask anything like:
- "How do I save a video to the gallery with progress tracking?"
- "What's the difference between saveBytes and saveFile?"
- "How to handle permission errors on Android 10+?"
- "Show me examples of custom file types"

## Installation

First, follow the [package installation instructions](https://pub.dev/packages/file_saver_ffi/install) and add `file_saver_ffi` to your app.

## Quick Start

### Platform Setup

<details>
<summary><b>Android Configuration</b></summary>

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Only required for Android 9 (API 28) and below -->
<uses-permission
        android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28"/>
```

> **Note:** Android 10+ uses scoped storage automatically and does not require this permission.

**Supported:** API 21+ (Android 5.0+)

</details>

<details>
<summary><b>iOS Configuration</b></summary>

Add to `ios/Runner/Info.plist`:

```xml
<!-- For Photos Library Access (images/videos) -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs permission to save photos and videos to your library</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs permission to access your photo library</string>

<!-- Prevent automatic "Select More Photos" prompt on iOS 14+ -->
<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>
<true/>

<!-- Optional: Make files visible in Files app -->
<key>UIFileSharingEnabled</key>
<true/>

<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

**Supported:** iOS 13.0+

</details>

### Basic Usage

```dart
import 'package:file_saver_ffi/file_saver_ffi.dart';

try {
  // Save image bytes
  final uri = await FileSaver.instance.saveBytesAsync(
    fileBytes: imageBytes,
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

## Core Concepts

### API Methods

The library provides methods organized by **input source** and **API style**:

#### Input Sources
- **Bytes** (`save*Bytes*`) - Save data from memory (`Uint8List`)
- **File** (`save*File*`) - Save from file path (efficient for large files)
- **Network** - Download and save from URL *(planned)*

#### API Styles
- **Stream** (`save*`) - Full control with progress events and cancellation
- **Async** (`save*Async`) - Simple Future-based API with optional progress callback
- **Interactive** (`save*As`) - User picks save location *(planned)*

#### API Matrix

| Input Source | Stream API | Async API | Interactive |
|--------------|-----------|-----------|---------------|
| **Bytes** | `saveBytes()` | `saveBytesAsync()` | `saveBytesAs()` |
| **File** | `saveFile()` | `saveFileAsync()` | `saveFileAs()` |
| **Network** | `saveNetworkFile()` | `saveNetworkFileAsync()` | `saveNetworkFileAs()` |

**When to use:**
- `save*()` - Need real-time progress, cancellation, or full event control
- `save*Async()` - Simple save with optional progress callback
- `save*As()` - Let user choose save location via system picker

### File Types

The library supports 35+ file formats across 4 categories:

| Category | Formats | Count | Example Types |
|----------|---------|-------|---------------|
| **Images** | PNG, JPG, GIF, WebP, BMP, HEIC, HEIF, TIFF, ICO, DNG | 12 | `ImageType.png`, `ImageType.jpg` |
| **Videos** | MP4, MOV, MKV, WebM, AVI, 3GP, M4V, FLV, WMV, HEVC | 12 | `VideoType.mp4`, `VideoType.mov` |
| **Audio** | MP3, AAC, WAV, FLAC, OGG, M4A, AMR, Opus, AIFF, CAF | 11 | `AudioType.mp3`, `AudioType.aac` |
| **Custom** | Any format via extension + MIME type | ∞ | `CustomFileType(ext: 'pdf', mimeType: 'application/pdf')` |

### Save Locations

Control where files are saved using platform-specific `SaveLocation` enums.

#### Android (`AndroidSaveLocation`)

Maps to standard Android MediaStore directories.

| Enum Value | Storage Directory | Use Case |
|------------|-------------------|----------|
| `.downloads` (default) | `Downloads/` | General files, PDFs, Docs |
| `.pictures` | `Pictures/` | Images (png, jpg, etc.) |
| `.movies` | `Movies/` | Videos (mp4, mov, etc.) |
| `.music` | `Music/` | Audio files |
| `.dcim` | `DCIM/` | Camera photos/videos |

#### iOS (`IosSaveLocation`)

Maps to either the Files app (Documents) or Photos app.

| Enum Value | Destination | Use Case |
|------------|-------------|----------|
| `.documents` (default) | Documents Directory | Any file type. Visible in **Files** app |
| `.photos` | Photos Library | Images & Videos only. Requires permission |

**Example:**
```dart
import 'dart:io' show Platform;

final uri = await FileSaver.instance.saveBytesAsync(
  // ...
  saveLocation: Platform.isAndroid
    ? AndroidSaveLocation.pictures  // Android-specific
    : IosSaveLocation.photos,       // iOS-specific
);
```

### Conflict Resolution

Handle existing files with 4 strategies:

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `autoRename` (default) | Appends (1), (2), etc. to filename | Safe, prevents data loss |
| `overwrite` | Replaces existing file* | Update existing files |
| `fail` | Throws `FileExistsException` | Strict validation |
| `skip` | Returns existing file URI | Idempotent saves |

\* **Platform limitations:** 
- iOS Photos: Can only overwrite files owned by your app
- Android 10+: Can only overwrite files owned by your app (scoped storage)

## Common Use Cases

### Save to Gallery

```dart
import 'dart:io' show Platform;

// Save image to Photos Library (iOS) or Pictures (Android)
final uri = await FileSaver.instance.saveBytesAsync(
  fileBytes: imageBytes,
  fileName: 'photo',
  fileType: ImageType.jpg,
  saveLocation: Platform.isAndroid
    ? AndroidSaveLocation.pictures
    : IosSaveLocation.photos,
  subDir: 'My App', // Creates album (iOS) or folder (Android)
);
```

### Progress Tracking

```dart
// Stream API - Full control
await for (final event in FileSaver.instance.saveBytes(
  fileBytes: largeVideoBytes,
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
      showCancelled();
  }
}

// Async API - Simple callback
final uri = await FileSaver.instance.saveBytesAsync(
  fileBytes: largeVideoBytes,
  fileName: 'video',
  fileType: VideoType.mp4,
  onProgress: (progress) {
    print('Progress: ${(progress * 100).toInt()}%');
  },
);
```

> **Note:** Progress is reported in 1MB chunks. For iOS Photos Library saves, progress jumps from 0% to 100% due to API limitations.

### Cancellation

```dart
StreamSubscription<SaveProgress>? subscription;

subscription = FileSaver.instance.saveBytes(
  fileBytes: largeVideoBytes,
  fileName: 'video',
  fileType: VideoType.mp4,
).listen((event) {
  switch (event) {
    case SaveProgressUpdate(:final progress):
      updateProgressBar(progress);
    case SaveProgressCancelled():
      showMessage('Cancelled and cleaned up!');
    // ... handle other events
  }
});

// Cancel when needed
cancelButton.onPressed = () {
  subscription?.cancel(); // Stops I/O, deletes partial file, emits SaveProgressCancelled
};
```

### Error Handling

```dart
try {
  final uri = await FileSaver.instance.saveBytesAsync(
    fileBytes: pdfBytes,
    fileName: 'document',
    fileType: CustomFileType(ext: 'pdf', mimeType: 'application/pdf'),
  );
  
  print('✅ Saved: $uri');

} on PermissionDeniedException catch (e) {
  print('❌ Permission denied: ${e.message}');
  // Request permissions

} on FileExistsException catch (e) {
  print('❌ File exists: ${e.fileName}');
  // Handle conflict

} on StorageFullException catch (e) {
  print('❌ Storage full: ${e.message}');
  // Show storage full message

} on FileSaverException catch (e) {
  print('❌ Save failed: ${e.message}');
  // Generic error handling
}
```

## Platform Differences

### Storage Locations

| Aspect | Android | iOS |
|--------|---------|-----|
| **Default location** | Downloads/ | Documents/ |
| **Gallery access** | MediaStore (no permission on 10+) | Photos Library (requires permission) |
| **Custom files** | Public directories via MediaStore | App sandbox (Documents/) |
| **File visibility** | Visible in file managers | Visible in Files app if `UIFileSharingEnabled` |

### Overwrite Behavior

| Scenario | Android 9- | Android 10+ | iOS Photos | iOS Documents |
|----------|-----------|-------------|-----------|---------------|
| **Own files** | ✅ Overwrite | ✅ Overwrite | ✅ Overwrite | ✅ Overwrite |
| **Other apps' files** | ✅ Overwrite | ⚠️ Auto-rename* | ⚠️ Duplicate | N/A (sandboxed) |

\* Android 10+ scoped storage cannot detect files from other apps before saving

### SubDir Parameter

- **Android:** Creates folder in MediaStore collection (e.g., `Pictures/My App/`)
- **iOS Photos:** Creates album with specified name
- **iOS Documents:** Creates subdirectory (e.g., `Documents/My App/`)

## Exception Reference

| Exception | Description | Error Code |
|-----------|-------------|------------|
| `PermissionDeniedException` | Storage access denied | `PERMISSION_DENIED` |
| `FileExistsException` | File exists with `fail` strategy | `FILE_EXISTS` |
| `StorageFullException` | Insufficient device storage | `STORAGE_FULL` |
| `InvalidFileException` | Empty bytes or invalid filename | `INVALID_FILE` |
| `FileIOException` | File system error | `FILE_IO_ERROR` |
| `UnsupportedFormatException` | Format not supported on platform | `UNSUPPORTED_FORMAT` |
| `SourceFileNotFoundException` | Source file not found (saveFile) | `FILE_NOT_FOUND` |
| `ICloudDownloadException` | iCloud download failed (iOS) | `ICLOUD_DOWNLOAD_FAILED` |
| `CancelledException` | Operation cancelled by user | `CANCELLED` |
| `PlatformException` | Generic platform error | `PLATFORM_ERROR` |

## API Reference

### Bytes Methods

Save data from memory (`Uint8List`).

| Method | Returns | Description |
|--------|---------|-------------|
| `saveBytes()` | `Stream<SaveProgress>` | Stream API with full control, cancellation, and progress events |
| `saveBytesAsync()` | `Future<Uri>` | Async API with optional progress callback |

**Common Parameters:**
- `fileBytes` (required) - File content as `Uint8List`
- `fileName` (required) - File name without extension
- `fileType` (required) - `ImageType`, `VideoType`, `AudioType`, or `CustomFileType`
- `saveLocation` (optional) - Platform-specific save location (defaults: Android=Downloads, iOS=Documents)
- `subDir` (optional) - Subdirectory/album name
- `conflictResolution` (optional) - Default: `ConflictResolution.autoRename`
- `onProgress` (optional, Async only) - Progress callback `(double progress) => void`

### File Methods

Save from file path (efficient for large files, no memory loading).

| Method | Returns | Description |
|--------|---------|-------------|
| `saveFile()` | `Stream<SaveProgress>` | Stream API with full control, cancellation, and progress events |
| `saveFileAsync()` | `Future<Uri>` | Async API with optional progress callback |

**Common Parameters:**
- `filePath` (required) - Source file path (`file://` or `content://` URI)
- `fileName` (required) - Target file name without extension
- `fileType` (required) - `ImageType`, `VideoType`, `AudioType`, or `CustomFileType`
- `saveLocation` (optional) - Platform-specific save location
- `subDir` (optional) - Subdirectory/album name
- `conflictResolution` (optional) - Default: `ConflictResolution.autoRename`
- `onProgress` (optional, Async only) - Progress callback `(double progress) => void`

**iOS iCloud Support:** When saving files from iCloud Drive, progress shows download (0-50%) + save (50-100%).

### Network Methods

*Planned for future release - download and save files from URLs.*

### SaveProgress Events

Stream API emits these sealed class events:

| Event | Properties | Description |
|-------|-----------|-------------|
| `SaveProgressStarted` | - | Operation began |
| `SaveProgressUpdate` | `progress: double` | Progress from 0.0 to 1.0 |
| `SaveProgressComplete` | `uri: Uri` | Success with saved file URI |
| `SaveProgressError` | `exception: FileSaverException` | Error occurred |
| `SaveProgressCancelled` | - | User cancelled operation |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Future Features

* ~~File Input Methods~~
* Save from Network URL
* User-Selected Location Android (SAF), iOS (Document Picker)
* Custom Path Support
* ~~Progress Tracking~~
* ~~Cancellation Support~~
* ~~Save from File Path~~
* MacOS Support
* Windows Support
* Web Support

## License

MIT License - see [LICENSE](LICENSE) file for details.
