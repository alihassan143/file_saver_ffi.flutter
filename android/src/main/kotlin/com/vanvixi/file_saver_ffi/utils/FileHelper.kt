package com.vanvixi.file_saver_ffi.utils

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.OutputStream

object FileHelper {
    /**
     * Ensures directory exists, creating it if necessary
     *
     * @param directory Directory to ensure exists
     * @return Result with success or error
     *
     */
    suspend fun ensureDirectoryExists(directory: File): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            when {
                // Directory already exists
                directory.exists() && directory.isDirectory -> {
                    Result.success(Unit)
                }
                // Path exists but is a file (not directory)
                directory.exists() && !directory.isDirectory -> {
                    Result.failure(
                        IllegalStateException("Path exists but is not a directory: ${directory.absolutePath}")
                    )
                }
                // Directory doesn't exist - create it
                else -> {
                    val created = directory.mkdirs()
                    if (created || directory.exists()) {
                        Result.success(Unit)
                    } else {
                        Result.failure(
                            IllegalStateException("Failed to create directory: ${directory.absolutePath}")
                        )
                    }
                }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Builds full file name with extension
     *
     * @param fileName File name without extension
     * @param extension File extension
     * @return Full file name
     *
     * Examples:
     * - ("video", "mp4") → "video.mp4"
     * - ("video", ".mp4") → "video.mp4"
     * - ("video.backup", "mp4") → "video.backup.mp4"
     */
    fun buildFileName(fileName: String, extension: String): String {
        val ext = extension.removePrefix(".").trim()
        return if (ext.isNotEmpty()) {
            "$fileName.$ext"
        } else {
            fileName
        }
    }

    /**
     * Writes data to output stream
     *
     * @param outputStream Output stream from MediaStore
     * @param data File data to write
     * @param onProgress Optional callback receiving progress from 0.0 to 1.0
     */
    suspend fun writeStream(
        outputStream: OutputStream,
        data: ByteArray,
        onProgress: ((Double) -> Unit)?,
    ) = withContext(Dispatchers.IO) {
        outputStream.use { stream ->
            var bytesWritten = 0L
            val chunkSize = Constants.CHUNK_SIZE
            val totalBytes = data.size.toLong()

            while (bytesWritten < totalBytes) {
                // Calculate chunk size
                val remainingBytes = (totalBytes - bytesWritten).toInt()
                val currentChunkSize = minOf(remainingBytes, chunkSize)

                // Write chunk
                stream.write(data, bytesWritten.toInt(), currentChunkSize)

                // Update progress
                bytesWritten += currentChunkSize

                // Report progress (0.0 to 1.0)
                if (onProgress != null) {
                    val progress = bytesWritten.toDouble() / totalBytes.toDouble()
                    onProgress(progress)
                }
            }

            // Flush stream
            stream.flush()
        }
    }
}
