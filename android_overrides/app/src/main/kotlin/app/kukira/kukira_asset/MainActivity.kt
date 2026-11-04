package app.kukira.kukira_asset

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

// FragmentActivity is needed for the fingerprint prompt (biometric_storage).
class MainActivity : FlutterFragmentActivity() {
    // The backup waiting for the save dialog to answer: its file, copied once a place is picked.
    private var saveResult: MethodChannel.Result? = null
    private var savePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kukira/privacy").setMethodCallHandler { call, result ->
            when (call.method) {
                "hideInRecents" -> {
                    hideInRecents(call.arguments as Boolean)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kukira/links").setMethodCallHandler { call, result ->
            when (call.method) {
                "openWeb" -> result.success(openWeb(call.arguments as String))
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kukira/save").setMethodCallHandler { call, result ->
            when (call.method) {
                "createDocument" -> createDocument(call.argument<String>("name"), call.argument<String>("path"), result)
                else -> result.notImplemented()
            }
        }
    }

    // Android's own save dialog. Folders on the phone and the installed cloud apps (Google
    // Drive, OneDrive, Dropbox) are its places, and the app that owns the place takes the
    // file, so Kukira itself never goes online. Answers the authority of the place the file
    // went to, so the app can tell the phone from the cloud, or null when the owner backed out.
    @Suppress("DEPRECATION")
    private fun createDocument(name: String?, path: String?, result: MethodChannel.Result) {
        if (name == null || path == null) {
            result.error("args", "A name and the file are needed", null)
            return
        }
        if (saveResult != null) {
            result.error("busy", "The save dialog is already open", null)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("application/octet-stream")
            .putExtra(Intent.EXTRA_TITLE, name)
        saveResult = result
        savePath = path
        try {
            startActivityForResult(intent, SAVE_REQUEST)
        } catch (e: Exception) {
            saveResult = null
            savePath = null
            result.error("noDialog", e.message, null)
        }
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_REQUEST) return
        val result = saveResult ?: return
        val path = savePath
        saveResult = null
        savePath = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || path == null) {
            result.success(null)
            return
        }
        // Copied a piece at a time, away from the main thread: a backup can be large, and a
        // cloud app can take a while to accept it.
        Thread {
            try {
                val out = contentResolver.openOutputStream(uri) ?: throw IOException("No stream for the file")
                out.use { o -> FileInputStream(File(path)).use { it.copyTo(o, 64 * 1024) } }
                runOnUiThread { result.success(uri.authority ?: "") }
            } catch (e: Exception) {
                runOnUiThread { result.error("write", e.message, null) }
            }
        }.start()
    }

    // A council's website opens in the phone's browser. The app itself has no internet
    // permission and does not load the page.
    private fun openWeb(url: String): Boolean {
        val uri = Uri.parse(url)
        if (uri.scheme != "https" && uri.scheme != "http") return false
        val intent = Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE)
        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            // No browser, or one that refused the address.
            false
        }
    }

    // With the app lock on, the Recent apps screen must not show a picture of the records.
    // Android 13+ can hide just that picture; older versions can only do it with FLAG_SECURE,
    // which also blocks screenshots.
    private fun hideInRecents(hide: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(!hide)
        } else if (hide) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    companion object {
        // Below 0x10000, as FragmentActivity requires.
        private const val SAVE_REQUEST = 0x4B53
    }
}
