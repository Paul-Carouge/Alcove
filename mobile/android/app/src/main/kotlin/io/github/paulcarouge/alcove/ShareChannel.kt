package io.github.paulcarouge.alcove

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import androidx.core.content.IntentCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

/**
 * "Share to Alcove" (channel "alcove/share"): files sent from other apps (ACTION_SEND /
 * ACTION_SEND_MULTIPLE, any type, or plain text) are copied into the app cache's shared/ folder,
 * then handed to Dart as `{path, name, mime, size}` maps. Dart asks for them with "ready" once it
 * listens; later shares arrive with "shared". Dart deletes the copies once queued or cancelled.
 *
 * Security: the sender chooses the URI, but the copy is read with Alcove's identity. So only
 * `content://` URIs from other apps are accepted, never Alcove's own providers, and never a file
 * that resolves inside Alcove's private storage (a sender could otherwise get Alcove's tokens or
 * cache uploaded to the server). Copies are bounded in size and time.
 */
class ShareChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "alcove/share")
    private val worker = Executors.newSingleThreadExecutor()
    private val watchdog = Executors.newSingleThreadScheduledExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val pending = mutableListOf<List<Map<String, Any>>>()
    private var dartReady = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> {
                    dartReady = true
                    val batches = pending.toList()
                    pending.clear()
                    result.success(batches)
                }
                // The Dart side stopped listening (signed out): shares wait in [pending] again.
                "unready" -> {
                    dartReady = false
                    result.success(null)
                }
                "discard" -> {
                    val paths = call.argument<List<String>>("paths") ?: emptyList()
                    // The trailing separator keeps "shared-other/" from passing as "shared/".
                    val dir = folder().canonicalPath + File.separator
                    worker.execute {
                        // Only our own copies, never anything else.
                        paths.map { File(it) }.filter { it.canonicalPath.startsWith(dir) }.forEach { it.delete() }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun folder() = File(activity.cacheDir, "shared")

    /** Takes the files of a share intent, if it is one. */
    fun handle(intent: Intent?) {
        if (intent == null) return
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val uris: List<Uri> = when (intent.action) {
            Intent.ACTION_SEND -> listOfNotNull(IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java))
            Intent.ACTION_SEND_MULTIPLE ->
                IntentCompat.getParcelableArrayListExtra(intent, Intent.EXTRA_STREAM, Uri::class.java) ?: emptyList()
            else -> return
        }
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        val type = intent.type
        // Handled once: a recreated activity must not upload the same files again.
        intent.action = null
        worker.execute {
            val dir = folder().apply { mkdirs() }
            val files = mutableListOf<Map<String, Any>>()
            for (uri in uris.take(MAX_FILES)) {
                try {
                    files.add(copy(uri, type, dir))
                } catch (_: Throwable) {
                    // A refused, unreadable or too large item is skipped; the others still arrive.
                }
            }
            if (uris.isEmpty() && !text.isNullOrEmpty()) {
                val name = safeName((subject?.takeIf { it.isNotBlank() } ?: "Shared text").take(80) + ".txt")
                val out = File(dir, "${System.nanoTime()}-$name")
                out.writeText(text.take(MAX_TEXT_CHARS))
                files.add(mapOf("path" to out.path, "name" to name, "mime" to "text/plain", "size" to out.length()))
            }
            if (files.isEmpty()) return@execute
            main.post { deliver(files) }
        }
    }

    /** Hands a share to Dart, or keeps it until Dart listens; never lost if Dart can't take it. */
    private fun deliver(files: List<Map<String, Any>>) {
        if (!dartReady) {
            pending.add(files)
            return
        }
        channel.invokeMethod("shared", files, object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(code: String, message: String?, details: Any?) {
                dartReady = false
                pending.add(files)
            }
            override fun notImplemented() {
                dartReady = false
                pending.add(files)
            }
        })
    }

    /** Whether a URI may be read on the sender's behalf (see the class comment). */
    private fun allowed(uri: Uri): Boolean {
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) return false // file://, android.resource://…
        val authority = uri.authority ?: return false
        // Alcove's own providers (FileProvider "<package>.updates", plugins' "<package>.*").
        return authority != activity.packageName && !authority.startsWith(activity.packageName + ".")
    }

    /** Alcove's private storage, wherever the system put it (internal, per user, external). */
    private fun privateRoots(): List<String> = listOfNotNull(
        activity.applicationInfo.dataDir,
        activity.filesDir.parent,
        activity.cacheDir.path,
        activity.getExternalFilesDir(null)?.parent,
        activity.externalCacheDir?.path,
    ).map { File(it).canonicalPath + File.separator }

    private fun copy(uri: Uri, fallbackType: String?, dir: File): Map<String, Any> {
        if (!allowed(uri)) throw SecurityException("refused uri")
        val resolver = activity.contentResolver
        val pfd = resolver.openFileDescriptor(uri, "r") ?: throw IOException("no descriptor")
        pfd.use {
            // What the descriptor really points to (a provider could hand out one of our files).
            val target = try {
                File("/proc/self/fd/${pfd.fd}").canonicalPath
            } catch (_: IOException) {
                "" // pipes and sockets have no path: fine
            }
            val roots = privateRoots()
            if (target.isNotEmpty() && (roots.any { (target + File.separator).startsWith(it) } ||
                    target.contains("/${activity.packageName}/"))
            ) {
                throw SecurityException("refused private file")
            }
            var name: String? = null
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) name = c.getString(0)
            }
            val display = safeName(name ?: uri.lastPathSegment ?: "file")
            val mime = resolver.getType(uri) ?: fallbackType?.takeIf { !it.contains('*') } ?: "application/octet-stream"
            val out = File(dir, "${System.nanoTime()}-$display")
            try {
                boundedCopy(pfd, out, maxBytes(dir))
            } catch (e: Throwable) {
                out.delete()
                throw e
            }
            return mapOf("path" to out.path, "name" to display, "mime" to mime, "size" to out.length())
        }
    }

    /** At most 4 GB, and never closer than 200 MB to a full phone. */
    private fun maxBytes(dir: File): Long = minOf(MAX_FILE_BYTES, dir.usableSpace - FREE_MARGIN_BYTES).coerceAtLeast(0)

    /**
     * Copies at most [limit] bytes. A sender that stops sending (a pipe left open) is cut off after
     * [STALL_SECONDS] without progress, so the single worker is never stuck.
     */
    private fun boundedCopy(pfd: ParcelFileDescriptor, out: File, limit: Long) {
        val lastProgress = AtomicLong(System.nanoTime())
        val stalled = watchdog.scheduleWithFixedDelay({
            if (System.nanoTime() - lastProgress.get() > TimeUnit.SECONDS.toNanos(STALL_SECONDS)) {
                try {
                    pfd.close() // unblocks the read below with an IOException
                } catch (_: IOException) {
                }
            }
        }, 5, 5, TimeUnit.SECONDS)
        try {
            FileInputStream(pfd.fileDescriptor).use { input ->
                out.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        total += n
                        if (total > limit) throw IOException("too large")
                        output.write(buffer, 0, n)
                        lastProgress.set(System.nanoTime())
                    }
                }
            }
        } finally {
            stalled.cancel(false)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
        watchdog.shutdownNow()
    }

    companion object {
        private const val MAX_FILES = 500
        private const val MAX_TEXT_CHARS = 1_000_000
        private const val MAX_FILE_BYTES = 4_000_000_000L
        private const val FREE_MARGIN_BYTES = 200_000_000L
        private const val STALL_SECONDS = 60L
        private const val MAX_NAME_BYTES = 200

        /**
         * Same rules as safeFileName in lib/core/file_names.dart: no path separators, control,
         * bidi or zero-width characters (U+200B–U+200F, U+202A–U+202E, U+2066–U+2069, BOM), no
         * leading dots, at most 200 UTF-8 bytes keeping a short extension.
         */
        fun safeName(name: String): String {
            var n = name
                .replace(Regex("[\\u200B-\\u200F\\u202A-\\u202E\\u2066-\\u2069\\uFEFF]"), "")
                .replace(Regex("[/\\\\\\u0000-\\u001f\\u007f]"), "_")
                .trim()
                .replaceFirst(Regex("^\\.+"), "_")
            if (n.isEmpty() || n == "_") return "file"
            if (n.toByteArray(Charsets.UTF_8).size <= MAX_NAME_BYTES) return n
            val dot = n.lastIndexOf('.')
            val ext = if (dot > 0 && n.length - dot <= 16) n.substring(dot) else ""
            val base = if (ext.isEmpty()) n else n.substring(0, dot)
            val budget = MAX_NAME_BYTES - ext.toByteArray(Charsets.UTF_8).size
            val out = StringBuilder()
            var used = 0
            var i = 0
            while (i < base.length) {
                val cp = base.codePointAt(i)
                val ch = String(Character.toChars(cp))
                val size = ch.toByteArray(Charsets.UTF_8).size
                if (used + size > budget) break
                out.append(ch)
                used += size
                i += Character.charCount(cp)
            }
            n = out.toString().trimEnd() + ext
            return n
        }
    }
}
