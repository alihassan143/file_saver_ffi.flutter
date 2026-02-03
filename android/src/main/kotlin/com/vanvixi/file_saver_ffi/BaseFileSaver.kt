package com.vanvixi.file_saver_ffi

import android.content.Context
import com.vanvixi.file_saver_ffi.exception.FileExistsException
import com.vanvixi.file_saver_ffi.exception.NetworkDownloadException
import com.vanvixi.file_saver_ffi.models.ConflictResolution
import com.vanvixi.file_saver_ffi.models.FileType
import com.vanvixi.file_saver_ffi.models.SaveLocation
import com.vanvixi.file_saver_ffi.models.SaveProgressEvent
import com.vanvixi.file_saver_ffi.utils.Constants
import com.vanvixi.file_saver_ffi.utils.FileHelper
import com.vanvixi.file_saver_ffi.utils.NetworkHelper
import com.vanvixi.file_saver_ffi.utils.StoreHelper
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import java.io.FileNotFoundException
import java.io.IOException

abstract class BaseFileSaver(protected val context: Context) {

    /**
     * Saves file to MediaStore with real-time progress streaming
     *
     * @param fileData File content as byte array
     * @param fileType File type (e.g., ImageType, VideoType, AudioType, CustomFileType)
     * @param baseFileName File name WITHOUT extension
     * @param saveLocation Target save location (e.g., PICTURES, DOWNLOADS, DCIM)
     * @param subDir Optional album name (null → Pictures folder)
     * @param conflictResolution Conflict resolution mode
     * @return Flow of SaveProgressEvent with real-time progress updates
     */
    open fun saveBytes(
        fileData: ByteArray,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
    ): Flow<SaveProgressEvent> = callbackFlow {
        trySend(SaveProgressEvent.Started)

        try {
            if (fileData.isEmpty()) {
                trySend(
                    SaveProgressEvent.Error(Constants.ERROR_INVALID_FILE, "File data cannot be empty")
                )
                close()
                awaitClose {}
                return@callbackFlow
            }

            // Progress: 0.05 (preparing)
            trySend(SaveProgressEvent.Progress(0.05))

            val (uri, outputStream) = try {
                StoreHelper.createEntry(
                    context,
                    fileType,
                    baseFileName,
                    saveLocation,
                    subDir,
                    conflictResolution,
                )
            } catch (e: IOException) {
                trySend(
                    SaveProgressEvent.Error(
                        Constants.ERROR_FILE_IO,
                        "Failed to create MediaStore entry: ${e.message}",
                    )
                )
                close()
                awaitClose {}
                return@callbackFlow
            } catch (e: FileExistsException) {
                trySend(
                    SaveProgressEvent.Error(
                        Constants.ERROR_FILE_EXISTS,
                        e.message ?: "File already exists",
                    )
                )
                close()
                awaitClose {}
                return@callbackFlow
            }

            // Progress: 0.1 (entry created)
            trySend(SaveProgressEvent.Progress(0.1))

            try {
                // Write with real-time progress (0.1 - 0.9)
                FileHelper.writeStream(outputStream, fileData) { writeProgress ->
                    // Map write progress (0.0-1.0) to overall progress (0.1-0.9)
                    val overallProgress = 0.1 + (writeProgress * 0.8)
                    trySend(SaveProgressEvent.Progress(overallProgress))
                }
            } catch (e: CancellationException) {
                // Operation was cancelled - cleanup partial file
                try {
                    context.contentResolver.delete(uri, null, null)
                } catch (_: Exception) {
                    // Ignore delete errors
                }
                trySend(SaveProgressEvent.Cancelled)
                close()
                awaitClose {}
                throw e  // Re-throw to properly cancel coroutine
            } catch (e: IOException) {
                // If write fails, try to delete the MediaStore entry
                try {
                    context.contentResolver.delete(uri, null, null)
                } catch (_: Exception) {
                    // Ignore delete errors
                }
                trySend(
                    SaveProgressEvent.Error(
                        Constants.ERROR_FILE_IO,
                        "Failed to write file data: ${e.message}",
                    )
                )
                close()
                awaitClose {}
                return@callbackFlow
            }

            // Progress: 0.9 (write complete)
            trySend(SaveProgressEvent.Progress(0.9))

            try {
                StoreHelper.markEntryComplete(context, uri)
            } catch (_: Exception) {
                // If marking complete fails, file is still saved
            }

            // Progress: 1.0 (complete)
            trySend(SaveProgressEvent.Progress(1.0))

            trySend(SaveProgressEvent.Success(uri.toString()))
        } catch (e: SecurityException) {
            trySend(
                SaveProgressEvent.Error(
                    Constants.ERROR_PERMISSION_DENIED,
                    "Permission denied: ${e.message}",
                )
            )
        } catch (e: Exception) {
            trySend(
                SaveProgressEvent.Error(
                    Constants.ERROR_PLATFORM,
                    "Unexpected error: ${e.message ?: "Unknown error"}",
                )
            )
        }

        close()
        awaitClose {}
    }.flowOn(Dispatchers.IO)

