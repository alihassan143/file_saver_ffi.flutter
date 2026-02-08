package com.vanvixi.file_saver_ffi

import android.content.Context
import com.vanvixi.file_saver_ffi.core.*
import com.vanvixi.file_saver_ffi.models.*
import com.vanvixi.file_saver_ffi.utils.Constants
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

class FileSaver(private val context: Context) {
    private val imageSaver = ImageSaver(context)
    private val videoSaver = VideoSaver(context)
    private val audioSaver = AudioSaver(context)
    private val customFileSaver = CustomFileSaver(context)

    // Job tracking for cancellation support
    private val activeJobs = ConcurrentHashMap<Long, Job>()
    private val operationIdCounter = AtomicLong(0)

    /**
     * Cancels an ongoing save operation.
     *
     * @param operationId The operation ID returned by saveBytes, saveFile, or saveNetwork
     */
    fun cancelOperation(operationId: Long) {
        activeJobs[operationId]?.cancel()
    }

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

            saver.saveBytes(fileData, fileType, baseFileName, saveLocation, subDir, conflictResolution)
                .collect { event -> emit(event) }
        } catch (e: Exception) {
            emit(
                SaveProgressEvent.Error(
                    Constants.ERROR_PLATFORM,
                    "Unexpected error: ${e.message ?: "Unknown error"}",
                )
            )
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
     * @return Operation ID for cancellation
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
    ): Long {
        val operationId = operationIdCounter.incrementAndGet()

        val job = CoroutineScope(Dispatchers.IO).launch {
            saveBytes(
                fileData,
                baseFileName,
                extension,
                mimeType,
                saveLocationIndex,
                subDir,
                conflictMode,
            ).collect { event ->
                when (event) {
                    is SaveProgressEvent.Started -> callback.onEvent(0, 0.0, null, null)

                    is SaveProgressEvent.Progress -> callback.onEvent(1, event.value, null, null)

                    is SaveProgressEvent.Error -> callback.onEvent(2, 0.0, event.code, event.message)

                    is SaveProgressEvent.Success -> callback.onEvent(3, 1.0, event.uri, null)

                    is SaveProgressEvent.Cancelled -> callback.onEvent(4, 0.0, null, null)
                }
            }
        }

        activeJobs[operationId] = job
        job.invokeOnCompletion { activeJobs.remove(operationId) }

        return operationId
    }

    /**
     * Saves file from source path with progress streaming (internal)
     *
     * @param filePath Source file path (file:// or content:// URI)
     * @param baseFileName File name WITHOUT extension
     * @param extension File extension WITHOUT dot
     * @param mimeType MIME type string (e.g., "image/jpeg")
     * @param saveLocationIndex Save location index from Dart enum (0-4)
     * @param subDir Optional subdirectory within target location
     * @param conflictMode Conflict resolution mode (0-3)
     * @return Flow of SaveProgressEvent
     */
    internal fun saveFile(
        filePath: String,
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

            saver.saveFile(filePath, fileType, baseFileName, saveLocation, subDir, conflictResolution)
                .collect { event -> emit(event) }
        } catch (e: Exception) {
            emit(
                SaveProgressEvent.Error(
                    Constants.ERROR_PLATFORM,
                    "Unexpected error: ${e.message ?: "Unknown error"}",
                )
            )
        }
    }.flowOn(Dispatchers.IO)

    /**
     * Saves file from source path with progress callback (for Dart consumption via JNI)
     *
     * @param filePath Source file path (file:// or content:// URI)
     * @param baseFileName File name WITHOUT extension
     * @param extension File extension WITHOUT dot
     * @param mimeType MIME type string (e.g., "image/jpeg")
     * @param saveLocationIndex Save location index from Dart enum (0-4)
     * @param subDir Optional subdirectory within target location
     * @param conflictMode Conflict resolution mode (0-3)
     * @param callback Progress callback for events
     * @return Operation ID for cancellation
     */
    fun saveFile(
        filePath: String,
        baseFileName: String,
        extension: String,
        mimeType: String,
        saveLocationIndex: Int,
        subDir: String?,
        conflictMode: Int,
        callback: ProgressCallback,
    ): Long {
        val operationId = operationIdCounter.incrementAndGet()

        val job = CoroutineScope(Dispatchers.IO).launch {
            saveFile(
                filePath,
                baseFileName,
                extension,
                mimeType,
                saveLocationIndex,
                subDir,
                conflictMode
            ).collect { event ->
                when (event) {
                    is SaveProgressEvent.Started -> callback.onEvent(0, 0.0, null, null)

                    is SaveProgressEvent.Progress -> callback.onEvent(1, event.value, null, null)

                    is SaveProgressEvent.Error -> callback.onEvent(2, 0.0, event.code, event.message)

                    is SaveProgressEvent.Success -> callback.onEvent(3, 1.0, event.uri, null)

                    is SaveProgressEvent.Cancelled -> callback.onEvent(4, 0.0, null, null)
                }
            }
        }

        activeJobs[operationId] = job
        job.invokeOnCompletion { activeJobs.remove(operationId) }

        return operationId
    }

    /**
     * Downloads file from network URL and saves directly to storage (internal)
     *
     * @param url Network URL to download from
     * @param headersJson Optional JSON string of HTTP headers
     * @param timeoutMs Timeout in milliseconds for network connection
     * @param baseFileName File name WITHOUT extension
     * @param extension File extension WITHOUT dot
     * @param mimeType MIME type string (e.g., "image/jpeg")
     * @param saveLocationIndex Save location index from Dart enum (0-4)
     * @param subDir Optional subdirectory within target location
     * @param conflictMode Conflict resolution mode (0-3)
     * @return Flow of SaveProgressEvent
     */
    internal fun saveNetwork(
        url: String,
        headersJson: String?,
        timeoutMs: Int,
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

            saver.saveNetwork(
                url, headersJson, timeoutMs,
                fileType, baseFileName, saveLocation, subDir, conflictResolution,
            ).collect { event -> emit(event) }
        } catch (e: Exception) {
            emit(
                SaveProgressEvent.Error(
                    Constants.ERROR_PLATFORM,
                    "Unexpected error: ${e.message ?: "Unknown error"}",
                )
            )
        }
    }.flowOn(Dispatchers.IO)

    /**
     * Downloads file from network URL and saves directly to storage (for Dart consumption via JNI)
     *
     * @param url Network URL to download from
     * @param headersJson Optional JSON string of HTTP headers
     * @param timeoutMs Timeout in milliseconds for network connection
     * @param baseFileName File name WITHOUT extension
     * @param extension File extension WITHOUT dot
     * @param mimeType MIME type string (e.g., "image/jpeg")
     * @param saveLocationIndex Save location index from Dart enum (0-4)
     * @param subDir Optional subdirectory within target location
     * @param conflictMode Conflict resolution mode (0-3)
     * @param callback Progress callback for events
     * @return Operation ID for cancellation
     */
    fun saveNetwork(
        url: String,
        headersJson: String?,
        timeoutMs: Int,
        baseFileName: String,
        extension: String,
        mimeType: String,
        saveLocationIndex: Int,
        subDir: String?,
        conflictMode: Int,
        callback: ProgressCallback,
    ): Long {
        val operationId = operationIdCounter.incrementAndGet()

        val job = CoroutineScope(Dispatchers.IO).launch {
            saveNetwork(
                url,
                headersJson,
                timeoutMs,
                baseFileName,
                extension,
                mimeType,
                saveLocationIndex,
                subDir,
                conflictMode,
            ).collect { event ->
                when (event) {
                    is SaveProgressEvent.Started -> callback.onEvent(0, 0.0, null, null)

                    is SaveProgressEvent.Progress -> callback.onEvent(1, event.value, null, null)

                    is SaveProgressEvent.Error -> callback.onEvent(2, 0.0, event.code, event.message)

                    is SaveProgressEvent.Success -> callback.onEvent(3, 1.0, event.uri, null)

                    is SaveProgressEvent.Cancelled -> callback.onEvent(4, 0.0, null, null)
                }
            }
        }

        activeJobs[operationId] = job
        job.invokeOnCompletion { activeJobs.remove(operationId) }

        return operationId
    }

    /**
     * Cancels an ongoing save operation.
     *
     * @param operationId The operation ID returned by saveBytes, saveFile, or saveNetwork
     */
    fun cancelOperation(operationId: Long) {
        activeJobs[operationId]?.cancel()
    }
}
