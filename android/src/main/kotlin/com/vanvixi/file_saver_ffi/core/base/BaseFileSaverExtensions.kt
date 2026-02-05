package com.vanvixi.file_saver_ffi.core.base

import android.content.Context
import android.net.Uri
import com.vanvixi.file_saver_ffi.exception.FileExistsException
import com.vanvixi.file_saver_ffi.models.ConflictResolution
import com.vanvixi.file_saver_ffi.models.FileType
import com.vanvixi.file_saver_ffi.models.SaveLocation
import com.vanvixi.file_saver_ffi.models.SaveProgressEvent
import com.vanvixi.file_saver_ffi.utils.Constants
import com.vanvixi.file_saver_ffi.utils.StoreHelper
import kotlinx.coroutines.channels.ProducerScope
import java.io.IOException
import java.io.OutputStream

/**
 * Creates MediaStore entry with standardized error handling.
 * Returns null and sends error event if creation fails.
 */
internal suspend fun ProducerScope<SaveProgressEvent>.createStoreEntry(
    context: Context,
    fileType: FileType,
    baseFileName: String,
    saveLocation: SaveLocation,
    subDir: String?,
    conflictResolution: ConflictResolution
): Pair<Uri, OutputStream>? {
    return try {
        StoreHelper.createEntry(context, fileType, baseFileName, saveLocation, subDir, conflictResolution)
    } catch (e: IOException) {
        sendError(Constants.ERROR_FILE_IO, "Failed to create MediaStore entry: ${e.message}")
        null
    } catch (e: FileExistsException) {
        sendError(Constants.ERROR_FILE_EXISTS, e.message ?: "File already exists")
        null
    }
}

/**
 * Deletes MediaStore entry, ignoring errors.
 */
internal fun Context.deleteEntry(uri: Uri) {
    try {
        contentResolver.delete(uri, null, null)
    } catch (_: Exception) {
    }
}

/**
 * Completes save operation with standard progress events (0.9 → 1.0 → Success).
 */
internal suspend fun ProducerScope<SaveProgressEvent>.finishSave(
    context: Context, uri: Uri
) {
    sendProgress(0.9)
    try {
        StoreHelper.markEntryComplete(context, uri)
    } catch (_: Exception) {
    }
    sendProgress(1.0)
    sendSuccess(uri.toString())
}

/**
 * Maps progress from source range [0.0-1.0] to target range [start-end].
 */
internal fun mapProgress(progress: Double, start: Double, end: Double): Double {
    return start + (progress * (end - start))
}

// MARK: - Event Sending Extensions

/**
 * Sends a progress event.
 */
internal fun ProducerScope<SaveProgressEvent>.sendProgress(progress: Double) {
    trySend(SaveProgressEvent.Progress(progress))
}

/**
 * Sends an error event.
 */
internal fun ProducerScope<SaveProgressEvent>.sendError(code: String, message: String) {
    trySend(SaveProgressEvent.Error(code, message))
}

/**
 * Sends a cancelled event.
 */
internal fun ProducerScope<SaveProgressEvent>.sendCancelled() {
    trySend(SaveProgressEvent.Cancelled)
}

/**
 * Sends a success event.
 */
internal fun ProducerScope<SaveProgressEvent>.sendSuccess(uri: String) {
    trySend(SaveProgressEvent.Success(uri))
}