    /**
     * Saves file from source path to MediaStore with real-time progress streaming
     *
     * Reads source file in chunks without loading into memory - suitable for large files.
     *
     * @param filePath Source file path (file:// or content:// URI)
     * @param fileType File type (e.g., ImageType, VideoType, AudioType, CustomFileType)
     * @param baseFileName Target file name WITHOUT extension
     * @param saveLocation Target save location (e.g., PICTURES, DOWNLOADS, DCIM)
     * @param subDir Optional album name (null → default folder)
     * @param conflictResolution Conflict resolution mode
     * @return Flow of SaveProgressEvent with real-time progress updates
     */
    open fun saveFile(
        filePath: String,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
    ): Flow<SaveProgressEvent> = callbackFlow {
        trySend(SaveProgressEvent.Started)

        try {
            // Progress: 0.05 (preparing)
            trySend(SaveProgressEvent.Progress(0.05))

            // Open source file
            val sourceFile = try {
                FileHelper.openSourceFile(context, filePath)
            } catch (_: FileNotFoundException) {
                trySend(
                    SaveProgressEvent.Error(
                        Constants.ERROR_FILE_NOT_FOUND,
                        "Source file not found: $filePath",
                    )
                )
                close()
                awaitClose {}
                return@callbackFlow
            } catch (e: SecurityException) {
                trySend(
                    SaveProgressEvent.Error(
                        Constants.ERROR_PERMISSION_DENIED,
                        "Permission denied: ${e.message}",
                    )
                )
                close()
                awaitClose {}
                return@callbackFlow
            } catch (e: IllegalArgumentException) {
                trySend(
                    SaveProgressEvent.Error(
                        Constants.ERROR_INVALID_FILE,
                        e.message ?: "Invalid file path",
                    )
                )
                close()
                awaitClose {}
                return@callbackFlow
            }

            // Progress: 0.1 (source file opened)
            trySend(SaveProgressEvent.Progress(0.1))

            // Create MediaStore entry
            val (uri, outputStream) = try {
                StoreHelper.createEntry(
                    context,
                    fileType,
                    baseFileName,
                    saveLocation,
                    subDir,
                    conflictResolution,
                )
            } catch (e: IOException) {
                sourceFile.inputStream.close()
                trySend(
                    SaveProgressEvent.Error(
                        Constants.ERROR_FILE_IO,
                        "Failed to create MediaStore entry: ${e.message}",
                    )
                )
                close()
                awaitClose {}
                return@callbackFlow
            } catch (e: FileExistsException) {
                sourceFile.inputStream.close()
                trySend(
                    SaveProgressEvent.Error(
                        Constants.ERROR_FILE_EXISTS,
                        e.message ?: "File already exists",
                    )
                )
                close()
                awaitClose {}
                return@callbackFlow
            }

            // Progress: 0.15 (entry created)
            trySend(SaveProgressEvent.Progress(0.15))

            try {
                // Copy with real-time progress (0.15 - 0.9)
                FileHelper.copyStream(sourceFile.inputStream, outputStream, sourceFile.totalSize) { copyProgress ->
                    // Map copy progress (0.0-1.0) to overall progress (0.15-0.9)
                    val overallProgress = 0.15 + (copyProgress * 0.75)
                    trySend(SaveProgressEvent.Progress(overallProgress))
                }
            } catch (e: CancellationException) {
                // Operation was cancelled - cleanup partial file
                try {
                    context.contentResolver.delete(uri, null, null)
                } catch (_: Exception) {
                    // Ignore delete errors
                }
                trySend(SaveProgressEvent.Cancelled)
                close()
                awaitClose {}
                throw e  // Re-throw to properly cancel coroutine
            } catch (e: IOException) {
                // If copy fails, try to delete the MediaStore entry
                try {
                    context.contentResolver.delete(uri, null, null)
                } catch (_: Exception) {
                    // Ignore delete errors
                }
                trySend(
                    SaveProgressEvent.Error(
                        Constants.ERROR_FILE_IO, "Failed to copy file: ${e.message}"
                    )
                )
                close()
                awaitClose {}
                return@callbackFlow
            }

            // Progress: 0.9 (copy complete)
            trySend(SaveProgressEvent.Progress(0.9))

            try {
                StoreHelper.markEntryComplete(context, uri)
            } catch (_: Exception) {
                // If marking complete fails, file is still saved
            }

            // Progress: 1.0 (complete)
            trySend(SaveProgressEvent.Progress(1.0))

            trySend(SaveProgressEvent.Success(uri.toString()))
        } catch (e: SecurityException) {
            trySend(
                SaveProgressEvent.Error(
                    Constants.ERROR_PERMISSION_DENIED,
                    "Permission denied: ${e.message}",
                )
            )
        } catch (e: Exception) {
            trySend(
                SaveProgressEvent.Error(
                    Constants.ERROR_PLATFORM,
                    "Unexpected error: ${e.message ?: "Unknown error"}",
                )
            )
        }

        close()
        awaitClose {}
    }.flowOn(Dispatchers.IO)

