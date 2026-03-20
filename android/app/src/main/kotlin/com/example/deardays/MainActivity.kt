package com.example.deardays

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.deardays/social_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.error("INVALID_ARGS", "bytes is required", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "shareToInstagram" -> shareToApp(
                        bytes,
                        packageName = "com.instagram.android",
                        action = "com.instagram.android.intent.action.SEND",
                        result,
                    )
                    "shareToWhatsApp" -> shareToApp(
                        bytes,
                        packageName = "com.whatsapp",
                        action = Intent.ACTION_SEND,
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun shareToApp(
        bytes: ByteArray,
        packageName: String,
        action: String,
        result: MethodChannel.Result,
    ) {
        // 1. Check the target app is installed.
        try {
            applicationContext.packageManager.getPackageInfo(packageName, 0)
        } catch (e: PackageManager.NameNotFoundException) {
            result.error("APP_NOT_INSTALLED", "$packageName is not installed", null)
            return
        }

        try {
            // 2. Write PNG bytes to a temp file in the app cache dir.
            val cacheDir = File(applicationContext.cacheDir, "share_images")
            cacheDir.mkdirs()
            val file = File(cacheDir, "deardays_share_${System.currentTimeMillis()}.png")
            file.writeBytes(bytes)

            // 3. Get a content:// URI via FileProvider (required on Android 7+).
            val contentUri: Uri = FileProvider.getUriForFile(
                applicationContext,
                "${applicationContext.packageName}.fileprovider",
                file,
            )

            // 4. Fire an explicit intent aimed at the target app.
            val intent = Intent(action).apply {
                setPackage(packageName)
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, contentUri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            applicationContext.startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("SHARE_FAILED", e.message, null)
        }
    }
}
