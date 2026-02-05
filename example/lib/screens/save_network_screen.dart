import 'dart:async';

import 'package:file_saver_ffi/file_saver_ffi.dart';
import 'package:flutter/material.dart';

import '../core/core.dart';
import 'save_multi_network_screen.dart';

class SaveNetworkScreen extends StatefulWidget {
  const SaveNetworkScreen({super.key});

  @override
  State<SaveNetworkScreen> createState() => _SaveNetworkScreenState();
}

class _SaveNetworkScreenState extends State<SaveNetworkScreen>
    with MediaSaverStateMixin {
  MediaCategory _selectedCategory = MediaCategory.image;
  bool _useStreamApi = false;
  bool _isSaving = false;

  StreamSubscription<SaveProgress>? _saveSubscription;

  NetworkDemoConfig get _config =>
      NetworkDemoConfig.forCategory(_selectedCategory);

  @override
  void dispose() {
    _saveSubscription?.cancel();
    super.dispose();
  }

  void _onCategoryChanged(MediaCategory category) {
    if (isLoading) return;
    if (category == MediaCategory.document) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SaveMultiNetworkScreen()));
      return; // Exit the method to avoid changing state
    }

    final config = NetworkDemoConfig.forCategory(category);
    setState(() {
      _selectedCategory = category;
      _useStreamApi = config.defaultUseStreamApi;
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

  Future<void> _saveFromNetwork() async {
    final config = _config;
    resetState();

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

      final fileName =
          '${config.fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}';

      setState(() => _isSaving = true);

      if (_useStreamApi) {
        await _saveWithStreamApi(fileName, config);
      } else {
        await _saveWithAsyncApi(fileName, config);
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
    String fileName,
    NetworkDemoConfig config,
  ) async {
    await runSaveCatching(
      () => FileSaver.instance.saveAsync(
        input: SaveInput.network(url: config.downloadUrl),
        fileName: fileName,
        fileType: config.fileType,
        saveLocation: config.saveLocation,
        onProgress: (value) {
          setState(() => progress = value * 100);
        },
      ),
    );
  }

  Future<void> _saveWithStreamApi(
    String fileName,
    NetworkDemoConfig config,
  ) async {
    final stream = FileSaver.instance.save(
      input: SaveInput.network(url: config.downloadUrl),
      fileName: fileName,
      fileType: config.fileType,
      saveLocation: config.saveLocation,
      subDir: config.subDir,
      conflictResolution: ConflictResolution.autoRename,
    );

    _saveSubscription = stream.listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case SaveProgressStarted():
            break;
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
                '${config.description}\nUses: ${_useStreamApi ? "saveNetwork (Stream)" : "saveNetworkAsync (Async)"}',
            url: config.downloadUrl,
          ),
          const SizedBox(height: 16),
          DownloadButton(
            isLoading: isLoading,
            onPressed: _saveFromNetwork,
            label: 'Download & Save ${config.category.label}',
          ),
          if (_isSaving && _useStreamApi) ...[
            const SizedBox(height: 8),
            CancelButton(onPressed: _cancelSave),
          ],
          if (isLoading && progress > 0) ProgressSection(progress: progress),
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
}