    /**
     * Downloads file from network URL and saves directly to MediaStore (zero temp files).
     *
     * Streams data from HttpURLConnection directly into MediaStore OutputStream,
     * providing continuous progress from 0.0 to 1.0.
     *
     * @param url Network URL to download from
     * @param headersJson Optional JSON string of HTTP headers
     * @param timeoutMs Timeout in milliseconds for network connection
     * @param fileType File type (e.g., ImageType, VideoType, AudioType, CustomFileType)
     * @param baseFileName Target file name WITHOUT extension
     * @param saveLocation Target save location (e.g., PICTURES, DOWNLOADS, DCIM)
     * @param subDir Optional subdirectory within target location
     * @param conflictResolution Conflict resolution mode
     * @return Flow of SaveProgressEvent with real-time progress updates
     */
    open fun saveNetwork(
        url: String,
        headersJson: String?,
        timeoutMs: Int,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
    ): Flow<SaveProgressEvent> = callbackFlow {
        trySend(SaveProgressEvent.Started)

        try {
            // Progress: 0.02 (connecting)
            trySend(SaveProgressEvent.Progress(0.02))

            // 1. Open network connection
            val connectionResult = try {
                NetworkHelper.openConnection(url, headersJson, timeoutMs)
            } catch (e: NetworkDownloadException) {
                val message = if (e.statusCode != null) {
                    "Network download failed (HTTP ${e.statusCode}): ${e.message}"
                } else {
                    "Network download failed: ${e.message}"
                }
                trySend(SaveProgressEvent.Error(Constants.ERROR_NETWORK, message))
                close()
                awaitClose {}
                return@callbackFlow
            }

            try {
                // Progress: 0.05 (connected, creating entry)
                trySend(SaveProgressEvent.Progress(0.05))

                // 2. Create MediaStore entry
                val (uri, outputStream) = try {
                    StoreHelper.createEntry(
                        context,
                        fileType,
                        baseFileName,
                        saveLocation,
                        subDir,
                        conflictResolution,
                    )
                } catch (e: IOException) {
                    trySend(
                        SaveProgressEvent.Error(
                            Constants.ERROR_FILE_IO,
                            "Failed to create MediaStore entry: ${e.message}",
                        )
                    )
                    close()
                    awaitClose {}
                    return@callbackFlow
                } catch (e: FileExistsException) {
                    trySend(
                        SaveProgressEvent.Error(
                            Constants.ERROR_FILE_EXISTS,
                            e.message ?: "File already exists",
                        )
                    )
                    close()
                    awaitClose {}
                    return@callbackFlow
                }

                // Progress: 0.1 (entry created, streaming)
                trySend(SaveProgressEvent.Progress(0.1))

                try {
                    // 3. Stream directly: network → MediaStore (single pass)
                    FileHelper.copyStream(
                        connectionResult.inputStream,
                        outputStream,
                        connectionResult.contentLength,
                    ) { copyProgress ->
                        // Map copy progress (0.0-1.0) to overall progress (0.1-0.9)
                        val overallProgress = 0.1 + (copyProgress * 0.8)
                        trySend(SaveProgressEvent.Progress(overallProgress))
                    }
                } catch (e: CancellationException) {
                    // Operation was cancelled - cleanup partial file
                    try {
                        context.contentResolver.delete(uri, null, null)
                    } catch (_: Exception) {
                        // Ignore delete errors
                    }
                    trySend(SaveProgressEvent.Cancelled)
                    close()
                    awaitClose {}
                    throw e  // Re-throw to properly cancel coroutine
                } catch (e: IOException) {
                    // If copy fails, try to delete the MediaStore entry
                    try {
                        context.contentResolver.delete(uri, null, null)
                    } catch (_: Exception) {
                        // Ignore delete errors
                    }
                    trySend(
                        SaveProgressEvent.Error(
                            Constants.ERROR_FILE_IO,
                            "Failed to stream network data: ${e.message}",
                        )
                    )
                    close()
                    awaitClose {}
                    return@callbackFlow
                }

                // Progress: 0.9 (stream complete)
                trySend(SaveProgressEvent.Progress(0.9))

                try {
                    StoreHelper.markEntryComplete(context, uri)
                } catch (_: Exception) {
                    // If marking complete fails, file is still saved
                }

                // Progress: 1.0 (complete)
                trySend(SaveProgressEvent.Progress(1.0))

                trySend(SaveProgressEvent.Success(uri.toString()))
            } finally {
                // Always disconnect the HTTP connection
                try {
                    connectionResult.connection.disconnect()
                } catch (_: Exception) {
                    // Ignore disconnect errors
                }
            }
        } catch (e: SecurityException) {
            trySend(
                SaveProgressEvent.Error(
                    Constants.ERROR_PERMISSION_DENIED,
                    "Permission denied: ${e.message}",
                )
            )
        } catch (e: Exception) {
            trySend(
                SaveProgressEvent.Error(
                    Constants.ERROR_PLATFORM,
                    "Unexpected error: ${e.message ?: "Unknown error"}",
                )
            )
        }

        close()
        awaitClose {}
    }.flowOn(Dispatchers.IO)
}
