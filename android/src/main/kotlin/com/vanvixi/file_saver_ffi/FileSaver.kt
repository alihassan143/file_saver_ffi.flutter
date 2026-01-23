package com.vanvixi.file_saver_ffi

import android.content.Context
import com.vanvixi.file_saver_ffi.models.*
import com.vanvixi.file_saver_ffi.utils.Constants
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch

class FileSaver(context: Context) {
    private val imageSaver = ImageSaver(context)
    private val videoSaver = VideoSaver(context)
    private val audioSaver = AudioSaver(context)
    private val customFileSaver = CustomFileSaver(context)

    /**
     * Saves file data with progress streaming (internal)
     *
     * @param fileData File content as byte array
     * @param baseFileName File name WITHOUT extension
     * @param extension File extension WITHOUT dot
     * @param mimeType MIME type string (e.g., "image/jpeg")
     * @param saveLocationIndex Save location index from Dart enum (0-4)
     * @param subDir Optional subdirectory within target location
     * @param conflictMode Conflict resolution mode (0-3)
     * @return Flow of SaveProgressEvent
     */
    internal fun saveBytes(
        fileData: ByteArray,
        baseFileName: String,
        extension: String,
        mimeType: String,
        saveLocationIndex: Int,
        subDir: String?,
        conflictMode: Int,
    ): Flow<SaveProgressEvent> = flow {
        try {
            val fileType = FileType(extension, mimeType)
            val conflictResolution = ConflictResolution.fromInt(conflictMode)
            val saveLocation = SaveLocation.fromInt(saveLocationIndex)

            val saver = when {
                fileType.isImage -> imageSaver
                fileType.isVideo -> videoSaver
                fileType.isAudio -> audioSaver
                else -> customFileSaver
            }

            saver.saveBytes(
                fileData, fileType, baseFileName, saveLocation, subDir, conflictResolution
            ).collect { event ->
                emit(event)
            }
        } catch (e: Exception) {
            emit(SaveProgressEvent.Error(
                Constants.ERROR_PLATFORM,
                "Unexpected error: ${e.message ?: "Unknown error"}"
            ))
        }
    }.flowOn(Dispatchers.IO)

    /**
     * Saves file data with progress callback (for Dart consumption via JNI)
     *
     * @param fileData File content as byte array
     * @param baseFileName File name WITHOUT extension
     * @param extension File extension WITHOUT dot
     * @param mimeType MIME type string (e.g., "image/jpeg")
     * @param saveLocationIndex Save location index from Dart enum (0-4)
     * @param subDir Optional subdirectory within target location
     * @param conflictMode Conflict resolution mode (0-3)
     * @param callback Progress callback for events
     */
    fun saveBytes(
        fileData: ByteArray,
        baseFileName: String,
        extension: String,
        mimeType: String,
        saveLocationIndex: Int,
        subDir: String?,
        conflictMode: Int,
        callback: ProgressCallback,
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            saveBytes(
                fileData, baseFileName, extension, mimeType,
                saveLocationIndex, subDir, conflictMode
            ).collect { event ->
                when (event) {
                    is SaveProgressEvent.Started ->
                        callback.onEvent(0, 0.0, null, null)
                    is SaveProgressEvent.Progress ->
                        callback.onEvent(1, event.value, null, null)
                    is SaveProgressEvent.Error ->
                        callback.onEvent(2, 0.0, event.code, event.message)
                    is SaveProgressEvent.Success ->
                        callback.onEvent(3, 1.0, event.uri, null)
                    is SaveProgressEvent.Cancelled ->
                        callback.onEvent(4, 0.0, null, null)
                }
            }
        }
    }
}
