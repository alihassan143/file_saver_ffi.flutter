package com.vanvixi.file_saver_ffi

import android.content.Context
import com.vanvixi.file_saver_ffi.models.FileType
import com.vanvixi.file_saver_ffi.models.SaveLocation
import com.vanvixi.file_saver_ffi.models.SaveProgressEvent
import com.vanvixi.file_saver_ffi.utils.Constants
import com.vanvixi.file_saver_ffi.exception.FileExistsException
import com.vanvixi.file_saver_ffi.models.ConflictResolution
import com.vanvixi.file_saver_ffi.utils.FileHelper
import com.vanvixi.file_saver_ffi.utils.StoreHelper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import java.io.IOException

abstract class BaseFileSaver(protected val context: Context) {

    /**
     * Saves file to MediaStore with progress streaming
     *
     * @param fileData File content as byte array
     * @param fileType File type (e.g., ImageType, VideoType, AudioType, CustomFileType)
     * @param baseFileName File name WITHOUT extension
     * @param saveLocation Target save location (e.g., PICTURES, DOWNLOADS, DCIM)
     * @param subDir Optional album name (null → Pictures folder)
     * @param conflictResolution Conflict resolution mode
     * @return Flow of SaveProgressEvent
     */
    open fun saveBytes(
        fileData: ByteArray,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
    ): Flow<SaveProgressEvent> = flow {
        emit(SaveProgressEvent.Started)

        try {
            if (fileData.isEmpty()) {
                emit(SaveProgressEvent.Error(
                    Constants.ERROR_INVALID_FILE,
                    "File data cannot be empty"
                ))
                return@flow
            }

            // Progress: 0.0 - 0.1 (preparing)
            emit(SaveProgressEvent.Progress(0.05))

            val (uri, outputStream) = try {
                StoreHelper.createEntry(
                    context, fileType, baseFileName, saveLocation, subDir, conflictResolution,
                )
            } catch (e: IOException) {
                emit(SaveProgressEvent.Error(
                    Constants.ERROR_FILE_IO,
                    "Failed to create MediaStore entry: ${e.message}"
                ))
                return@flow
            } catch (e: FileExistsException) {
                emit(SaveProgressEvent.Error(
                    Constants.ERROR_FILE_EXISTS,
                    e.message ?: "File already exists"
                ))
                return@flow
            }

            // Progress: 0.1 (entry created)
            emit(SaveProgressEvent.Progress(0.1))

            try {
                // Write with progress (0.1 - 0.9)
                FileHelper.writeStream(outputStream, fileData) { writeProgress ->
                    // Map write progress (0.0-1.0) to overall progress (0.1-0.9)
                    val overallProgress = 0.1 + (writeProgress * 0.8)
                    // Note: This callback runs on IO dispatcher, we can't emit directly
                    // So we'll just use the final progress after write completes
                }
            } catch (e: IOException) {
                // If write fails, try to delete the MediaStore entry
                try {
                    context.contentResolver.delete(uri, null, null)
                } catch (_: Exception) {
                    // Ignore delete errors
                }
                emit(SaveProgressEvent.Error(
                    Constants.ERROR_FILE_IO,
                    "Failed to write file data: ${e.message}"
                ))
                return@flow
            }

            // Progress: 0.9 (write complete)
            emit(SaveProgressEvent.Progress(0.9))

            try {
                StoreHelper.markEntryComplete(context, uri)
            } catch (_: Exception) {
                // If marking complete fails, file is still saved
            }

            // Progress: 1.0 (complete)
            emit(SaveProgressEvent.Progress(1.0))

            emit(SaveProgressEvent.Success(uri.toString()))

        } catch (e: SecurityException) {
            emit(SaveProgressEvent.Error(
                Constants.ERROR_PERMISSION_DENIED,
                "Permission denied: ${e.message}"
            ))
        } catch (e: Exception) {
            emit(SaveProgressEvent.Error(
                Constants.ERROR_PLATFORM,
                "Unexpected error: ${e.message ?: "Unknown error"}"
            ))
        }
    }.flowOn(Dispatchers.IO)
}
