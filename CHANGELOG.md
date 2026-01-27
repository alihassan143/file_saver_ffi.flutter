## 0.1.0

### Breaking Changes
- **`saveBytes()` now returns `Stream<SaveProgress>`** instead of `Future<Uri>`
  - Renamed `saveBytes` parameter from `bytes` to `fileBytes`.
  - Renamed `saveBytesAsync` parameter from `bytes` to `fileBytes`.

### Added
- **`saveFile()` method**: Save files from source path instead of bytes in memory
  - Stream-based API returning `Stream<SaveProgress>` for real-time progress tracking
  - Handles large files efficiently without loading entire file into RAM
  - Supports `file://` paths and picker results

- **`saveFileAsync()` method**: Convenience API returning `Future<Uri>` with optional `onProgress` callback
  ```dart
  final uri = await FileSaver.instance.saveFileAsync(
    filePath: '/path/to/source/video.mp4',
    fileName: 'my_video',
    fileType: VideoType.mp4,
    onProgress: (progress) => print('${(progress * 100).toInt()}%'),
  );
  ```

- **True Cancellation Support**: Cancel save operations mid-stream with proper cleanup
  - Call `subscription.cancel()` or break from `await for` loop to cancel
  - Native code stops I/O operations between chunks (1MB)
  - Partial files are automatically deleted on cancellation
  - `SaveProgressCancelled` event emitted on successful cancellation
  - Works for both `saveBytes()` and `saveFile()` streams
  ```dart
  // Example: Cancel with subscription
  final subscription = FileSaver.instance.saveBytes(...).listen((event) {
    if (event is SaveProgressCancelled) {
      print('Cancelled and cleaned up!');
    }
  });

  // Cancel when needed
  await subscription.cancel();

  // Example: Cancel with await for
  await for (final event in FileSaver.instance.saveBytes(...)) {
    if (shouldCancel) break;  // Triggers native cancellation
    // handle event...
  }
  ```

- **iOS iCloud download progress**: When saving files from iCloud Drive, progress is split into 2 phases:
  - Phase 1 (0% → 50%): iCloud download progress
  - Phase 2 (50% → 100%): Copy to destination progress

- **New exceptions**:
  - `FileNotFoundException`: Source file not found
  - `ICloudDownloadException`: iCloud download failed or timed out (iOS only)

### Changed
- **Simplified FormatValidator**: Removed codec/encoder validation on both platforms
  - iOS: Removed AVAssetWriter and ImageIO validation
  - Android: Removed MediaCodecList encoder checks
  - Now only validates MIME type category (image/video/audio)
  - Rationale: This library is a file saver, not a media player. Files are written as raw bytes without encoding/decoding. The developer is responsible for choosing appropriate formats.

### Fixed
- **iOS video filename**: Videos saved to Photos Library now preserve the specified filename instead of using UUID
- **iOS audio format crash**: Fixed crash when saving MP3 and other audio formats that AVAssetWriter doesn't support
- **Android audio format rejection**: Fixed rejection of audio formats not in MediaCodecList (AMR, OPUS, etc.)

## 0.0.5

### Breaking Changes
- **`saveBytes()` now returns `Stream<SaveProgress>`** instead of `Future<Uri>`
  - Enables real-time progress tracking during save operations
  - Use `saveBytesAsync()` for the previous `Future<Uri>` behavior

### Added
- **`SaveProgress` sealed class** for streaming progress events:
  - `SaveProgressStarted` - Operation started
  - `SaveProgressUpdate(double progress)` - Progress 0.0 to 1.0
  - `SaveProgressComplete(Uri uri)` - Success with file URI
  - `SaveProgressError(FileSaverException)` - Error occurred
  - `SaveProgressCancelled` - User cancelled
- **`saveBytesAsync()` method** - Convenience API returning `Future<Uri>` with optional `onProgress` callback
- **Real progress reporting for iOS** - Chunked file writes with progress callbacks (1MB chunks)

### Migration Guide
```dart
// Before (0.0.4)
final uri = await FileSaver.instance.saveBytes(...);

// After (0.0.5) - Option 1: Use saveBytesAsync (minimal change)
final uri = await FileSaver.instance.saveBytesAsync(...);

// After (0.0.5) - Option 2: Use saveBytesAsync with progress
final uri = await FileSaver.instance.saveBytesAsync(
  ...,
  onProgress: (progress) => print('${(progress * 100).toInt()}%'),
);

// After (0.0.5) - Option 3: Use saveBytes stream for full control
await for (final event in FileSaver.instance.saveBytes(...)) {
  switch (event) {
    case SaveProgressStarted(): showLoading();
    case SaveProgressUpdate(:final progress): updateUI(progress);
    case SaveProgressComplete(:final uri): handleSuccess(uri);
    case SaveProgressError(:final exception): handleError(exception);
    case SaveProgressCancelled(): handleCancel();
  }
}
```

## 0.0.4

### Added
- **SaveLocation Feature**: Explicit control over save locations with platform-specific enums
  - Android: `pictures`, `movies`, `music`, `downloads` (default), `dcim`
  - iOS: `photos` (Photos Library), `documents` (default, no permission)
  - Type-safe sealed class design with platform defaults

### Changed
- Added optional `saveLocation` parameter to `saveBytes()`
- Standardized parameter order: `saveLocation` now before `subDir`

### Breaking Changes
- **Default locations changed** for better UX:
  - Android: All files → Downloads (was type-based: Images→Pictures, Videos→Movies, etc.)
  - iOS: All files → Documents (was Images/Videos→Photos Library)
- **Migration**: Explicitly set `saveLocation` to maintain old behavior:
  ```dart
  saveLocation: Platform.isAndroid
    ? AndroidSaveLocation.pictures
    : [PlatformX]SaveLocation.photos
  ```

## 0.0.3

### Added
- **OVERWRITE Functionality**: Fully implemented overwrite conflict resolution
  - Android (Legacy): Delete existing file and save new one
  - Android 10+: Delete existing file via ContentResolver
  - iOS: Optimized with early return check
- **Platform Behavior Documentation**: Comprehensive guide for overwrite behavior
  - iOS Photos: Own files overwritten; other apps' files create duplicates
  - iOS Documents: Full overwrite capability (sandboxed per app)
  - Android 10+: Only detects/overwrites own files; other apps' files auto-renamed
  - Platform comparison table in README
- **iOS 14+ Dialog Prevention**: Added `PHPhotoLibraryPreventAutomaticLimitedAccessAlert` key
  - Prevents automatic "Select More Photos" prompt on iOS 14+
  - Provides better user experience with limited photos access
  - Documented in README with setup instructions

### Refactored
- **iOS Code Quality**: Extracted common logic from ImageSaver and VideoSaver
  - Moved `findOrCreateAlbum()` to BaseFileSaver extension
  - Moved `handlePhotosConflictResolution()` to BaseFileSaver extension
  - Removed 38 lines of duplicated code for better maintainability


## 0.0.2

* Refactor `FileSaverIos` to use NativeFinalizer + Arena for safer native resource management, more robust, and less prone to native memory leaks while maintaining performance.
* Make `FileSaverPlatform.instance` a true singleton
* Update document and README.md

## 0.0.1