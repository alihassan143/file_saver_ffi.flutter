<p align="center">
  <img alt="cover" src="https://raw.githubusercontent.com/vanvixi/file_saver_ffi.flutter/main/screenshots/cover.png" />
</p>

## File Saver FFI

<p align="left">
  <a href="https://github.com/vanvixi/file_saver_ffi"><img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue.svg" alt="Platform"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
  <a href="https://deepwiki.com/vanvixi/file_saver_ffi.flutter"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
</p>

A high-performance file saver for Flutter using FFI and JNI. Effortlessly save to gallery (images/videos) or device
storage with original quality and custom album support.

## Features

- 🖼️ **Gallery Saving** – Save images and videos to iOS Photos or Android Gallery with custom albums
- ⚡ **Native Performance** – Powered by FFI (iOS) and JNI (Android) for near-zero latency
- 📁 **Universal Storage** – Save any file type (PDF, ZIP, DOCX, etc.) to device storage
- 💾 **Original Quality** – Files saved bit-for-bit without compression or metadata loss
- 📊 **Progress & Cancellation** – Real-time progress tracking with cancellable operations
- ⚙️ **Conflict Resolution** – Auto-rename, overwrite, skip, or fail on existing files

If you want to say thank you, star us on GitHub or like us on pub.dev.

## 🤖 Ask AI About This Library

Have questions about `file_saver_ffi`? Get instant AI-powered answers about the library's features, usage, and best
practices.

