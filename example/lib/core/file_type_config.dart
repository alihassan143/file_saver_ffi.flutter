import 'package:file_saver_ffi/file_saver_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Enum for selectable media types in the example app
enum MediaCategory {
  image('Image', Icons.image),
  video('Video', Icons.video_library),
  audio('Audio', Icons.audio_file),
  document('Document', Icons.description);

  const MediaCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

abstract class MediaConfig {
  const MediaConfig({
    required this.category,
    required this.saveLocation,
    this.subDir = "FileSaverFFI Demo",
    this.defaultUseStreamApi = false,
  });

  final MediaCategory category;
  final SaveLocation? saveLocation;
  final String? subDir;
  final bool defaultUseStreamApi;
}

/// Configuration for each media type for Save Bytes (download) demos
class SaveDemoConfig extends MediaConfig {
  const SaveDemoConfig({
    required super.category,
    required this.downloadUrl,
    required this.fileNamePrefix,
    required this.fileType,
    required super.saveLocation,
    super.defaultUseStreamApi,
    super.subDir,
  });

  final String downloadUrl;
  final String fileNamePrefix;
  final FileType fileType;

  static final image = SaveDemoConfig(
    category: MediaCategory.image,
    downloadUrl: 'https://picsum.photos/800/1200',
    fileNamePrefix: 'image',
    fileType: ImageType.jpg,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.pictures,
      TargetPlatform.iOS => IosSaveLocation.photos,
      TargetPlatform.macOS => MacosSaveLocation.downloads,
      _ => null,
    },
  );

  static final video = SaveDemoConfig(
    category: MediaCategory.video,
    downloadUrl: 'https://download.samplelib.com/mp4/sample-5s.mp4',
    fileNamePrefix: 'video',
    fileType: VideoType.mp4,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.movies,
      TargetPlatform.iOS => IosSaveLocation.photos,
      TargetPlatform.macOS => MacosSaveLocation.downloads,
      _ => null,
    },
    defaultUseStreamApi: true,
  );

  static final audio = SaveDemoConfig(
    category: MediaCategory.audio,
    downloadUrl:
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    fileNamePrefix: 'audio',
    fileType: AudioType.mp3,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.music,
      TargetPlatform.iOS => IosSaveLocation.documents,
      TargetPlatform.macOS => MacosSaveLocation.downloads,
      _ => null,
    },
    subDir: switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'Music',
      _ => 'FileSaverFFI Demo',
    },
    defaultUseStreamApi: true,
  );

  static final document = SaveDemoConfig(
    category: MediaCategory.document,
    downloadUrl:
        'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
    fileNamePrefix: 'document',
    fileType: const CustomFileType(ext: 'pdf', mimeType: 'application/pdf'),
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.downloads,
      TargetPlatform.iOS => IosSaveLocation.documents,
      TargetPlatform.macOS => MacosSaveLocation.documents,
      _ => null,
    },
    subDir: switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'Documents',
      _ => 'FileSaverFFI Demo',
    },
  );

  static SaveDemoConfig forCategory(MediaCategory category) {
    return switch (category) {
      MediaCategory.image => image,
      MediaCategory.video => video,
      MediaCategory.audio => audio,
      MediaCategory.document => document,
    };
  }
}

/// Configuration for each media type for Save Network (download) demos
class NetworkDemoConfig extends MediaConfig {
  const NetworkDemoConfig({
    required super.category,
    required this.downloadUrl,
    required this.fileNamePrefix,
    required this.fileType,
    required super.saveLocation,
    super.subDir,
    super.defaultUseStreamApi = false,
  });

  final String downloadUrl;
  final String fileNamePrefix;
  final FileType fileType;

  static final image = NetworkDemoConfig(
    category: MediaCategory.image,
    downloadUrl: 'https://picsum.photos/800/1200',
    fileNamePrefix: 'image',
    fileType: ImageType.jpg,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.pictures,
      TargetPlatform.iOS => IosSaveLocation.photos,
      TargetPlatform.macOS => MacosSaveLocation.downloads,
      _ => null,
    },
  );

  static final video = NetworkDemoConfig(
    category: MediaCategory.video,
    downloadUrl: 'https://download.samplelib.com/mp4/sample-30s.mp4',
    fileNamePrefix: 'video',
    fileType: VideoType.mp4,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.movies,
      TargetPlatform.iOS => IosSaveLocation.photos,
      TargetPlatform.macOS => MacosSaveLocation.downloads,
      _ => null,
    },
    defaultUseStreamApi: true,
  );

  static final audio = NetworkDemoConfig(
    category: MediaCategory.audio,
    downloadUrl: 'https://download.samplelib.com/mp3/sample-15s.mp3',
    fileNamePrefix: 'audio',
    fileType: AudioType.mp3,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.music,
      TargetPlatform.iOS => IosSaveLocation.documents,
      TargetPlatform.macOS => MacosSaveLocation.downloads,
      _ => null,
    },
    subDir: switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'Music',
      _ => 'FileSaverFFI Demo',
    },
    defaultUseStreamApi: true,
  );

  static final document = NetworkDemoConfig(
    category: MediaCategory.document,
    downloadUrl:
        'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
    fileNamePrefix: 'document',
    fileType: const CustomFileType(ext: 'pdf', mimeType: 'application/pdf'),
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.downloads,
      TargetPlatform.iOS => IosSaveLocation.documents,
      TargetPlatform.macOS => MacosSaveLocation.documents,
      _ => null,
    },
    subDir: switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'Documents',
      _ => 'FileSaverFFI Demo',
    },
    defaultUseStreamApi: true,
  );

  static NetworkDemoConfig forCategory(MediaCategory category) {
    return switch (category) {
      MediaCategory.image => image,
      MediaCategory.video => video,
      MediaCategory.audio => audio,
      MediaCategory.document => document,
    };
  }
}
