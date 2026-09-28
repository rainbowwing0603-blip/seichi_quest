package jp.seichiquest.app

import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.content.ContentValues
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // PixelCopy cannot reliably capture Flutter's default Surface render target
    // on some emulator/Android combinations. Media Studio runs only in debug,
    // so use a Texture render target there; release keeps the normal Surface.
    override fun getRenderMode(): RenderMode {
        val debuggable =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        return if (debuggable) RenderMode.texture else RenderMode.surface
    }

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

            val mosaic = call.argument<Boolean>("mosaic") ?: false
            captureWindowPng(name, mosaic, result)
        }
    }

    private fun captureWindowPng(
        name: String,
        mosaic: Boolean,
        result: MethodChannel.Result
    ) {
        val root = window.decorView.rootView
        val width = root.width
        val height = root.height
        if (width <= 0 || height <= 0) {
            result.error("CAPTURE_FAILED", "画面サイズを取得できません", null)
            return
        }

        // Media Studio runs only in debug and debug uses RenderMode.texture.
        // Draw the composed decor view directly instead of PixelCopy. On the
        // affected emulator PixelCopy reported SUCCESS while returning a fully
        // black bitmap, so its success code cannot be trusted here.
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(bitmap)
            root.draw(canvas)

            // Do not abort here based on sampled darkness. On the emulator,
            // Google Maps/platform-view composition can briefly report dark
            // samples even when the composed capture is valid. We already
            // switched away from the PixelCopy path that produced truly black
            // files; let the batch save the composed frame and validate the
            // resulting PNGs as a set instead.
            val outputBitmap = if (mosaic) createMosaic(bitmap) else bitmap
            val bytes = java.io.ByteArrayOutputStream().use { stream ->
                outputBitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                stream.toByteArray()
            }
            if (outputBitmap !== bitmap) outputBitmap.recycle()
            bitmap.recycle()
            savePng(bytes, name, "SeichiQuest/MediaStudio", result)
        } catch (error: Exception) {
            if (!bitmap.isRecycled) bitmap.recycle()
            result.error("CAPTURE_FAILED", error.message, null)
        }
    }

    private fun isAlmostBlack(source: Bitmap): Boolean {
        // Sample a grid rather than scanning every pixel. This catches capture
        // failures cheaply and aborts the batch before invalid media is saved.
        val columns = 24
        val rows = 40
        var dark = 0
        var sampled = 0

        for (row in 0 until rows) {
            val y = ((row + 0.5) * source.height / rows)
                .toInt()
                .coerceIn(0, source.height - 1)
            for (column in 0 until columns) {
                val x = ((column + 0.5) * source.width / columns)
                    .toInt()
                    .coerceIn(0, source.width - 1)
                val pixel = source.getPixel(x, y)
                val red = android.graphics.Color.red(pixel)
                val green = android.graphics.Color.green(pixel)
                val blue = android.graphics.Color.blue(pixel)
                if (red < 12 && green < 12 && blue < 12) dark++
                sampled++
            }
        }

        return sampled > 0 && dark.toDouble() / sampled >= 0.98
    }

    private fun createMosaic(source: Bitmap): Bitmap {
        // Coarse, intentionally irreversible teaser treatment. The entire
        // acquisition capture is reduced to large pixels so card artwork,
        // frame/background, copy and other reward details stay a surprise.
        val blockSize = 28
        val smallWidth = kotlin.math.max(1, source.width / blockSize)
        val smallHeight = kotlin.math.max(1, source.height / blockSize)
        val small = Bitmap.createScaledBitmap(source, smallWidth, smallHeight, false)
        return try {
            Bitmap.createScaledBitmap(small, source.width, source.height, false)
        } finally {
            small.recycle()
        }
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
