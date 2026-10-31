package com.ansorstudi.drinkpos_lite

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ansorstudi.drinkpos_lite/device"
    private var incomingPackagePath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val uri: Uri = intent?.data ?: return
        try {
            var isDpos = false
            var fileName = "incoming_update_${System.currentTimeMillis()}.dpos"

            if (uri.scheme == "content") {
                try {
                    contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1 && cursor.moveToFirst()) {
                            val name = cursor.getString(nameIndex)
                            if (name != null) {
                                fileName = name
                                if (name.endsWith(".dpos", ignoreCase = true)) {
                                    isDpos = true
                                }
                            }
                        }
                    }
                } catch (_: Exception) {}
            } else if (uri.scheme == "file") {
                val path = uri.path ?: ""
                if (path.endsWith(".dpos", ignoreCase = true)) {
                    isDpos = true
                    uri.lastPathSegment?.let { fileName = it }
                }
            }

            val targetFile = File(cacheDir, "incoming_update_${System.currentTimeMillis()}.dpos")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }

            if (targetFile.exists() && targetFile.length() > 0) {
                // Verify magic prefix DPOS_V1# in case extension was stripped
                val headerBuffer = ByteArray(8)
                val readBytes = targetFile.inputStream().use { it.read(headerBuffer) }
                val headerStr = if (readBytes > 0) String(headerBuffer, 0, readBytes) else ""
                if (headerStr.startsWith("DPOS_V1") || isDpos || fileName.endsWith(".dpos", ignoreCase = true)) {
                    incomingPackagePath = targetFile.absolutePath
                    methodChannel?.invokeMethod("onIncomingPackageReceived", incomingPackagePath)
                } else {
                    targetFile.delete()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openBluetoothSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openWhatsApp" -> {
                    val phone = call.argument<String>("phone") ?: "081775700114"
                    val cleanPhone = if (phone.startsWith("0")) "62" + phone.substring(1) else phone
                    try {
                        val url = "https://wa.me/$cleanPhone"
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getIncomingPackagePath" -> {
                    val path = incomingPackagePath
                    incomingPackagePath = null
                    result.success(path)
                }
                else -> result.notImplemented()
            }
        }

        incomingPackagePath?.let { path ->
            methodChannel?.invokeMethod("onIncomingPackageReceived", path)
        }
    }
}
