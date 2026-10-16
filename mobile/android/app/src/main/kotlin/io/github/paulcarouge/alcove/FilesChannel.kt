package io.github.paulcarouge.alcove

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Files opened in the app's viewers (channel "alcove/files"):
 * - PDF pages rendered to PNG with Android's own PdfRenderer (no extra library);
 * - "Open with…" and "Share" through the system chooser, with a FileProvider URI (read-only grant);
 * - "Download" into the public Downloads/Alcove folder (MediaStore, Android 10+).
 * Only files inside the app cache's viewer/ folder are handed out (see res/xml/update_paths.xml).
 */
class FilesChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "alcove/files")

    // PdfRenderer is not thread-safe: every PDF call runs on this one thread, in order.
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val docs = HashMap<Int, Pair<ParcelFileDescriptor, PdfRenderer>>()

    // Copies to Downloads run apart, so a large file never delays the pages being read.
    private val io = Executors.newSingleThreadExecutor()
    private var nextId = 1

    init {
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    private val authority get() = "${activity.packageName}.updates"

    private fun uriFor(path: String): Uri = FileProvider.getUriForFile(activity, authority, File(path))

    /** Runs [work] on the worker and always answers, even after an OutOfMemoryError. */
    private fun background(
        result: MethodChannel.Result,
        executor: java.util.concurrent.Executor = worker,
        work: () -> Any?,
    ) {
        executor.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Throwable) {
                main.post { result.error("failed", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    /**
     * The type other apps are told (same rules as handOutMime in lib/core/file_names.dart): the
     * extension wins when the system knows it, and an installable package is never announced as
     * one, so a shared or opened file can't launch the package installer.
     */
    private fun safeMime(path: String, asked: String?): String {
        val generic = "application/octet-stream"
        val name = File(path).name.lowercase()
        val ext = name.substringAfterLast('.', "")
        val fromExt = if (ext.isEmpty()) null else MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
        val mime = (fromExt ?: asked?.substringBefore(';')?.trim()?.lowercase()).orEmpty()
        return when {
            ext == "apk" || ext == "apks" || ext == "xapk" -> generic
            mime.contains("android.package-archive") -> generic
            mime.isEmpty() || mime.contains('*') -> generic
            else -> mime
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pdfOpen" -> {
                val path = call.argument<String>("path") ?: return result.error("bad_args", "path", null)
                background(result) {
                    val fd = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
                    val renderer = try {
                        PdfRenderer(fd)
                    } catch (e: Exception) {
                        fd.close()
                        throw e
                    }
                    if (renderer.pageCount > MAX_PAGES) {
                        renderer.close()
                        fd.close()
                        throw IllegalStateException("too many pages")
                    }
                    // Page sizes, within a time budget: a hostile document can't hold pdfOpen.
                    // Pages not measured in time take the size of the last one measured.
                    val started = System.nanoTime()
                    val sizes = ArrayList<List<Int>>(renderer.pageCount)
                    try {
                        for (i in 0 until renderer.pageCount) {
                            val over = System.nanoTime() - started > SIZE_BUDGET_NANOS
                            sizes.add(
                                if (over && sizes.isNotEmpty()) sizes.last()
                                else renderer.openPage(i).use { listOf(it.width.coerceAtLeast(1), it.height.coerceAtLeast(1)) },
                            )
                        }
                    } catch (e: Throwable) {
                        // A broken page: nothing stays open.
                        renderer.close()
                        fd.close()
                        throw e
                    }
                    val id = nextId++
                    docs[id] = fd to renderer
                    mapOf("id" to id, "pages" to sizes)
                }
            }
            "pdfRender" -> {
                val id = call.argument<Int>("id") ?: return result.error("bad_args", "id", null)
                val index = call.argument<Int>("page") ?: return result.error("bad_args", "page", null)
                val asked = call.argument<Int>("width") ?: return result.error("bad_args", "width", null)
                background(result) {
                    val renderer = docs[id]?.second ?: throw IllegalStateException("closed")
                    renderer.openPage(index).use { page ->
                        // At most 4096 px wide and 12 MP, whatever the zoom or the page shape.
                        var width = asked.coerceIn(64, 4096)
                        val pw = page.width.coerceAtLeast(1)
                        var height = (width.toLong() * page.height / pw).coerceIn(1, 16_384).toInt()
                        val maxPixels = MAX_PIXELS
                        if (width.toLong() * height > maxPixels) {
                            val f = Math.sqrt(maxPixels.toDouble() / (width.toLong() * height))
                            width = (width * f).toInt().coerceAtLeast(1)
                            height = (height * f).toInt().coerceAtLeast(1)
                        }
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        val out = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                        bitmap.recycle()
                        out.toByteArray()
                    }
                }
            }
            "pdfClose" -> {
                val id = call.argument<Int>("id") ?: return result.error("bad_args", "id", null)
                background(result) {
                    docs.remove(id)?.let { (fd, renderer) ->
                        renderer.close()
                        fd.close()
                    }
                    null
                }
            }
            "openWith" -> {
                val path = call.argument<String>("path") ?: return result.error("bad_args", "path", null)
                val mime = safeMime(path, call.argument<String>("mime"))
                val title = call.argument<String>("title") ?: ""
                val uri = try {
                    uriFor(path)
                } catch (e: IllegalArgumentException) {
                    return result.error("bad_args", "not a viewer file", null) // outside cache/viewer
                }
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mime)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                result.success(start(Intent.createChooser(intent, title)))
            }
            "share" -> {
                val paths = call.argument<List<String>>("paths") ?: return result.error("bad_args", "paths", null)
                val mime = paths.map { safeMime(it, call.argument<String>("mime")) }.distinct()
                    .singleOrNull() ?: "*/*"
                val title = call.argument<String>("title") ?: ""
                val uris = try {
                    ArrayList(paths.map { uriFor(it) })
                } catch (e: IllegalArgumentException) {
                    return result.error("bad_args", "not a viewer file", null)
                }
                if (uris.isEmpty()) return result.success(false)
                val intent = if (uris.size == 1) {
                    Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris[0])
                } else {
                    Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                }
                intent.type = mime
                // The grant follows the clip data to the app the user picks.
                intent.clipData = ClipData.newRawUri("", uris[0]).apply {
                    uris.drop(1).forEach { addItem(ClipData.Item(it)) }
                }
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                result.success(start(Intent.createChooser(intent, title)))
            }
            "saveToDownloads" -> {
                val path = call.argument<String>("path") ?: return result.error("bad_args", "path", null)
                val name = ShareChannel.safeName(call.argument<String>("name") ?: File(path).name)
                val mime = safeMime(name, call.argument<String>("mime"))
                // Only files of the viewer cache are copied out.
                val viewer = File(activity.cacheDir, "viewer").canonicalPath + File.separator
                if (!File(path).canonicalPath.startsWith(viewer)) return result.error("bad_args", "not a viewer file", null)
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return result.success(false)
                background(result, io) {
                    val resolver = activity.contentResolver
                    val values = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                        put(MediaStore.MediaColumns.MIME_TYPE, mime)
                        put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/Alcove")
                        put(MediaStore.MediaColumns.IS_PENDING, 1)
                    }
                    val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                        ?: throw IllegalStateException("insert")
                    try {
                        resolver.openOutputStream(uri)!!.use { out -> File(path).inputStream().use { it.copyTo(out) } }
                        resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
                    } catch (e: Exception) {
                        resolver.delete(uri, null, null)
                        throw e
                    }
                    true
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun start(intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    }

    companion object {
        private const val MAX_PAGES = 5000
        private const val MAX_PIXELS = 12_000_000L
        private const val SIZE_BUDGET_NANOS = 3_000_000_000L
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.execute {
            docs.values.forEach { (fd, renderer) ->
                renderer.close()
                fd.close()
            }
            docs.clear()
        }
        worker.shutdown()
        io.shutdown()
    }
}
