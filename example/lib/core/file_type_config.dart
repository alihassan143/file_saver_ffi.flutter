import 'dart:io';

import 'package:file_saver_ffi/file_saver_ffi.dart';
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

/// Configuration for each media type for Save Bytes (download) demos
class BytesDemoConfig {
  const BytesDemoConfig({
    required this.category,
    required this.title,
    required this.description,
    required this.downloadUrl,
    required this.fileNamePrefix,
    required this.fileType,
    required this.getSaveLocation,
    this.defaultUseStreamApi = false,
  });

  final MediaCategory category;
  final String title;
  final String description;
  final String downloadUrl;
  final String fileNamePrefix;
  final FileType fileType;
  final SaveLocation? Function() getSaveLocation;
  final bool defaultUseStreamApi;

  static final image = BytesDemoConfig(
    category: MediaCategory.image,
    title: 'Image Bytes Demo',
    description: 'Downloads a random image and saves to Photos library.',
    downloadUrl: 'https://picsum.photos/800/1200',
    fileNamePrefix: 'image',
    fileType: ImageType.jpg,
    getSaveLocation: () => Platform.isAndroid
        ? AndroidSaveLocation.pictures
        : Platform.isIOS
        ? IosSaveLocation.photos
        : null,
  );

  static final video = BytesDemoConfig(
    category: MediaCategory.video,
    title: 'Video Bytes Demo',
    description: 'Downloads a sample video and saves to Photos library.',
    downloadUrl: 'https://download.samplelib.com/mp4/sample-5s.mp4',
    fileNamePrefix: 'video',
    fileType: VideoType.mp4,
    getSaveLocation: () => Platform.isAndroid
        ? AndroidSaveLocation.movies
        : Platform.isIOS
        ? IosSaveLocation.photos
        : null,
  );

  static final audio = BytesDemoConfig(
    category: MediaCategory.audio,
    title: 'Audio Bytes Demo',
    description: 'Downloads a sample audio file and saves to Music folder.',
    downloadUrl:
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    fileNamePrefix: 'audio',
    fileType: AudioType.mp3,
    getSaveLocation: () => Platform.isAndroid
        ? AndroidSaveLocation.music
        : Platform.isIOS
        ? IosSaveLocation.documents
        : null,
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
    getSaveLocation: () => Platform.isAndroid
        ? AndroidSaveLocation.downloads
        : Platform.isIOS
        ? IosSaveLocation.documents
        : null,
    defaultUseStreamApi: true,
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
class FileDemoConfig {
  const FileDemoConfig({
    required this.category,
    required this.title,
    required this.description,
    this.defaultUseStreamApi = false,
  });

  final MediaCategory category;
  final String title;
  final String description;
  final bool defaultUseStreamApi;

  static final image = FileDemoConfig(
    category: MediaCategory.image,
    title: 'Image File Demo',
    description: 'Pick image from gallery and save.',
  );

  static final video = FileDemoConfig(
    category: MediaCategory.video,
    title: 'Video File Demo',
    description: 'Pick video from gallery and save.',
  );

  static final document = FileDemoConfig(
    category: MediaCategory.document,
    title: 'Document File Demo',
    description: 'Pick any file and save with cancellation support.',
    defaultUseStreamApi: true,
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
