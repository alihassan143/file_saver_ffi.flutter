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
    required this.title,
    required this.description,
    required this.saveLocation,
    this.subDir = "FileSaverFFI Demo",
    this.defaultUseStreamApi = false,
  });

  final MediaCategory category;
  final String title;
  final String description;
  final SaveLocation? saveLocation;
  final String? subDir;
  final bool defaultUseStreamApi;
}

/// Configuration for each media type for Save Bytes (download) demos
class BytesDemoConfig extends MediaConfig {
  const BytesDemoConfig({
    required super.category,
    required super.title,
    required super.description,
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

  static final image = BytesDemoConfig(
    category: MediaCategory.image,
    title: 'Image Bytes Demo',
    description: 'Downloads a random image and saves to Photos library.',
    downloadUrl: 'https://picsum.photos/800/1200',
    fileNamePrefix: 'image',
    fileType: ImageType.jpg,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.pictures,
      TargetPlatform.iOS => IosSaveLocation.photos,
      _ => null,
    },
  );

  static final video = BytesDemoConfig(
    category: MediaCategory.video,
    title: 'Video Bytes Demo',
    description: 'Downloads a sample video and saves to Photos library.',
    downloadUrl: 'https://download.samplelib.com/mp4/sample-5s.mp4',
    fileNamePrefix: 'video',
    fileType: VideoType.mp4,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.movies,
      TargetPlatform.iOS => IosSaveLocation.photos,
      _ => null,
    },
    defaultUseStreamApi: true,
  );

  static final audio = BytesDemoConfig(
    category: MediaCategory.audio,
    title: 'Audio Bytes Demo',
    description: 'Downloads a sample audio file and saves to Music folder.',
    downloadUrl:
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    fileNamePrefix: 'audio',
    fileType: AudioType.mp3,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.music,
      TargetPlatform.iOS => IosSaveLocation.documents,
      _ => null,
    },
    subDir: switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'Music',
      _ => 'FileSaverFFI Demo',
    },
    defaultUseStreamApi: true,
  );

  static final document = BytesDemoConfig(
    category: MediaCategory.document,
    title: 'Document Bytes Demo',
    description: 'Downloads a PDF file and saves to Downloads/Documents.',
    downloadUrl:
        'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
    fileNamePrefix: 'document',
    fileType: const CustomFileType(ext: 'pdf', mimeType: 'application/pdf'),
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.downloads,
      TargetPlatform.iOS => IosSaveLocation.documents,
      _ => null,
    },
    subDir: switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'Documents',
      _ => 'FileSaverFFI Demo',
    },
  );

  static BytesDemoConfig forCategory(MediaCategory category) {
    return switch (category) {
      MediaCategory.image => image,
      MediaCategory.video => video,
      MediaCategory.audio => audio,
      MediaCategory.document => document,
    };
  }
}

/// Configuration for Save File (file picker) demos
class FileDemoConfig extends MediaConfig {
  const FileDemoConfig({
    required super.category,
    required super.title,
    required super.description,
    required super.saveLocation,
    super.subDir,
    super.defaultUseStreamApi = false,
  });

  static final image = FileDemoConfig(
    category: MediaCategory.image,
    title: 'Image File Demo',
    description: 'Pick image from gallery and save.',
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.pictures,
      TargetPlatform.iOS => IosSaveLocation.documents,
      _ => null,
    },
    subDir: switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'Images',
      _ => 'FileSaverFFI Demo',
    },
  );

  static final video = FileDemoConfig(
    category: MediaCategory.video,
    title: 'Video File Demo',
    description: 'Pick video from gallery and save.',
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.movies,
      TargetPlatform.iOS => IosSaveLocation.documents,
      _ => null,
    },
    subDir: switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'Videos',
      _ => 'FileSaverFFI Demo',
    },
  );

  static final document = FileDemoConfig(
    category: MediaCategory.document,
    title: 'Document File Demo',
    description: 'Pick any file and save with cancellation support.',
    defaultUseStreamApi: true,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.downloads,
      TargetPlatform.iOS => IosSaveLocation.documents,
      _ => null,
    },
    subDir: switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'Documents',
      _ => 'FileSaverFFI Demo',
    },
  );

  static FileDemoConfig forCategory(MediaCategory category) {
    return switch (category) {
      MediaCategory.image => image,
      MediaCategory.video => video,
      MediaCategory.audio => document, // Use document config for audio picker
      MediaCategory.document => document,
    };
  }
}

/// Configuration for each media type for Save Network (download) demos
class NetworkDemoConfig extends MediaConfig {
  const NetworkDemoConfig({
    required super.category,
    required super.title,
    required super.description,
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
    title: 'Image Network Demo',
    description: 'Downloads a random image and saves to Photos library.',
    downloadUrl: 'https://picsum.photos/800/1200',
    fileNamePrefix: 'image',
    fileType: ImageType.jpg,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.pictures,
      TargetPlatform.iOS => IosSaveLocation.photos,
      _ => null,
    },
  );

  static final video = NetworkDemoConfig(
    category: MediaCategory.video,
    title: 'Video Network Demo',
    description: 'Downloads a sample video and saves to Photos library.',
    downloadUrl: 'https://download.samplelib.com/mp4/sample-30s.mp4',
    fileNamePrefix: 'video',
    fileType: VideoType.mp4,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.movies,
      TargetPlatform.iOS => IosSaveLocation.photos,
      _ => null,
    },
    defaultUseStreamApi: true,
  );

  static final audio = NetworkDemoConfig(
    category: MediaCategory.audio,
    title: 'Audio Network Demo',
    description: 'Downloads a sample audio file and saves to Music folder.',
    downloadUrl: 'https://download.samplelib.com/mp3/sample-15s.mp3',
    fileNamePrefix: 'audio',
    fileType: AudioType.mp3,
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.music,
      TargetPlatform.iOS => IosSaveLocation.documents,
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
    title: 'Document Network Demo',
    description: 'Downloads a PDF file and saves to Downloads/Documents.',
    downloadUrl:
        'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
    fileNamePrefix: 'document',
    fileType: const CustomFileType(ext: 'pdf', mimeType: 'application/pdf'),
    saveLocation: switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSaveLocation.downloads,
      TargetPlatform.iOS => IosSaveLocation.documents,
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
