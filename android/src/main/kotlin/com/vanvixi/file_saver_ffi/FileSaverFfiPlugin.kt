package com.vanvixi.file_saver_ffi

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.vanvixi.file_saver_ffi.utils.StoragePermissionHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume

/**
 * Flutter plugin for file_saver_ffi.
 *
 * Handles:
 * - Directory picker via Storage Access Framework (SAF)
 * - WRITE_EXTERNAL_STORAGE runtime permission for Android 9 and below
 *
 * This plugin is needed because these operations require an Activity.
 */
class FileSaverFfiPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    ActivityResultListener, RequestPermissionsResultListener {

    companion object {
        private const val TAG = "FileSaverFfi"
        private const val CHANNEL_NAME = "com.vanvixi/file_saver_ffi"
        private const val REQUEST_CODE_PICK_DIRECTORY = 43891
        private const val REQUEST_CODE_STORAGE_PERMISSION = 43892

        // Unique keys for ActivityResultRegistry
        private const val PICKER_REGISTRY_KEY = "com.vanvixi.file_saver_ffi.dir_picker"
        private const val PERMISSION_REGISTRY_KEY = "com.vanvixi.file_saver_ffi.storage_perm"
    }

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResult: Result? = null

    // Whether to persist permission for current picker operation
    private var shouldPersistPermission: Boolean = true

    // For ComponentActivity (AndroidX)
    private var directoryPickerLauncher: ActivityResultLauncher<Uri?>? = null

    // Storage permission handling
    private var permissionLauncher: ActivityResultLauncher<String>? = null
    private var pendingPermissionContinuation: CancellableContinuation<Boolean>? = null

    // ─────────────────────────────────────────────────────────────────────────
    // FlutterPlugin
    // ─────────────────────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MethodCallHandler
    // ─────────────────────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "pickDirectory" -> {
                val shouldPersist = call.argument<Boolean>("shouldPersist") ?: true
                pickDirectory(shouldPersist, result)
            }

            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Directory Picker
    // ─────────────────────────────────────────────────────────────────────────

    private fun pickDirectory(shouldPersist: Boolean, result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        if (pendingResult != null) {
            result.error("ALREADY_ACTIVE", "Another directory picker is already active", null)
            return
        }

        pendingResult = result
        shouldPersistPermission = shouldPersist

        // Try using ActivityResultLauncher if available (ComponentActivity)
        val launcher = directoryPickerLauncher
        if (launcher != null) {
            try {
                launcher.launch(null)
                return
            } catch (_: Exception) {
                // Fall back to startActivityForResult
            }
        }

        // Fallback: Use startActivityForResult for non-ComponentActivity
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
            currentActivity.startActivityForResult(intent, REQUEST_CODE_PICK_DIRECTORY)
        } catch (e: Exception) {
            pendingResult = null
            result.error("PICKER_ERROR", "Failed to launch directory picker: ${e.message}", null)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ActivityAware
    // ─────────────────────────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attachActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attachActivity(binding)

    override fun onDetachedFromActivity() = detachActivity()

    private fun attachActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
        setupActivityResultLauncher(binding.activity)
        setupPermissionLauncher(binding.activity)
        setupStoragePermissionHandler()
    }

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null

        directoryPickerLauncher?.unregister()
        directoryPickerLauncher = null

        permissionLauncher?.unregister()
        permissionLauncher = null

        FileSaver.storagePermissionHandler = null
        pendingPermissionContinuation?.let { if (it.isActive) it.resume(false) }
        pendingPermissionContinuation = null
    }

    private fun setupActivityResultLauncher(activity: Activity) {
        if (activity !is ComponentActivity) {
            return
        }

        directoryPickerLauncher = activity.activityResultRegistry.register(
            PICKER_REGISTRY_KEY,
            ActivityResultContracts.OpenDocumentTree()
        ) { uri: Uri? ->
            handlePickerResult(uri)
        }
    }

    private fun handlePickerResult(uri: Uri?) {
        val result = pendingResult
        val shouldPersist = shouldPersistPermission

        // Reset state
        pendingResult = null
        shouldPersistPermission = true

        if (result == null) return

        if (uri == null) {
            // User cancelled
            result.success(null)
            return
        }

        // Persist permission if requested
        if (shouldPersist) {
            try {
                val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                activity?.contentResolver?.takePersistableUriPermission(uri, takeFlags)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to persist permission: ${e.message}")
            }
        }
        result.success(uri.toString())
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ActivityResultListener (fallback for non-ComponentActivity)
    // ─────────────────────────────────────────────────────────────────────────

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_PICK_DIRECTORY) {
            return false
        }

        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        handlePickerResult(uri)
        return true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Storage Permission (Android 9 and below)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Sets up ActivityResultLauncher for WRITE_EXTERNAL_STORAGE permission request.
     * Only registers on ComponentActivity (AndroidX).
     */
    private fun setupPermissionLauncher(activity: Activity) {
        if (activity !is ComponentActivity) return

        permissionLauncher = activity.activityResultRegistry.register(
            PERMISSION_REGISTRY_KEY,
            ActivityResultContracts.RequestPermission()
        ) { isGranted: Boolean ->
            handlePermissionResult(isGranted)
        }
    }

    /**
     * Registers a [StoragePermissionHandler] on [FileSaver] that transparently
     * requests WRITE_EXTERNAL_STORAGE when needed (API < 29).
     *
     * The handler:
     * 1. Checks if permission is already granted (early return)
     * 2. Switches to Main thread to show permission dialog
     * 3. Suspends until user responds via [suspendCancellableCoroutine]
     */
    private fun setupStoragePermissionHandler() {
        FileSaver.storagePermissionHandler = StoragePermissionHandler {
            val currentActivity = activity ?: return@StoragePermissionHandler false

            // Double-check: might have been granted since FileSaver checked
            if (ContextCompat.checkSelfPermission(
                    currentActivity,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                return@StoragePermissionHandler true
            }

            // Must launch permission dialog on Main thread
            withContext(Dispatchers.Main) {
                suspendCancellableCoroutine { continuation ->
                    pendingPermissionContinuation = continuation

                    continuation.invokeOnCancellation {
                        pendingPermissionContinuation = null
                    }

                    // Try modern launcher first (ComponentActivity)
                    val launcher = permissionLauncher
                    if (launcher != null) {
                        try {
                            launcher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                            return@suspendCancellableCoroutine
                        } catch (e: Exception) {
                            Log.w(TAG, "Permission launcher failed, falling back: ${e.message}")
                        }
                    }

                    // Fallback: ActivityCompat for non-ComponentActivity
                    val act = activity
                    if (act != null) {
                        ActivityCompat.requestPermissions(
                            act,
                            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            REQUEST_CODE_STORAGE_PERMISSION
                        )
                    } else {
                        pendingPermissionContinuation = null
                        continuation.resume(false)
                    }
                }
            }
        }
    }

    private fun handlePermissionResult(isGranted: Boolean) {
        val continuation = pendingPermissionContinuation
        pendingPermissionContinuation = null
        if (continuation != null && continuation.isActive) {
            continuation.resume(isGranted)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RequestPermissionsResultListener (fallback for non-ComponentActivity)
    // ─────────────────────────────────────────────────────────────────────────

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_CODE_STORAGE_PERMISSION) return false

        val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
        handlePermissionResult(granted)
        return true
    }
}
