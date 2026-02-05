import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart' hide FileType;
import 'package:file_saver_ffi/file_saver_ffi.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/core.dart';

class SaveFileScreen extends StatefulWidget {
  const SaveFileScreen({super.key});

  @override
  State<SaveFileScreen> createState() => _SaveFileScreenState();
}

class _SaveFileScreenState extends State<SaveFileScreen>
    with MediaSaverStateMixin {
  final ImagePicker _imagePicker = ImagePicker();

  MediaCategory _selectedCategory = MediaCategory.image;
  bool _useStreamApi = false;
  bool _isSaving = false;

  String? _pickedFilePath;
  String? _pickedFileName;
  StreamSubscription<SaveProgress>? _saveSubscription;

  FileDemoConfig get _config => FileDemoConfig.forCategory(_selectedCategory);

  // Available categories for file picker (no audio in image_picker)
  List<MediaCategory> get _availableCategories => [
    MediaCategory.image,
    MediaCategory.video,
    MediaCategory.document,
  ];

  @override
  void dispose() {
    _saveSubscription?.cancel();
    super.dispose();
  }

  void _onCategoryChanged(MediaCategory category) {
    if (isLoading) return;
    final config = FileDemoConfig.forCategory(category);
    setState(() {
      _selectedCategory = category;
      _useStreamApi = config.defaultUseStreamApi;
      _pickedFilePath = null;
      _pickedFileName = null;
      savedFilePath = null;
      mediaSize = 0;
    });
  }

  void _cancelSave() {
    _saveSubscription?.cancel();
    _saveSubscription = null;
    setState(() {
      isLoading = false;
      _isSaving = false;
      progress = 0;
    });
    showAppSnackBar(context, 'Operation cancelled', isSuccess: false);
  }

  Future<void> _pickAndSave() async {
    resetState();
    _pickedFilePath = null;
    _pickedFileName = null;

    try {
      final pickedPath = await _pickFile();

      if (pickedPath == null) {
        finishLoading();
        return;
      }

      final hasPermission = _selectedCategory == MediaCategory.document
          ? await isGrantedPermissionWriteExternalStorage()
          : await isGrantedPermissionWritePhotos();

      if (!hasPermission) {
        showError('Permission denied');
        finishLoading();
        return;
      }

      final file = File(pickedPath);
      final fileSize = await file.length();

      setState(() {
        _pickedFilePath = pickedPath;
        _pickedFileName = pickedPath.split('/').last;
        mediaSize = fileSize;
      });

      final fileName =
          'saved_${_selectedCategory.name}_${DateTime.now().millisecondsSinceEpoch}';
      final fileType = _getFileType(pickedPath);
      final saveLocation = _getSaveLocation();

      setState(() => _isSaving = true);

      if (_useStreamApi) {
        await _saveWithStreamApi(pickedPath, fileName, fileType, saveLocation);
      } else {
        await _saveWithAsyncApi(pickedPath, fileName, fileType, saveLocation);
      }
    } catch (e) {
      showError(e);
    } finally {
      if (_saveSubscription == null) {
        setState(() => _isSaving = false);
        finishLoading();
      }
    }
  }

  Future<String?> _pickFile() async {
    switch (_selectedCategory) {
      case MediaCategory.image:
        final image = await _imagePicker.pickImage(source: ImageSource.gallery);
        return image?.path;
      case MediaCategory.video:
        final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
        return video?.path;
      case MediaCategory.audio:
      case MediaCategory.document:
        final result = await FilePicker.platform.pickFiles();
        return result?.files.first.path;
    }
  }

  FileType _getFileType(String path) {
    return switch (_selectedCategory) {
      MediaCategory.image => imageTypeFromPath(path),
      MediaCategory.video => videoTypeFromPath(path),
      MediaCategory.audio || MediaCategory.document => fileTypeFromPath(path),
    };
  }

  SaveLocation? _getSaveLocation() {
    if (Platform.isAndroid) {
      return switch (_selectedCategory) {
        MediaCategory.image => AndroidSaveLocation.pictures,
        MediaCategory.video => AndroidSaveLocation.movies,
        MediaCategory.audio => AndroidSaveLocation.music,
        MediaCategory.document => AndroidSaveLocation.downloads,
      };
    } else if (Platform.isIOS) {
      return switch (_selectedCategory) {
        MediaCategory.image || MediaCategory.video => IosSaveLocation.documents,
        MediaCategory.audio ||
        MediaCategory.document => IosSaveLocation.documents,
      };
    }
    return null;
  }

  Future<void> _saveWithAsyncApi(
    String filePath,
    String fileName,
    FileType fileType,
    SaveLocation? saveLocation,
  ) async {
    await runSaveCatching(
      () => FileSaver.instance.saveAsync(
        input: SaveInput.file(filePath),
        fileName: fileName,
        fileType: fileType,
        saveLocation: saveLocation,
        subDir: _config.subDir,
        onProgress: (value) {
          setState(() => progress = value * 100);
        },
      ),
    );
  }

  Future<void> _saveWithStreamApi(
    String filePath,
    String fileName,
    FileType fileType,
    SaveLocation? saveLocation,
  ) async {
    final stream = FileSaver.instance.save(
      input: SaveInput.file(filePath),
      fileName: fileName,
      fileType: fileType,
      saveLocation: saveLocation,
      subDir: _config.subDir,
    );

    _saveSubscription = stream.listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case SaveProgressStarted():
            debugPrint('Save started');
          case SaveProgressUpdate(:final progress):
            setState(() => this.progress = progress * 100);
          case SaveProgressComplete(:final uri):
            setState(() {
              savedFilePath = uri.toString();
              isLoading = false;
              _isSaving = false;
            });
            showAppSnackBar(
              context,
              'Saved successfully!\nURI: $uri',
              isSuccess: true,
            );
          case SaveProgressError(:final exception):
            setState(() {
              isLoading = false;
              _isSaving = false;
            });
            showAppSnackBar(
              context,
              'Save failed: ${exception.message}',
              isSuccess: false,
            );
          case SaveProgressCancelled():
            setState(() {
              isLoading = false;
              _isSaving = false;
              progress = 0;
            });
            showAppSnackBar(context, 'Save cancelled', isSuccess: false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          _isSaving = false;
        });
        showError(error);
      },
      onDone: () => _saveSubscription = null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MediaCategorySelector(
            selected: _selectedCategory,
            categories: _availableCategories
                .map((c) => (value: c, label: c.label, icon: c.icon))
                .toList(),
            onChanged: (c) => _onCategoryChanged(c as MediaCategory),
            enabled: !isLoading,
          ),
          const SizedBox(height: 16),
          ApiModeSelector(
            useStreamApi: _useStreamApi,
            onChanged: (v) => setState(() => _useStreamApi = v),
            enabled: !isLoading,
          ),
          const SizedBox(height: 16),
          SimpleInfoCard(
            title: config.title,
            description: config.description,
            subtitle:
                'Uses ${_selectedCategory == MediaCategory.document ? "file_picker" : "image_picker"} to select, then ${_useStreamApi ? "Stream" : "Async"} API to save.',
          ),
          const SizedBox(height: 16),
          DownloadButton(
            isLoading: isLoading,
            onPressed: _pickAndSave,
            label: 'Pick & Save ${_selectedCategory.label}',
            loadingLabel: 'Saving...',
          ),
          if (_isSaving && _useStreamApi) ...[
            const SizedBox(height: 8),
            CancelButton(onPressed: _cancelSave),
          ],
          if (isLoading && progress > 0) ProgressSection(progress: progress),
          if (_pickedFilePath != null) ...[
            const SizedBox(height: 24),
            _buildPreview(context),
          ],
          if (mediaSize > 0) ...[
            const SizedBox(height: 16),
            FileSizeCard(sizeInBytes: mediaSize),
          ],
          if (savedFilePath != null) ...[
            const SizedBox(height: 16),
            SuccessCard(savedPath: savedFilePath!),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (_selectedCategory == MediaCategory.image && _pickedFilePath != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_pickedFilePath!),
              fit: BoxFit.cover,
              height: 300,
              width: double.infinity,
            ),
          ),
        ],
      );
    }

    // Generic file preview
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selected:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(_getCategoryIcon(), size: 48),
            title: Text(
              _pickedFileName ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _pickedFilePath ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon() {
    return switch (_selectedCategory) {
      MediaCategory.image => Icons.image,
      MediaCategory.video => Icons.video_file,
      MediaCategory.audio => Icons.audio_file,
      MediaCategory.document => Icons.insert_drive_file,
    };
  }
}
