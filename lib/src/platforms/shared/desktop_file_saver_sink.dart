import 'dart:async';
import 'dart:io';

import '../../exceptions/file_saver_exceptions.dart';
import '../../models/file_saver_sink.dart';

/// Desktop (Windows / Linux) implementation of [FileSaverSink].
///
/// Wraps [dart:io]'s [IOSink] with progress/bytesWritten tracking.
/// Deletes the partial file on [cancel].
class DesktopFileSaverSink implements FileSaverSink {
  DesktopFileSaverSink({
    required IOSink sink,
    required File file,
    required int? totalSize,
  })  : _sink = sink,
        _file = file,
        _totalSize = totalSize;

  final IOSink _sink;
  final File _file;
  final int? _totalSize;

  int _bytesWritten = 0;
  bool _isClosed = false;
  bool _isAddingStream = false;

  final _progressController = StreamController<double>.broadcast();
  final _bytesController = StreamController<int>.broadcast();
  final _resultCompleter = Completer<Uri>();
  final _doneCompleter = Completer<dynamic>();

  // ─────────────────────────────────────────────────────────────────────────
  // FileSaverSink interface
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Stream<double> get progress => _progressController.stream;

  @override
  Stream<int> get bytesWritten => _bytesController.stream;

  @override
  Future<Uri> get result => _resultCompleter.future;

  @override
  Future get done => _doneCompleter.future;

  // ─────────────────────────────────────────────────────────────────────────
  // StreamSink<List<int>>
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void add(List<int> data) {
    if (_isClosed) throw StateError('Cannot add to a closed FileSaverSink');
    _sink.add(data);
    _bytesWritten += data.length;
    _bytesController.add(_bytesWritten);
    if (_totalSize != null && _totalSize > 0) {
      _progressController.add(_bytesWritten / _totalSize);
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.completeError(error, stackTrace);
    }
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    if (_isAddingStream) throw StateError('Already adding a stream');
    _isAddingStream = true;
    try {
      await for (final chunk in stream) {
        if (_isClosed) break;
        add(chunk);
      }
    } finally {
      _isAddingStream = false;
    }
  }

  @override
  Future<void> flush() => _sink.flush();

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    while (_isAddingStream) {
      await Future.microtask(() {});
    }

    await _doClose();
  }

  Future<void> _doClose() async {
    try {
      await _sink.flush();
      await _sink.close();
      _progressController.close().ignore();
      _bytesController.close().ignore();
      final uri = Uri.file(_file.path);
      if (!_resultCompleter.isCompleted) _resultCompleter.complete(uri);
      if (!_doneCompleter.isCompleted) _doneCompleter.complete(uri);
    } catch (e, st) {
      _progressController.close().ignore();
      _bytesController.close().ignore();
      if (!_resultCompleter.isCompleted) _resultCompleter.completeError(e, st);
      if (!_doneCompleter.isCompleted) _doneCompleter.completeError(e, st);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // cancel
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<void> cancel() async {
    if (_isClosed) return;
    _isClosed = true;
    try {
      await _sink.close();
    } catch (_) {}
    if (await _file.exists()) await _file.delete();
    _progressController.close().ignore();
    _bytesController.close().ignore();
    const error = CancelledException();
    if (!_resultCompleter.isCompleted) {
      _resultCompleter.completeError(error);
      _resultCompleter.future.ignore();
    }
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
  }
}
