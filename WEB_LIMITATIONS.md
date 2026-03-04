# Web – Limitations

Saving files on **Flutter Web** is fundamentally different from mobile and desktop platforms due to browser security restrictions.

## How Downloads Work

The download mechanism depends on which API and arguments are used:

| API           | Scenario              | Mechanism                                             | CORS required | Progress                    |
|---------------|-----------------------|-------------------------------------------------------|---------------|-----------------------------|
| `saveNetwork` | No custom `headers`   | `<a href=url download>` — browser native streaming    | ❌            | ❌                          |
| `saveNetwork` | With custom `headers` | `window.fetch()` → Blob → `<a download>`              | ✅            | ❌                          |
| `saveAs`      | Chrome / Edge 86+     | FSA: streams chunks directly to disk (zero RAM)       | ✅            | ✅ (needs `Content-Length`) |
| `saveAs`      | Firefox / Safari      | Falls back to standard browser download               | —             | —                           |

The sections below explain each limitation that flows from these mechanisms.

---

## 1. Browser-Controlled Downloads

When using `saveNetwork` or `saveBytes` without the File System Access API, the browser controls where the file is saved. You cannot programmatically choose a directory, and the final behavior depends on server headers and browser settings.

This is a browser security constraint and cannot be overridden.

---

## 2. Media / PDF Files May Open Instead of Download

If the server response does **not** include:

```
Content-Disposition: attachment
```

browsers may open certain file types directly in the current tab instead of downloading them (PDF, images, audio, video).

### To Force Download

Your server must return:

```
Content-Disposition: attachment; filename="file.ext"
```

> The `download` attribute on `<a>` elements is **not** sufficient for cross-origin files — the browser ignores it silently.

---

## 3. Custom Headers Require `fetch()` (Memory Usage)

If you pass custom HTTP headers:

```dart
saveNetwork(
  url: '...',
  headers: {'Authorization': 'Bearer ...'},
)
```

The browser must use `fetch()` instead of native anchor download. This means the file is loaded into memory (RAM) as a Blob before the download is triggered. Large files may consume significant memory.

**Recommendation:** For large files, avoid custom headers when possible, or use `saveAs()` with directory selection (see §5).

---

## 4. CORS Restrictions

`fetch()` (used when custom headers are present, or when using FSA streaming) is blocked by the browser if the server does not send the appropriate `Access-Control-Allow-Origin` header. The operation immediately yields `SaveProgressError(NetworkException(...))`.

| Scenario                                          | CORS required |
|---------------------------------------------------|---------------|
| `saveNetwork` without `headers` (anchor download) | ❌            |
| `saveNetwork` with custom `headers`               | ✅            |
| `saveAs` + `SaveNetworkInput` (FSA path)          | ✅            |

**Solutions:**
1. Configure `Access-Control-Allow-Origin: *` (or your app origin) on the server.
2. Route the request through a same-origin proxy.
3. Drop custom headers when authorization is not needed.

---

## 5. Zero-RAM Streaming (Recommended for Large Files)

When using `saveAs()` with a directory chosen via `pickDirectory()`, the package uses the **File System Access API (FSA)** to stream data directly to disk — chunk by chunk — without ever loading the full file into memory.

```dart
final directory = await FileSaver.instance.pickDirectory();

await FileSaver.instance.saveAsAsync(
  input: SaveNetworkInput(url: 'https://example.com/large-file.zip'),
  fileName: 'large_file',
  fileType: CustomFileType(ext: 'zip', mimeType: 'application/zip'),
  saveLocation: directory,
  onProgress: (p) => print('${(p * 100).toInt()}%'),
);
```

**Benefits:** no full file in memory, supports GB+ files, real progress reporting, timeout handling.

**Supported browsers:** Chrome 86+, Edge 86+, and other Chromium-based browsers.

**Not supported:** Firefox, Safari — `saveAs()` falls back to browser-controlled download automatically.

---

## 6. `saveAs()` Fallback Behavior

On browsers that do not support FSA (Firefox / Safari):

- `pickDirectory()` throws a `PlatformException`.
- `saveAs()` (when called with `saveLocation: null`) catches this and falls back to a standard browser download.
- The browser controls the save location; zero-RAM streaming is not available.

---

## Recommended Setup for Reliable Web Downloads

1. Use Chromium-based browsers for the best experience.
2. Configure your server to send `Content-Disposition: attachment` for downloadable files.
3. Add `Access-Control-Allow-Origin` headers if you need custom HTTP headers or FSA streaming.
4. Use `pickDirectory()` + `saveAs()` for large files to avoid memory issues.

---

> These limitations are enforced by the browser to prevent silent file system access, unauthorized downloads, and cross-origin data leaks. They cannot be bypassed by JavaScript or Flutter Web.
