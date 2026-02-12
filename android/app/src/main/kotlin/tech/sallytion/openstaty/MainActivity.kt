package tech.sallytion.openstaty

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "tech.sallytion.openstaty/share"
    private var sharedFilePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedFile" -> {
                    result.success(sharedFilePath)
                    sharedFilePath = null // Clear after sending
                }
                else -> result.notImplemented()
            }
        }

        // Handle the intent that launched the activity
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.action == Intent.ACTION_SEND) {
            val uri: Uri? = intent.getParcelableExtra(Intent.EXTRA_STREAM)
            if (uri != null) {
                // Copy the shared file to app's cache directory so Flutter can access it
                val path = copyFileToCache(uri)
                if (path != null) {
                    sharedFilePath = path
                    // Notify Flutter side if the engine is already running
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, CHANNEL).invokeMethod("onSharedFile", path)
                    }
                }
            } else {
                // Some apps share text content directly via EXTRA_TEXT
                val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (sharedText != null) {
                    // Save text to a temp file
                    val tempFile = File(cacheDir, "shared_chat.txt")
                    tempFile.writeText(sharedText)
                    sharedFilePath = tempFile.absolutePath
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, CHANNEL).invokeMethod("onSharedFile", tempFile.absolutePath)
                    }
                }
            }
        }
    }

    private fun copyFileToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            // Determine file name from URI
            var fileName = "shared_file"
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        fileName = it.getString(nameIndex)
                    }
                }
            }
            val outputFile = File(cacheDir, fileName)
            FileOutputStream(outputFile).use { outputStream ->
                inputStream.copyTo(outputStream)
            }
            inputStream.close()
            outputFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
