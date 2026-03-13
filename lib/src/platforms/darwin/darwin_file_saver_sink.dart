import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../exceptions/file_saver_exceptions.dart';
import '../../models/file_saver_sink.dart';
import 'bindings.g.dart';

/// Darwin (iOS / macOS) implementation of [FileSaverSink].
///
/// Wraps an FFI write session with progress/bytesWritten tracking.
/// Each FFI call uses a one-shot [ReceivePort] that is closed after the first
/// event fires. Swift copies the data buffer synchronously before returning
/// from `file_saver_write_chunk`, so the Dart arena is safe to free immediately.
class DarwinFileSaverSink implements FileSaverSink {
  DarwinFileSaverSink({
    required FileSaverFFI fileSaver,
    required int sessionId,
    int? totalSize,
  }) : _fileSaver = fileSaver,
       _sessionId = sessionId,
       _totalSize = totalSize;

  final FileSaverFFI _fileSaver;
  final int _sessionId;
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
    if (_isAddingStream) {
      throw StateError('Cannot add while addStream is active');
    }
    _dispatchChunk(data);
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
        await _writeChunkAwaited(chunk);
      }
    } finally {
      _isAddingStream = false;
    }
  }

  @override
  Future<void> flush() {
    final completer = Completer<void>();
    final receivePort = ReceivePort();
    receivePort.listen((message) {
      receivePort.close();
      final msg = message as List;
      switch (msg[0] as int) {
        case 1:
          if (!completer.isCompleted) completer.complete();
        case 2:
          if (!completer.isCompleted) {
            completer.completeError(
              FileSaverException.fromErrorResult(
                msg[1] as String,
                msg[2] as String,
              ),
            );
          }
      }
    });
    _fileSaver.flushWrite(_sessionId, receivePort.sendPort.nativePort);
    return completer.future;
  }

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    while (_isAddingStream) {
      await Future.microtask(() {});
    }

    await _doClose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // cancel
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<void> cancel() async {
    if (_isClosed) return;
    _isClosed = true;
    _fileSaver.cancelWrite(_sessionId);
    _progressController.close().ignore();
    _bytesController.close().ignore();
    const error = CancelledException();
    if (!_resultCompleter.isCompleted) {
      _resultCompleter.completeError(error);
      _resultCompleter.future.ignore();
    }
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Fire-and-forget chunk write (used by [add]).
  void _dispatchChunk(List<int> data) {
    final bytes = Uint8List.fromList(data);
    final receivePort = ReceivePort();
    receivePort.listen((message) {
      receivePort.close();
      if (_isClosed) return;
      final msg = message as List;
      switch (msg[0] as int) {
        case 1:
          _bytesWritten = (msg[1] as num).toInt();
          _bytesController.add(_bytesWritten);
          final total = _totalSize;
          if (total != null && total > 0) {
            _progressController.add(_bytesWritten / total);
          }
        case 2:
          if (!_doneCompleter.isCompleted) {
            _doneCompleter.completeError(
              const WriteSessionException('Write chunk failed'),
            );
          }
      }
    });
    using((arena) {
      final dataPtr = arena<Uint8>(bytes.length);
      dataPtr.asTypedList(bytes.length).setAll(0, bytes);
      _fileSaver.writeChunk(
        _sessionId,
        dataPtr,
        bytes.length,
        receivePort.sendPort.nativePort,
      );
    });
  }

  /// Sequential chunk write with back-pressure (used by [addStream]).
  ///
  /// Awaits the native ACK (type=1) before returning, ensuring the next chunk
  /// is not sent until the previous one has been written to disk.
  Future<void> _writeChunkAwaited(List<int> data) {
    final completer = Completer<void>();
    final bytes = Uint8List.fromList(data);
    final receivePort = ReceivePort();
    receivePort.listen((message) {
      receivePort.close();
      final msg = message as List;
      switch (msg[0] as int) {
        case 1:
          if (!_isClosed) {
            _bytesWritten = (msg[1] as num).toInt();
            _bytesController.add(_bytesWritten);
            final total = _totalSize;
            if (total != null && total > 0) {
              _progressController.add(_bytesWritten / total);
            }
          }
          if (!completer.isCompleted) completer.complete();
        case 2:
          if (!completer.isCompleted) {
            completer.completeError(
              const WriteSessionException('Write chunk failed'),
            );
          }
      }
    });
    using((arena) {
      final dataPtr = arena<Uint8>(bytes.length);
      dataPtr.asTypedList(bytes.length).setAll(0, bytes);
      _fileSaver.writeChunk(
        _sessionId,
        dataPtr,
        bytes.length,
        receivePort.sendPort.nativePort,
      );
    });
    return completer.future;
  }

  Future<void> _doClose() async {
    final receivePort = ReceivePort();
    final closeCompleter = Completer<Uri>();
    receivePort.listen((message) {
      receivePort.close();
      final msg = message as List;
      switch (msg[0] as int) {
        case 3:
          if (!closeCompleter.isCompleted) {
            closeCompleter.complete(Uri.parse(msg[1] as String));
          }
        case 2:
          if (!closeCompleter.isCompleted) {
            closeCompleter.completeError(
              FileSaverException.fromErrorResult(
                msg[1] as String,
                msg[2] as String,
              ),
            );
          }
      }
    });
    _fileSaver.closeWrite(_sessionId, receivePort.sendPort.nativePort);
    try {
      final uri = await closeCompleter.future;
      _progressController.close().ignore();
      _bytesController.close().ignore();
      if (!_resultCompleter.isCompleted) _resultCompleter.complete(uri);
      if (!_doneCompleter.isCompleted) _doneCompleter.complete(uri);
    } catch (e, st) {
      _progressController.close().ignore();
      _bytesController.close().ignore();
      if (!_resultCompleter.isCompleted) _resultCompleter.completeError(e, st);
      if (!_doneCompleter.isCompleted) _doneCompleter.completeError(e, st);
    }
  }
}
