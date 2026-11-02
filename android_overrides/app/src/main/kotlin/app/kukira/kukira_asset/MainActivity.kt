package app.kukira.kukira_asset

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// SPIKE (branch spike/saf, never merged): can the app keep writing to a file or folder the
// user picked once in Google Drive or OneDrive, after a restart, with no INTERNET permission?
// The picked location is kept by Android (persisted URI permission) and in SharedPreferences.
class MainActivity : FlutterFragmentActivity() {
    private var pending: MethodChannel.Result? = null
    private val prefs by lazy { getSharedPreferences("saf_spike", MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "spike/saf").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "pickFile" -> {
                        pending = result
                        startActivityForResult(
                            Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                                .setType("text/plain").putExtra(Intent.EXTRA_TITLE, "kukira-saf-test.txt"),
                            FILE,
                        )
                    }
                    "pickFolder" -> {
                        pending = result
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), FOLDER)
                    }
                    "writeFile" -> result.success(write(Uri.parse(prefs.getString("file", null) ?: return@setMethodCallHandler result.error("none", "No file picked yet", null)), call.arguments as String))
                    "writeFolder" -> result.success(writeInFolder(call.arguments as String))
                    "status" -> result.success(status())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("failed", "${e.javaClass.simpleName}: ${e.message}", null)
            }
        }
    }

    @Deprecated("Spike only")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val r = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) return r.success("cancelled")
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            prefs.edit().putString(if (requestCode == FILE) "file" else "folder", uri.toString()).apply()
            r.success("picked $uri")
        } catch (e: Exception) {
            r.success("picked, but Android refused to keep access: ${e.javaClass.simpleName}: ${e.message}")
        }
    }

    // "wt" truncates, so the file holds only the newest text.
    private fun write(uri: Uri, text: String): String {
        val out = contentResolver.openOutputStream(uri, "wt") ?: return "openOutputStream returned null"
        out.use { it.write(text.toByteArray()) }
        val back = contentResolver.openInputStream(uri)?.use { it.readBytes().decodeToString() }
        return if (back == text) "written and read back OK" else "written, but read back: ${back?.take(80)}"
    }

    // Two files side by side, like the planned A/B backups.
    private fun writeInFolder(text: String): String {
        val tree = Uri.parse(prefs.getString("folder", null) ?: return "No folder picked yet")
        val dir = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        val names = listOf("kukira-saf-test-A.txt", "kukira-saf-test-B.txt")
        val slot = names[(prefs.getInt("slot", 0)) % 2]
        prefs.edit().putInt("slot", prefs.getInt("slot", 0) + 1).apply()
        val existing = findChild(tree, slot)
        val target = existing ?: DocumentsContract.createDocument(contentResolver, dir, "text/plain", slot)
            ?: return "createDocument returned null"
        return "$slot: " + write(target, text)
    }

    private fun findChild(tree: Uri, name: String): Uri? {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        contentResolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { c ->
            while (c.moveToNext()) {
                if (c.getString(1) == name) return DocumentsContract.buildDocumentUriUsingTree(tree, c.getString(0))
            }
        }
        return null
    }

    private fun status(): String {
        val kept = contentResolver.persistedUriPermissions.joinToString("\n") { "${it.uri} read=${it.isReadPermission} write=${it.isWritePermission}" }
        return "file: ${prefs.getString("file", "-")}\nfolder: ${prefs.getString("folder", "-")}\nAndroid keeps access to:\n${kept.ifEmpty { "(nothing)" }}"
    }

    companion object {
        private const val FILE = 41
        private const val FOLDER = 42
    }
}
