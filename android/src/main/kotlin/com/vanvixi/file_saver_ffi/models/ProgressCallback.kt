package com.vanvixi.file_saver_ffi.models

/**
 * Callback interface for progress events from Dart via JNI
 *
 * Message protocol:
 * - eventType 0: Started (no other params)
 * - eventType 1: Progress (progress = 0.0-1.0)
 * - eventType 2: Error (data = errorCode, message = errorMessage)
 * - eventType 3: Success (data = fileUri)
 * - eventType 4: Cancelled (no other params)
 */
interface ProgressCallback {
    /**
     * Called for each progress event
     *
     * @param eventType 0=Started, 1=Progress, 2=Error, 3=Success, 4=Cancelled
     * @param progress Progress value (0.0-1.0) for eventType=1
     * @param data String data: URI for Success, errorCode for Error
     * @param message Error message for eventType=2
     */
    fun onEvent(eventType: Int, progress: Double, data: String?, message: String?)
}