**[→ Chat with AI Documentation Assistant](https://deepwiki.com/vanvixi/file_saver_ffi.flutter)**

Ask anything like:

- "How do I save a video to the gallery with progress tracking?"
- "What's the difference between saveBytes and saveFile?"
- "How to handle permission errors on Android 10+?"
- "Show me examples of custom file types"

## Installation

First, follow the [package installation instructions](https://pub.dev/packages/file_saver_ffi/install) and add
`file_saver_ffi` to your app.

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
  final uri = await FileSaver.instance.saveAsync(
    fileBytes: SaveBytesInput(imageBytes),
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

### Unified API

The library provides a single, consistent API for all save operations using `SaveInput` polymorphism:

- **`save(input: ...)`**: Stream-based API with full control (progress, cancellation).
- **`saveAsync(input: ...)`**: Future-based API for simple usage.

#### Input Sources (`SaveInput`)

Use the appropriate input class for your data source:

| Input Type             | Data Source     | Use Case                                       |
|------------------------|-----------------|------------------------------------------------|
| **`SaveBytesInput`**   | `Uint8List`     | Small files in memory (images, generated PDFs) |
| **`SaveFileInput`**    | `String` (path) | Large files from disk (videos, recordings)     |
| **`SaveNetworkInput`** | `String` (URL)  | Download and save directly from internet       |

#### Usage Matrix 📊

|                                            | **Standard Location**<br>*(Downloads, Photos, etc.)* | **User-Chosen Location**<br>*(System Picker)* |
|:-------------------------------------------|:-----------------------------------------------------|:----------------------------------------------|
| **Advanced Control**<br>*(Stream, Cancel)* | **`save()`**                                         | **`saveAs()`**                                |
| **Simple / Await**<br>*(Future)*           | **`saveAsync()`**                                    | **`saveAsAsync()`**                           |

> *Standard Location*: defined enum (e.g., `Downloads`, `Photos`).
> *User-Chosen*: via `pickDirectory()` or auto-prompt.

### User-Selected Location (Save As)

Sometimes you want the user to choose where to save the file.

- **`pickDirectory()`**: Opens the system directory picker (Android SAF / iOS Document Picker) and returns a persistent permission URI (Android) or URL (iOS).
- **`saveAs()` / `saveAsAsync()`**: Saves a file to a user-selected location. If no location is provided, it automatically prompts the user to pick one.

> **Note:** On Android, this uses the Storage Access Framework (SAF), which allows your app to write to arbitrary locations (SD cards, USB drives, etc.) without standard storage permissions.

### File Types

The library supports 35+ file formats across 4 categories:

| Category   | Formats                                              | Count | Example Types                                             |
|------------|------------------------------------------------------|-------|-----------------------------------------------------------|
| **Images** | PNG, JPG, GIF, WebP, BMP, HEIC, HEIF, TIFF, ICO, DNG | 12    | `ImageType.png`, `ImageType.jpg`                          |
| **Videos** | MP4, MOV, MKV, WebM, AVI, 3GP, M4V, FLV, WMV, HEVC   | 12    | `VideoType.mp4`, `VideoType.mov`                          |
| **Audio**  | MP3, AAC, WAV, FLAC, OGG, M4A, AMR, Opus, AIFF, CAF  | 11    | `AudioType.mp3`, `AudioType.aac`                          |
| **Custom** | Any format via extension + MIME type                 | ∞     | `CustomFileType(ext: 'pdf', mimeType: 'application/pdf')` |

### Save Locations

Control where files are saved using platform-specific enum values:

#### Android (`AndroidSaveLocation`)
| Value        | Directory    | Use Case                |
|--------------|--------------|-------------------------|
| `.downloads` | `Downloads/` | General files (default) |
| `.pictures`  | `Pictures/`  | Images                  |
| `.movies`    | `Movies/`    | Videos                  |
| `.music`     | `Music/`     | Audio                   |
| `.dcim`      | `DCIM/`      | Camera media            |

#### iOS (`IosSaveLocation`)
| Value        | Destination    | Use Case                |
|--------------|----------------|-------------------------|
| `.documents` | Documents Dir  | General files (default) |
| `.photos`    | Photos Library | Images/Videos only      |

### Conflict Resolution

Handle existing files with 4 strategies:

| Strategy               | Behavior                           | Use Case                 |
|------------------------|------------------------------------|--------------------------|
| `autoRename` (default) | Appends (1), (2), etc. to filename | Safe, prevents data loss |
| `overwrite`            | Replaces existing file*            | Update existing files    |
| `fail`                 | Throws `FileExistsException`       | Strict validation        |
| `skip`                 | Returns existing file URI          | Idempotent saves         |

\* **Platform limitations:**

- iOS Photos: Can only overwrite files owned by your app
- Android 10+: Can only overwrite files owned by your app (scoped storage)

## Common Use Cases

### Download video from Network to Gallery

```dart
final uri = await FileSaver.instance.saveAsync(
  input: SaveNetworkInput(
    url: 'https://example.com/video.mp4',
    headers: {'Authorization': 'Bearer token'}, // Optional headers
    timeout: Duration(minutes: 5), // Custom timeout
  ),
  fileName: 'downloaded_video',
  fileType: VideoType.mp4,
  saveLocation: Platform.isAndroid
    ? AndroidSaveLocation.movies
    : IosSaveLocation.photos,
);
```

### Progress Tracking

```dart
// Using Unified API
await FileSaver.instance.saveAsync(
  input: SaveNetworkInput(url: '...'),
  fileName: 'video',
  fileType: VideoType.mp4,
  onProgress: (progress) {
    print('Download progress: ${(progress * 100).toInt()}%');
  },
);
```

### Cancellation

```dart
// Stream API allows cancellation
final subscription = FileSaver.instance.save(
  input: SaveNetworkInput(url: '...'), // Works for all inputs
  fileName: 'video',
  fileType: VideoType.mp4,
).listen((event) {
    if (event is SaveProgressCancelled) {
      print('Cancelled!');
    }
});

// Cancel anytime
subscription.cancel();
```

### Save to User-Selected Directory

```dart
// 1. Pick directory (Optional, saveAs handles this automatically if null)
final location = await FileSaver.instance.pickDirectory();

if (location != null) {
  // 2. Save file to that directory
  await FileSaver.instance.saveAsAsync(
    input: SaveBytesInput(pdfBytes),
    fileName: 'invoice',
    fileType: CustomFileType(ext: 'pdf', mimeType: 'application/pdf'),
    saveLocation: location,
  );
}
```

## API Reference

### Unified API (Recommended)

#### `save`
Stream-based API for advanced control (cancellation, detailed events).

```dart
Stream<SaveProgress> save({
  required SaveInput input,
  required String fileName,
  required FileType fileType,
  // ... same optional params
})
```

#### `saveAsync`
Future-based API for simple usage.

```dart
Future<Uri> saveAsync({
  required SaveInput input,
  required String fileName,
  required FileType fileType,
  SaveLocation? saveLocation,
  String? subDir,
  ConflictResolution conflictResolution,
  Function(double)? onProgress,
})
```

#### `saveAs`
Stream-based interactive save.

```dart
Stream<SaveProgress> saveAs({
  required SaveInput input,
  required String fileName,
  required FileType fileType,
  UserSelectedLocation? saveLocation,
  ConflictResolution conflictResolution,
})
```

#### `saveAsAsync`
Interactive save (shows picker) or save to specific `UserSelectedLocation`.

```dart
Future<Uri?> saveAsAsync({
  required SaveInput input,
  required String fileName,
  required FileType fileType,
  UserSelectedLocation? saveLocation, // Null = Show Picker
  ConflictResolution conflictResolution,
  Function(double)? onProgress,
})
```

#### `pickDirectory`
Open system picker to let user choose a folder.

```dart
Future<UserSelectedLocation?> pickDirectory({bool shouldPersist = true})
```

### Input Models

#### `SaveBytesInput`
- `fileBytes`: `Uint8List` (Required)

#### `SaveFileInput`
- `filePath`: `String` (Required - absolute path)

#### `SaveNetworkInput`
- `url`: `String` (Required)
- `headers`: `Map<String, String>?` (Optional)
- `timeout`: `Duration` (Default: 60s)

### Direct API

Specific methods are still available but `save/saveAsync` is recommended.

- `saveBytes` / `saveBytesAsync`
- `saveFile` / `saveFileAsync`
- `saveNetwork` / `saveNetworkAsync`

### SaveProgress Events

Stream API emits these sealed class events:

| Event                   | Properties                      | Description                 |
|-------------------------|---------------------------------|-----------------------------|
| `SaveProgressStarted`   | -                               | Operation began             |
| `SaveProgressUpdate`    | `progress: double`              | Progress from 0.0 to 1.0    |
| `SaveProgressComplete`  | `uri: Uri`                      | Success with saved file URI |
| `SaveProgressError`     | `exception: FileSaverException` | Error occurred              |
| `SaveProgressCancelled` | -                               | User cancelled operation    |

## Exception Reference

| Exception                     | Description                             | Error Code               |
|-------------------------------|-----------------------------------------|--------------------------|
| `PermissionDeniedException`   | Storage access denied                   | `PERMISSION_DENIED`      |
| `FileExistsException`         | File exists with `fail` strategy        | `FILE_EXISTS`            |
| `StorageFullException`        | Insufficient device storage             | `STORAGE_FULL`           |
| `InvalidInputException`       | Empty bytes or invalid input            | `INVALID_INPUT`          |
| `FileIOException`             | File system error                       | `FILE_IO_ERROR`          |
| `UnsupportedFormatException`  | Format not supported on platform        | `UNSUPPORTED_FORMAT`     |
| `SourceFileNotFoundException` | Source file not found (saveFile)        | `FILE_NOT_FOUND`         |
| `ICloudDownloadException`     | iCloud download failed (iOS)            | `ICLOUD_DOWNLOAD_FAILED` |
| `NetworkException`            | Network error occurred during download. | `NETWORK_ERROR`          |
| `CancelledException`          | Operation cancelled by user             | `CANCELLED`              |
| `PlatformException`           | Generic platform error                  | `PLATFORM_ERROR`         |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Future Features

* ~~File Input Methods~~
* ~~Save from Network URL~~
* ~~User-Selected Location Android (SAF), iOS (Document Picker)~~
* Custom Path Support
* ~~Progress Tracking~~
* ~~Cancellation Support~~
* ~~Save from File Path~~
* MacOS Support
* Windows Support
* Web Support

## License

MIT License - see [LICENSE](LICENSE) file for details.
