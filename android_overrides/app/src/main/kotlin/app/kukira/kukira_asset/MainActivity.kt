package app.kukira.kukira_asset

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FragmentActivity is needed for the fingerprint prompt (biometric_storage).
class MainActivity : FlutterFragmentActivity() {
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
}
