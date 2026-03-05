// Stubs for all non-web platform classes, used when compiling for web.
import 'dart:typed_data';

import '../models/conflict_resolution.dart';
import '../models/file_type.dart';
import '../models/save_input.dart';
import '../models/locations/save_location.dart';
import '../models/save_progress.dart';
import '../platform_interface/file_saver_platform.dart';

class FileSaverAndroid extends _FileSaverStub {
  FileSaverAndroid() : super('FileSaverAndroid');

  static void registerWith() => FileSaverPlatform.instance = FileSaverAndroid();
}

class FileSaverDarwin extends _FileSaverStub {
  FileSaverDarwin() : super('FileSaverDarwin');

  static void registerWith() => FileSaverPlatform.instance = FileSaverDarwin();
}

class FileSaverLinux extends _FileSaverStub {
  FileSaverLinux() : super('FileSaverLinux');

  static void registerWith() => FileSaverPlatform.instance = FileSaverLinux();
}

class FileSaverWindows extends _FileSaverStub {
  FileSaverWindows() : super('FileSaverWindows');

  static void registerWith() => FileSaverPlatform.instance = FileSaverWindows();
}

class _FileSaverStub extends FileSaverPlatform {
  _FileSaverStub(this.className);

  final String className;

  @override
  Stream<SaveProgress> saveBytes({
    required Uint8List fileBytes,
    required FileType fileType,
    required String fileName,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) => throw UnsupportedError('$className is not supported on this platform.');

  @override
  Stream<SaveProgress> saveFile({
    required String filePath,
    required String fileName,
    required FileType fileType,
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) => throw UnsupportedError('$className is not supported on this platform.');

  @override
  Stream<SaveProgress> saveNetwork({
    required String url,
    required String fileName,
    required FileType fileType,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 60),
    SaveLocation? saveLocation,
    String? subDir,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) => throw UnsupportedError('$className is not supported on this platform.');

  @override
  Stream<SaveProgress> saveAs({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    required UserSelectedLocation saveLocation,
    ConflictResolution conflictResolution = ConflictResolution.autoRename,
  }) => throw UnsupportedError('$className is not supported on this platform.');
}
