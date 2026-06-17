package com.example.songhut

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "audiomark/import"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getSdkInt") {
                    result.success(Build.VERSION.SDK_INT)
                } else if (call.method == "importToMusic") {
                    val path = call.argument<String>("path")
                    val name = call.argument<String>("name")
                    if (path == null || name == null) {
                        result.error("ARG", "Missing path or name", null)
                        return@setMethodCallHandler
                    }
                    try {
                        importToMusic(path, name)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("IMPORT", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    // Copies a picked audio file into the shared Music collection via MediaStore
    // so it shows up in the library like any other on-device song.
    private fun importToMusic(path: String, name: String) {
        val src = File(path)
        val resolver = contentResolver
        val mime = when (name.substringAfterLast('.', "").lowercase()) {
            "m4a", "mp4", "aac" -> "audio/mp4"
            "wav" -> "audio/x-wav"
            else -> "audio/mpeg"
        }
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, name)
            put(MediaStore.Audio.Media.MIME_TYPE, mime)
            put(MediaStore.Audio.Media.IS_MUSIC, 1)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Audio.Media.RELATIVE_PATH, Environment.DIRECTORY_MUSIC)
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
        }
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
        val uri = resolver.insert(collection, values)
            ?: throw Exception("Could not create media entry")
        resolver.openOutputStream(uri).use { out ->
            src.inputStream().use { input -> input.copyTo(out!!) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Audio.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
    }
}
