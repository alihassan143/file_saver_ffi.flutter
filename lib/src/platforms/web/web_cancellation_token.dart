import 'dart:js_interop';

import 'package:web/web.dart';

import 'web_file_entity.dart';

class WebCancellationToken {
  bool isCancelled = false;
  AbortController? _controller;
  WebFileEntity? _fileEntity;
  String? _fileName;
  FileSystemWritableFileStream? _writable;

  void setController(AbortController c) => _controller = c;

  void setFileEntry(WebFileEntity entity, String name) {
    _fileEntity = entity;
    _fileName = name;
    // cancel() may have fired before getFileHandle completed — delete directly
    // (no writable yet → file not locked).
    if (isCancelled) {
      if (_writable != null) {
        _abortThenDelete();
      } else {
        _deleteFile();
      }
    }
  }

  void setWritable(FileSystemWritableFileStream w) {
    _writable = w;
    // cancel() may have fired before createWritable() completed. The earlier
    // _deleteFile() attempt in cancel() may have failed due to the file lock
    // acquired by createWritable(). Abort the writable first (releases lock),
    // then retry the delete.
    if (isCancelled) _abortThenDelete();
  }

  /// Call after writable.close() succeeds to prevent cleanup from running
  /// when the stream subscription is cancelled after the done event.
  void complete() {
    _fileEntity = null;
    _fileName = null;
    _writable = null;
  }

  void cancel([String? reason]) {
    isCancelled = true;
    _controller?.abort(reason?.toJS);
    _controller = null;
    if (_writable != null) {
      // File is locked by the open writable — must abort first to release the
      // lock, then delete. Concurrent delete + abort causes NoModificationAllowedError.
      _abortThenDelete();
    } else {
      // No writable open yet — file is not locked, delete directly.
      _deleteFile();
    }
  }

  void _deleteFile() {
    _fileEntity?.delete(_fileName!).catchError((_) => null).then((_) {
      _fileEntity = null;
      _fileName = null;
    });
  }

  void _abortThenDelete() {
    _writable?.abort().toDart.catchError((_) => null).then((_) {
      _writable = null;
      _deleteFile();
    });
  }
}
