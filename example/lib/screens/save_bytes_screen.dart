import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_saver_ffi/file_saver_ffi.dart';
import 'package:flutter/material.dart';

import '../core/core.dart';

class SaveBytesScreen extends StatefulWidget {
  const SaveBytesScreen({super.key});

  @override
  State<SaveBytesScreen> createState() => _SaveBytesScreenState();
}

class _SaveBytesScreenState extends State<SaveBytesScreen>
    with MediaSaverStateMixin {
  MediaCategory _selectedCategory = MediaCategory.image;
  bool _useStreamApi = false;
  bool _isSaving = false;

  Uint8List? _downloadedBytes;
  StreamSubscription<SaveProgress>? _saveSubscription;

  BytesDemoConfig get _config => BytesDemoConfig.forCategory(_selectedCategory);

  @override
  void dispose() {
    _saveSubscription?.cancel();
    super.dispose();
  }

  void _onCategoryChanged(MediaCategory category) {
    if (isLoading) return;
    final config = BytesDemoConfig.forCategory(category);
    setState(() {
      _selectedCategory = category;
      _useStreamApi = config.defaultUseStreamApi;
      _downloadedBytes = null;
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

  Future<void> _downloadAndSave() async {
    final config = _config;
    resetState();
    _downloadedBytes = null;

    try {
      final hasPermission =
          config.category == MediaCategory.document ||
              config.category == MediaCategory.audio
          ? await isGrantedPermissionWriteExternalStorage()
          : await isGrantedPermissionWritePhotos();

      if (!hasPermission) {
        showError('Permission denied');
        finishLoading();
        return;
      }

      if (config.category == MediaCategory.video ||
          config.category == MediaCategory.audio) {
        if (mounted) {
          showAppSnackBar(
            context,
            'Downloading ${config.category.label.toLowerCase()}... This may take a while',
            isSuccess: true,
          );
        }
      }

      final bytes = await downloadFromUrl(config.downloadUrl);

      setState(() {
        _downloadedBytes = bytes;
        mediaSize = bytes.length;
      });

      final fileName =
          '${config.fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}';

      setState(() => _isSaving = true);

      if (_useStreamApi) {
        await _saveWithStreamApi(bytes, fileName, config);
      } else {
        await _saveWithAsyncApi(bytes, fileName, config);
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

  Future<void> _saveWithAsyncApi(
    Uint8List bytes,
    String fileName,
    BytesDemoConfig config,
  ) async {
    await runSaveCatching(
      () => FileSaver.instance.saveAsync(
        input: SaveInput.bytes(bytes),
        fileName: fileName,
        fileType: config.fileType,
        saveLocation: config.getSaveLocation(),
        subDir: 'FileSaverFFI Demo',
        onProgress: (value) {
          setState(() => progress = value);
        },
      ),
    );
  }

  Future<void> _saveWithStreamApi(
    Uint8List bytes,
    String fileName,
    BytesDemoConfig config,
  ) async {
    final stream = FileSaver.instance.save(
      input: SaveInput.bytes(bytes),
      fileName: fileName,
      fileType: config.fileType,
      saveLocation: config.getSaveLocation(),
      subDir: Platform.isIOS && config.category == MediaCategory.document
          ? 'PDF'
          : 'FileSaverFFI Demo',
      conflictResolution: ConflictResolution.autoRename,
    );

    _saveSubscription = stream.listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case SaveProgressStarted():
            break;
          case SaveProgressUpdate(:final progress):
            setState(() => this.progress = progress);
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
            categories: MediaCategory.values
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
          InfoCard(
            title: config.title,
            description:
                '${config.description}\nUses: ${_useStreamApi ? "saveBytes (Stream)" : "saveBytesAsync (Async)"}',
            url: config.downloadUrl,
          ),
          const SizedBox(height: 16),
          DownloadButton(
            isLoading: isLoading,
            onPressed: _downloadAndSave,
            label: 'Download & Save ${config.category.label}',
          ),
          if (_isSaving && _useStreamApi) ...[
            const SizedBox(height: 8),
            CancelButton(onPressed: _cancelSave),
          ],
          if (isLoading && progress > 0) ProgressSection(progress: progress),
          if (_downloadedBytes != null &&
              _selectedCategory == MediaCategory.image) ...[
            const SizedBox(height: 24),
            _buildImagePreview(context),
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

  Widget _buildImagePreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            _downloadedBytes!,
            fit: BoxFit.cover,
            height: 300,
            width: double.infinity,
          ),
        ),
      ],
    );
  }
}
