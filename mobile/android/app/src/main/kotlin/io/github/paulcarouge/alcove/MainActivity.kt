package io.github.paulcarouge.alcove

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands a downloaded APK to Android's installer (in-app updates, ADR 0024), and hosts the file
 * viewers' channel (PDF pages, open with, share, download) and "Share to Alcove".
 */
class MainActivity : FlutterActivity() {
    private var files: FilesChannel? = null
    private var share: ShareChannel? = null
    private var firstLaunch = true

    override fun onCreate(savedInstanceState: Bundle?) {
        // A recreated activity (after the system killed it) must not take the same share twice.
        firstLaunch = savedInstanceState == null
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        share?.handle(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        files?.dispose()
        share?.dispose()
        files = null
        share = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        files = FilesChannel(this, messenger)
        share = ShareChannel(this, messenger).also { if (firstLaunch) it.handle(intent) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alcove/update").setMethodCallHandler { call, result ->
            when (call.method) {
                // The device's ABIs, preferred first: the updater picks the matching APK (ADR 0029).
                "abis" -> result.success(Build.SUPPORTED_ABIS.toList())
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls(),
                )
                "allowInstalls" -> {
                    // Android 8+: the user allows this app to install updates, once.
                    startActivity(
                        Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")),
                    )
                    result.success(null)
                }
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path is required", null)
                        return@setMethodCallHandler
                    }
                    val uri = FileProvider.getUriForFile(this, "$packageName.updates", File(path))
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
