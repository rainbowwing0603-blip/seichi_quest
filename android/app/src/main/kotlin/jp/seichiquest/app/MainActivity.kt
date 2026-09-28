package jp.seichiquest.app

import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.content.ContentValues
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "jp.seichiquest.app/collection_card_gallery"
        ).setMethodCallHandler { call, result ->
            if (call.method != "savePng") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                result.error("UNSUPPORTED", "Android 10以上で写真保存に対応しています", null)
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            val name = call.argument<String>("name")
            if (bytes == null || name == null || !name.endsWith(".png")) {
                result.error("INVALID", "PNGデータがありません", null)
                return@setMethodCallHandler
            }
            savePng(bytes, name, "SeichiQuest", result)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "jp.seichiquest.app/media_studio_capture"
        ).setMethodCallHandler { call, result ->
            if (call.method != "capturePng") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            // Defense in depth: the Dart studio is a separate debug-only entry
            // point, and the native capture bridge also refuses non-debuggable
            // builds even if someone discovers the channel name.
            val debuggable =
                (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
            if (!debuggable) {
                result.error(
                    "DEBUG_ONLY",
                    "Media Studio capture is disabled in release builds",
                    null
                )
                return@setMethodCallHandler
            }

            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                result.error("UNSUPPORTED", "Android 8以上が必要です", null)
                return@setMethodCallHandler
            }

            val name = call.argument<String>("name")
            if (name == null || !name.endsWith(".png")) {
                result.error("INVALID", "PNGファイル名が不正です", null)
                return@setMethodCallHandler
            }

            captureWindowPng(name, result)
        }
    }

    private fun captureWindowPng(name: String, result: MethodChannel.Result) {
        val root = window.decorView.rootView
        val width = root.width
        val height = root.height
        if (width <= 0 || height <= 0) {
            result.error("CAPTURE_FAILED", "画面サイズを取得できません", null)
            return
        }

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        PixelCopy.request(
            window,
            bitmap,
            { copyResult ->
                if (copyResult != PixelCopy.SUCCESS) {
                    bitmap.recycle()
                    result.error(
                        "CAPTURE_FAILED",
                        "PixelCopy failed: $copyResult",
                        null
                    )
                    return@request
                }

                try {
                    val bytes = java.io.ByteArrayOutputStream().use { stream ->
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                        stream.toByteArray()
                    }
                    bitmap.recycle()
                    savePng(bytes, name, "SeichiQuest/MediaStudio", result)
                } catch (error: Exception) {
                    bitmap.recycle()
                    result.error("CAPTURE_FAILED", error.message, null)
                }
            },
            Handler(Looper.getMainLooper())
        )
    }

    private fun savePng(
        bytes: ByteArray,
        name: String,
        relativeFolder: String,
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("UNSUPPORTED", "Android 10以上で写真保存に対応しています", null)
            return
        }

        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(
                MediaStore.Images.Media.RELATIVE_PATH,
                Environment.DIRECTORY_PICTURES + "/" + relativeFolder
            )
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        if (uri == null) {
            result.error("SAVE_FAILED", "写真を作成できません", null)
            return
        }

        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("写真を開けません")
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            result.success(null)
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            result.error("SAVE_FAILED", error.message, null)
        }
    }
}
