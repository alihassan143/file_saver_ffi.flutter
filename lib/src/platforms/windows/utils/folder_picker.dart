import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Win32 type aliases
// ─────────────────────────────────────────────────────────────────────────────

typedef HRESULT = Int32;
typedef DWORD = Uint32;
typedef LPVOID = Pointer<Void>;
typedef ULONG = Uint32;

// ─────────────────────────────────────────────────────────────────────────────
// Win32 constants
// ─────────────────────────────────────────────────────────────────────────────

const int _sOk = 0;
const int _coinitApartmentThreaded = 0x2;
const int _clsctxAll = 23; // CLSCTX_INPROC_SERVER | CLSCTX_LOCAL_SERVER | ...
const int _fosPickFolders = 0x20;
const int _sigdnFileSysPath = 0x80058000; // SIGDN_FILESYSPATH

// ─────────────────────────────────────────────────────────────────────────────
// GUID struct (matches Windows GUID layout)
// ─────────────────────────────────────────────────────────────────────────────

@Packed(4)
base class _GUID extends Struct {
  @Uint32()
  external int data1;

  @Uint16()
  external int data2;

  @Uint16()
  external int data3;

  // data4 is an 8-byte array; stored as Uint64 with little-endian byte order.
  @Uint64()
  external int data4;

  /// Parses a GUID string such as `{DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}`
  /// into the struct fields.
  void parse(String guid) {
    final hex = guid.replaceAll(RegExp(r'[{}-]'), '');
    final bytes = ByteData(16);
    for (int i = 0; i < 16; i++) {
      bytes.setUint8(i, int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
    }
    data1 = bytes.getInt32(0);
    data2 = bytes.getInt16(4);
    data3 = bytes.getInt16(6);
    // data4 is a byte array — preserve byte order with little-endian read.
    data4 = bytes.getInt64(8, Endian.little);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COM function bindings (ole32.dll)
// ─────────────────────────────────────────────────────────────────────────────

final _ole32 = DynamicLibrary.open('ole32.dll');

final _coInitializeEx = _ole32.lookupFunction<
  HRESULT Function(LPVOID, DWORD),
  int Function(Pointer<Void>, int)
>('CoInitializeEx');

final _coUninitialize = _ole32.lookupFunction<Void Function(), void Function()>(
  'CoUninitialize',
);

final _coCreateInstance = _ole32.lookupFunction<
  HRESULT Function(
    Pointer<_GUID>,
    LPVOID,
    DWORD,
    Pointer<_GUID>,
    Pointer<Pointer<Void>>,
  ),
  int Function(
    Pointer<_GUID>,
    Pointer<Void>,
    int,
    Pointer<_GUID>,
    Pointer<Pointer<Void>>,
  )
>('CoCreateInstance');

final _coTaskMemFree = _ole32
    .lookupFunction<Void Function(LPVOID), void Function(Pointer<Void>)>(
      'CoTaskMemFree',
    );

// ─────────────────────────────────────────────────────────────────────────────
// COM vtable helper
// ─────────────────────────────────────────────────────────────────────────────

/// Gets a function pointer from a COM object's vtable at the given [index].
Pointer<NativeFunction<T>> _vtableEntry<T extends Function>(
  Pointer<Void> comObj,
  int index,
) {
  // COM object layout: first pointer is vtable pointer
  final vtable = comObj.cast<Pointer<Pointer<NativeFunction<T>>>>().value;
  return (vtable + index).value;
}

// ─────────────────────────────────────────────────────────────────────────────
// COM vtable function signatures
// ─────────────────────────────────────────────────────────────────────────────

// IUnknown::Release (vtable index 2)
typedef _ReleaseNative = ULONG Function(Pointer<Void>);
typedef _ReleaseDart = int Function(Pointer<Void>);

// IFileDialog::SetOptions (vtable index 9)
typedef _SetOptionsNative = HRESULT Function(Pointer<Void>, DWORD);
typedef _SetOptionsDart = int Function(Pointer<Void>, int);

// IModalWindow::Show (vtable index 3)
typedef _ShowNative = HRESULT Function(Pointer<Void>, IntPtr);
typedef _ShowDart = int Function(Pointer<Void>, int);

// IFileDialog::GetResult (vtable index 20)
typedef _GetResultNative =
    HRESULT Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _GetResultDart = int Function(Pointer<Void>, Pointer<Pointer<Void>>);

// IShellItem::GetDisplayName (vtable index 5)
typedef _GetDisplayNameNative =
    HRESULT Function(Pointer<Void>, Uint32, Pointer<Pointer<Utf16>>);
typedef _GetDisplayNameDart =
    int Function(Pointer<Void>, int, Pointer<Pointer<Utf16>>);

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

class FolderPicker {
  /// Shows a modern Windows folder picker dialog.
  ///
  /// Returns the selected folder path, or `null` if the user cancelled.
  ///
  /// Runs on a separate isolate because the COM dialog blocks the calling
  /// thread until the user closes it.
  static Future<String?> pick() => Isolate.run(_pickSync);

  static String? _pickSync() {
    final hr = _coInitializeEx(nullptr, _coinitApartmentThreaded);
    if (hr < 0 && hr != 1) return null; // 1 = S_FALSE (already initialized)

    try {
      return _showDialog();
    } finally {
      _coUninitialize();
    }
  }

  static String? _showDialog() {
    // CLSID_FileOpenDialog: {DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}
    final clsid =
        calloc<_GUID>()..ref.parse('{DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}');

    // IID_IFileOpenDialog: {D57C7288-D4AD-4768-BE02-9D969532D960}
    final iid =
        calloc<_GUID>()..ref.parse('{D57C7288-D4AD-4768-BE02-9D969532D960}');

    final ppDialog = calloc<Pointer<Void>>();

    try {
      // Create IFileOpenDialog instance
      var hr = _coCreateInstance(clsid, nullptr, _clsctxAll, iid, ppDialog);
      if (hr < 0) return null;

      final dialog = ppDialog.value;

      // Set FOS_PICKFOLDERS option
      final setOptions =
          _vtableEntry<_SetOptionsNative>(
            dialog,
            9,
          ).asFunction<_SetOptionsDart>();
      hr = setOptions(dialog, _fosPickFolders);
      if (hr < 0) {
        _release(dialog);
        return null;
      }

      // Show the dialog (blocks until user closes)
      final show = _vtableEntry<_ShowNative>(dialog, 3).asFunction<_ShowDart>();
      hr = show(dialog, 0);
      if (hr != _sOk) {
        // User cancelled or error
        _release(dialog);
        return null;
      }

      // Get the selected folder as IShellItem
      final ppItem = calloc<Pointer<Void>>();
      try {
        final getResult =
            _vtableEntry<_GetResultNative>(
              dialog,
              20,
            ).asFunction<_GetResultDart>();
        hr = getResult(dialog, ppItem);
        if (hr < 0) {
          _release(dialog);
          return null;
        }

        final item = ppItem.value;

        // Get the file system path from IShellItem
        final ppszName = calloc<Pointer<Utf16>>();
        try {
          final getDisplayName =
              _vtableEntry<_GetDisplayNameNative>(
                item,
                5,
              ).asFunction<_GetDisplayNameDart>();
          hr = getDisplayName(item, _sigdnFileSysPath, ppszName);
          if (hr < 0) {
            _release(item);
            _release(dialog);
            return null;
          }

          final path = ppszName.value.toDartString();
          _coTaskMemFree(ppszName.value.cast());
          _release(item);
          _release(dialog);
          return path;
        } finally {
          calloc.free(ppszName);
        }
      } finally {
        calloc.free(ppItem);
      }
    } finally {
      calloc.free(clsid);
      calloc.free(iid);
      calloc.free(ppDialog);
    }
  }

  static void _release(Pointer<Void> comObj) {
    final release =
        _vtableEntry<_ReleaseNative>(comObj, 2).asFunction<_ReleaseDart>();
    release(comObj);
  }
}
