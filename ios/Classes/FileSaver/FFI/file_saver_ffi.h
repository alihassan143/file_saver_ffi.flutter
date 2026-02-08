#ifndef file_saver_ffi_h
#define file_saver_ffi_h

#include <stdint.h>
#include <stdbool.h>

/// Initialize Dart API for NativePort communication.
/// Must be called before using file_saver_save_bytes.
///
/// @param data Pointer from NativeApi.initializeApiDLData
/// @return 0 on success, -1 on failure
intptr_t file_saver_init_dart_api_dl(void* data);

void* file_saver_init(void);


void file_saver_dispose(void* instance);

/// Cancel an ongoing save operation.
///
/// @param tokenId Token ID returned from file_saver_save_bytes or file_saver_save_file
void file_saver_cancel(uint64_t tokenId);

/// Save file bytes asynchronously with progress reporting via NativePort.
///
/// Progress messages sent to native_port:
/// - Started:    [0]
/// - Progress:   [1, progress]    (progress is 0.0 to 1.0)
/// - Error:      [2, errorCode, errorMessage]
/// - Success:    [3, fileUri]
/// - Cancelled:  [4]
///
/// @param instance FileSaver instance from file_saver_init
/// @param fileData Byte array of file content
/// @param fileDataLength Length of fileData
/// @param baseFileName File name without extension
/// @param extension File extension without dot
/// @param mimeType MIME type string
/// @param saveLocation Save location index (0-4)
/// @param subDir Optional subdirectory (can be NULL)
/// @param conflictMode Conflict resolution mode (0-3)
/// @param native_port Dart NativePort for progress reporting
/// @return Token ID for cancellation
uint64_t file_saver_save_bytes(
    void* instance,
    const uint8_t* fileData,
    int64_t fileDataLength,
    const char* baseFileName,
    const char* extension,
    const char* mimeType,
    int32_t saveLocation,
    const char* subDir,
    int32_t conflictMode,
    int64_t native_port
);

/// Save file from source path asynchronously with progress reporting via
/// NativePort.
///
/// Reads source file in chunks without loading into memory - suitable for large
/// files. Handles security-scoped resources (Files app) and iCloud file
/// downloads.
///
/// Progress messages sent to native_port:
/// - Started:    [0]
/// - Progress:   [1, progress]    (progress is 0.0 to 1.0)
/// - Error:      [2, errorCode, errorMessage]
/// - Success:    [3, fileUri]
/// - Cancelled:  [4]
///
/// @param instance FileSaver instance from file_saver_init
/// @param filePath Source file path (file:// URI)
/// @param baseFileName Target file name without extension
/// @param extension File extension without dot
/// @param mimeType MIME type string
/// @param saveLocation Save location index (0-1 for iOS)
/// @param subDir Optional subdirectory (can be NULL)
/// @param conflictMode Conflict resolution mode (0-3)
/// @param native_port Dart NativePort for progress reporting
/// @return Token ID for cancellation
uint64_t file_saver_save_file(
    void *instance,
    const char *filePath,
    const char *baseFileName,
    const char *extension,
    const char *mimeType,
    int32_t saveLocation,
    const char *subDir,
    int32_t conflictMode,
    int64_t native_port
);

/// Save file from network URL asynchronously with progress reporting via
/// NativePort.
///
/// Downloads file at native level to avoid double storage:
/// - Documents: Downloads directly to target path
/// - Photos: Downloads to tmp, saves to Photos Library, deletes tmp
///
/// Progress messages sent to native_port:
/// - Started:    [0]
/// - Progress:   [1, progress]    (progress is 0.0 to 1.0)
/// - Error:      [2, errorCode, errorMessage]
/// - Success:    [3, fileUri]
/// - Cancelled:  [4]
///
/// @param instance FileSaver instance from file_saver_init
/// @param urlString URL to download from
/// @param headersJson Optional JSON string of HTTP headers (can be NULL)
/// @param timeoutSeconds Timeout in seconds for network request
/// @param baseFileName File name without extension
/// @param extension File extension without dot
/// @param mimeType MIME type string
/// @param saveLocation Save location index (0-1 for iOS)
/// @param subDir Optional subdirectory (can be NULL)
/// @param conflictMode Conflict resolution mode (0-3)
/// @param native_port Dart NativePort for progress reporting
/// @return Token ID for cancellation
uint64_t file_saver_save_network(
    void* instance,
    const char* urlString,
    const char* headersJson,
    int32_t timeoutSeconds,
    const char* baseFileName,
    const char* extension,
    const char* mimeType,
    int32_t saveLocation,
    const char* subDir,
    int32_t conflictMode,
    int64_t native_port
);

