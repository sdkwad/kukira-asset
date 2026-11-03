package app.kukira.kukira_asset

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
