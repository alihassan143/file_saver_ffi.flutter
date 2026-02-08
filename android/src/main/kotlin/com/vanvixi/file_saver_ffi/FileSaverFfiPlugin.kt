package com.vanvixi.file_saver_ffi

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener

/**
 * Flutter plugin for file_saver_ffi.
 *
 * Handles directory picker via Storage Access Framework (SAF).
 * This plugin is needed because launching system pickers requires an Activity.
 */
class FileSaverFfiPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, ActivityResultListener {
    companion object {
        private const val TAG = "FileSaverFfi"
        private const val CHANNEL_NAME = "com.vanvixi/file_saver_ffi"
        private const val REQUEST_CODE_PICK_DIRECTORY = 43891

        // Unique key for ActivityResultRegistry
        private const val PICKER_REGISTRY_KEY = "com.vanvixi.file_saver_ffi.dir_picker"
    }

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResult: Result? = null

    // Whether to persist permission for current picker operation
    private var shouldPersistPermission: Boolean = true

    // For ComponentActivity (AndroidX)
    private var directoryPickerLauncher: ActivityResultLauncher<Uri?>? = null

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
        setupActivityResultLauncher(binding.activity)
    }


    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
        directoryPickerLauncher?.unregister()
        directoryPickerLauncher = null
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
}