// MARK: - User-Selected Location (Document Picker)

/// Pick a directory via system Document Picker.
///
/// Shows the system directory picker and returns the selected directory URI.
///
/// Messages sent to native_port:
/// - Success:    [3, directoryUri]
/// - Cancelled:  [4]
/// - Error:      [2, errorCode, errorMessage]
///
/// @param instance FileSaver instance from file_saver_init
/// @param native_port Dart NativePort for result reporting
void file_saver_pick_directory(
    void* instance,
    int64_t native_port
);

/// Save bytes to user-selected directory (saveAs).
///
/// Saves file bytes to a directory previously selected via file_saver_pick_directory.
/// Uses security-scoped resource access for the selected directory.
///
/// Progress messages sent to native_port:
/// - Started:    [0]
/// - Progress:   [1, progress]    (progress is 0.0 to 1.0)
/// - Error:      [2, errorCode, errorMessage]
/// - Success:    [3, fileUri]
/// - Cancelled:  [4]
///
/// @param instance FileSaver instance from file_saver_init
/// @param fileData Byte array of file content
/// @param fileDataLength Length of fileData
/// @param directoryUri Directory URI from file_saver_pick_directory
/// @param baseFileName File name without extension
/// @param extension File extension without dot
/// @param conflictMode Conflict resolution mode (0-3)
/// @param native_port Dart NativePort for progress reporting
/// @return Token ID for cancellation
uint64_t file_saver_save_bytes_as(
    void* instance,
    const uint8_t* fileData,
    int64_t fileDataLength,
    const char* directoryUri,
    const char* baseFileName,
    const char* extension,
    int32_t conflictMode,
    int64_t native_port
);

/// Save file to user-selected directory (saveAs).
///
/// Copies a file to a directory previously selected via file_saver_pick_directory.
/// Uses security-scoped resource access for the selected directory.
///
/// Progress messages sent to native_port:
/// - Started:    [0]
/// - Progress:   [1, progress]    (progress is 0.0 to 1.0)
/// - Error:      [2, errorCode, errorMessage]
/// - Success:    [3, fileUri]
/// - Cancelled:  [4]
///
/// @param instance FileSaver instance from file_saver_init
/// @param filePath Source file path (file:// URI)
/// @param directoryUri Directory URI from file_saver_pick_directory
/// @param baseFileName File name without extension
/// @param extension File extension without dot
/// @param conflictMode Conflict resolution mode (0-3)
/// @param native_port Dart NativePort for progress reporting
/// @return Token ID for cancellation
uint64_t file_saver_save_file_as(
    void* instance,
    const char* filePath,
    const char* directoryUri,
    const char* baseFileName,
    const char* extension,
    int32_t conflictMode,
    int64_t native_port
);

/// Save network file to user-selected directory (saveAs).
///
/// Downloads and saves a file to a directory previously selected via
/// file_saver_pick_directory. Uses security-scoped resource access.
///
/// Progress messages sent to native_port:
/// - Started:    [0]
/// - Progress:   [1, progress]    (progress is 0.0 to 1.0)
/// - Error:      [2, errorCode, errorMessage]
/// - Success:    [3, fileUri]
/// - Cancelled:  [4]
///
/// @param instance FileSaver instance from file_saver_init
/// @param urlString URL to download from
/// @param headersJson Optional JSON string of HTTP headers (can be NULL)
/// @param timeoutSeconds Timeout in seconds for network request
/// @param directoryUri Directory URI from file_saver_pick_directory
/// @param baseFileName File name without extension
/// @param extension File extension without dot
/// @param conflictMode Conflict resolution mode (0-3)
/// @param native_port Dart NativePort for progress reporting
/// @return Token ID for cancellation
uint64_t file_saver_save_network_as(
    void* instance,
    const char* urlString,
    const char* headersJson,
    int32_t timeoutSeconds,
    const char* directoryUri,
    const char* baseFileName,
    const char* extension,
    int32_t conflictMode,
    int64_t native_port
);

#endif
