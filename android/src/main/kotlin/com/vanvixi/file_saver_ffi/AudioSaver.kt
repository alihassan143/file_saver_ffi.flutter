package com.vanvixi.file_saver_ffi

import android.content.Context
import com.vanvixi.file_saver_ffi.exception.UnsupportedFormatException
import com.vanvixi.file_saver_ffi.models.ConflictResolution
import com.vanvixi.file_saver_ffi.models.FileType
import com.vanvixi.file_saver_ffi.models.SaveLocation
import com.vanvixi.file_saver_ffi.models.SaveProgressEvent
import com.vanvixi.file_saver_ffi.utils.Constants
import com.vanvixi.file_saver_ffi.utils.FormatValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn

class AudioSaver(context: Context) : BaseFileSaver(context) {

    override fun saveBytes(
        fileData: ByteArray,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
    ): Flow<SaveProgressEvent> = flow {
        try {
            FormatValidator.validateAudioFormat(fileType)
        } catch (e: UnsupportedFormatException) {
            emit(
                SaveProgressEvent.Error(
                    Constants.ERROR_UNSUPPORTED_FORMAT,
                    e.message ?: "Unsupported format: ${fileType.ext}"
                )
            )
            return@flow
        }

        super.saveBytes(fileData, fileType, baseFileName, saveLocation, subDir, conflictResolution)
            .collect { event -> emit(event) }
    }.flowOn(Dispatchers.IO)

    override fun saveFile(
        filePath: String,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
    ): Flow<SaveProgressEvent> = flow {
        try {
            FormatValidator.validateAudioFormat(fileType)
        } catch (e: UnsupportedFormatException) {
            emit(
                SaveProgressEvent.Error(
                    Constants.ERROR_UNSUPPORTED_FORMAT,
                    e.message ?: "Unsupported format: ${fileType.ext}",
                )
            )
            return@flow
        }

        super.saveFile(filePath, fileType, baseFileName, saveLocation, subDir, conflictResolution)
            .collect { event -> emit(event) }
    }.flowOn(Dispatchers.IO)

    override fun saveNetwork(
        url: String,
        headersJson: String?,
        timeoutMs: Int,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
    ): Flow<SaveProgressEvent> = flow {
        try {
            FormatValidator.validateAudioFormat(fileType)
        } catch (e: UnsupportedFormatException) {
            emit(
                SaveProgressEvent.Error(
                    Constants.ERROR_UNSUPPORTED_FORMAT,
                    e.message ?: "Unsupported format: ${fileType.ext}",
                )
            )
            return@flow
        }

        super.saveNetwork(
            url, headersJson, timeoutMs,
            fileType, baseFileName, saveLocation, subDir, conflictResolution,
        ).collect { event -> emit(event) }
    }.flowOn(Dispatchers.IO)
}
