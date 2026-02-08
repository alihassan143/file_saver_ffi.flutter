import 'dart:async';
import 'dart:io';

import 'package:file_saver_ffi/file_saver_ffi.dart';
import 'package:flutter/material.dart';

import '../core/core.dart';
import '../helper/perm_helper.dart';

class SaveScreen extends StatefulWidget {
  const SaveScreen({super.key});

  @override
  State<SaveScreen> createState() => _SaveScreenState();
}

class _SaveScreenState extends State<SaveScreen> with DemoSaveScreenMixin {
  MediaCategory _selectedCategory = MediaCategory.image;
  bool _useStreamApi = false;
  bool _isSaving = false;
  DemoInputSource _inputSource = DemoInputSource.network;

  String? _pickedFilePath;

  StreamSubscription<SaveProgress>? _saveSubscription;

  @override
  MediaCategory get demoSelectedCategory => _selectedCategory;

  @override
  set demoSelectedCategory(MediaCategory value) => _selectedCategory = value;

  @override
  bool get demoUseStreamApi => _useStreamApi;
  @override
  set demoUseStreamApi(bool value) => _useStreamApi = value;

  @override
  bool get demoIsSaving => _isSaving;
  @override
  set demoIsSaving(bool value) => _isSaving = value;

  @override
  DemoInputSource get demoInputSource => _inputSource;
  @override
  set demoInputSource(DemoInputSource value) => _inputSource = value;

  @override
  String? get demoPickedFilePath => _pickedFilePath;
  @override
  set demoPickedFilePath(String? value) => _pickedFilePath = value;

  @override
  StreamSubscription<SaveProgress>? get demoSaveSubscription =>
      _saveSubscription;
  @override
  set demoSaveSubscription(StreamSubscription<SaveProgress>? value) =>
      _saveSubscription = value;

  @override
  void dispose() {
    _saveSubscription?.cancel();
    super.dispose();
  }

  void _onCategoryChanged(MediaCategory category) {
    if (isLoading) return;
    setState(() {
      _selectedCategory = category;
      _useStreamApi = demoConfig.defaultUseStreamApi;
      _pickedFilePath = null;
      savedFilePath = null;
      mediaSize = 0;
      progress = 0;
    });
  }

  void _onInputSourceChanged(DemoInputSource source) {
    if (isLoading) return;
    setState(() {
      _inputSource = source;
      _pickedFilePath = null;
      savedFilePath = null;
      mediaSize = 0;
      progress = 0;
    });
  }

  void _cancelSave() {
    cancelDemoSave(message: 'Operation cancelled', isSuccess: false);
  }

  Future<bool> _ensurePermissionForCategory() async {
    return demoSelectedCategory == MediaCategory.document ||
            demoSelectedCategory == MediaCategory.audio
        ? PermHelper.isGrantedPermWriteExternalStorage()
        : PermHelper.isGrantedPermWritePhotos();
  }

  SaveLocation? _resolveSaveLocation() {
    if (Platform.isAndroid) {
      return switch (demoSelectedCategory) {
        MediaCategory.image => AndroidSaveLocation.pictures,
        MediaCategory.video => AndroidSaveLocation.movies,
        MediaCategory.audio => AndroidSaveLocation.music,
        MediaCategory.document => AndroidSaveLocation.downloads,
      };
    }

    if (Platform.isIOS) {
      return switch (demoSelectedCategory) {
        MediaCategory.image || MediaCategory.video => IosSaveLocation.photos,
        MediaCategory.audio ||
        MediaCategory.document => IosSaveLocation.documents,
      };
    }

    return null;
  }

  Future<void> _runSave() async {
    resetState();
    savedFilePath = null;

    try {
      final hasPermission = await _ensurePermissionForCategory();
      if (!hasPermission) {
        showError('Permission denied');
        finishLoading();
        return;
      }

      final resolved = await resolveDemoSaveParams();

      setState(() => _isSaving = true);

      final saveLocation = _resolveSaveLocation();

      if (_useStreamApi) {
        await _saveWithStreamApi(
          input: resolved.input,
          fileType: resolved.fileType,
          fileName: resolved.fileName,
          saveLocation: saveLocation,
        );
      } else {
        await _saveWithAsyncApi(
          input: resolved.input,
          fileType: resolved.fileType,
          fileName: resolved.fileName,
          saveLocation: saveLocation,
        );
      }
    } on CancelledException {
      showAppSnackBar(context, 'Operation cancelled', isSuccess: false);
    } catch (e) {
      showError(e);
    } finally {
      if (_saveSubscription == null) {
        setState(() => _isSaving = false);
        finishLoading();
      }
    }
  }

  Future<void> _saveWithAsyncApi({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    required SaveLocation? saveLocation,
  }) async {
    await runSaveCatching(
      () => FileSaver.instance.saveAsync(
        input: input,
        fileType: fileType,
        fileName: fileName,
        saveLocation: saveLocation,
        subDir: demoConfig.subDir,
        conflictResolution: ConflictResolution.autoRename,
        onProgress: (p) => setState(() => progress = p * 100),
      ),
    );
  }

  Future<void> _saveWithStreamApi({
    required SaveInput input,
    required FileType fileType,
    required String fileName,
    required SaveLocation? saveLocation,
  }) async {
    final stream = FileSaver.instance.save(
      input: input,
      fileType: fileType,
      fileName: fileName,
      saveLocation: saveLocation,
      subDir: demoConfig.subDir,
      conflictResolution: ConflictResolution.autoRename,
    );
    listenDemoSaveStream(stream, cancelledMessage: 'Operation cancelled');
  }

  @override
  Widget build(BuildContext context) {
    final infoUrlLabel = _inputSource == DemoInputSource.file ? 'Path' : 'URL';
    final infoValue = _inputSource == DemoInputSource.file
        ? (_pickedFilePath ?? 'No file selected')
        : demoConfig.downloadUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Save Demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InputSourceSelector(
              value: _inputSource,
              enabled: !isLoading,
              onChanged: _onInputSourceChanged,
            ),
            MediaCategorySelector(
              selected: _selectedCategory,
              categories: MediaCategory.values
                  .map((c) => (value: c, label: c.label, icon: c.icon))
                  .toList(),
              onChanged: (c) => _onCategoryChanged(c as MediaCategory),
              enabled: !isLoading,
            ),
            ApiModeSelector(
              useStreamApi: _useStreamApi,
              onChanged: (v) => setState(() => _useStreamApi = v),
              enabled: !isLoading,
            ),
            InfoCard(
              description:
                  'Save to standard locations (Photos/Downloads/etc.) \n'
                  'Uses: ${_useStreamApi ? "save (Stream)" : "saveAsync (Async)"}\n'
                  'Input: ${_inputSource.name}',
              url: infoValue,
              urlLabel: infoUrlLabel,
            ),
            const SizedBox(height: 12),
            DownloadButton(
              isLoading: isLoading,
              onPressed: _runSave,
              label: 'Save ${_selectedCategory.label}',
              loadingLabel: 'Saving...',
            ),
            if (_isSaving && _useStreamApi) ...[
              const SizedBox(height: 8),
              CancelButton(onPressed: _cancelSave),
            ],
            if (isLoading && progress > 0) ProgressSection(progress: progress),
            if (mediaSize > 0) FileSizeCard(sizeInBytes: mediaSize),
            if (savedFilePath != null) SuccessCard(savedPath: savedFilePath!),
          ],
        ),
      ),
    );
  }
}
