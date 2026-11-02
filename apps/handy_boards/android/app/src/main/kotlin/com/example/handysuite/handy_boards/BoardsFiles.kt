package com.example.handysuite.handy_boards

import android.app.Activity
import android.content.Intent
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** SAF owns the destination; only fresh CREATE_DOCUMENT URIs are written. */
class BoardsFiles(private val activity: Activity) {
    private val executor = Executors.newSingleThreadExecutor()
    private val cancelled = AtomicBoolean(false)
    private var result: MethodChannel.Result? = null
    private var source: File? = null
    fun call(call: MethodCall, reply: MethodChannel.Result) {
        if (call.method == "cancel") { cancelled.set(true); reply.success(null); return }
        if (call.method != "save") { reply.notImplemented(); return }
        if (result != null) { reply.error("FILE_BUSY", "A file operation is already open", null); return }
        try {
            val file = File(call.argument<String>("path") ?: "").canonicalFile
            require(file.path.startsWith(activity.cacheDir.canonicalPath + File.separator) && file.isFile)
            val name = call.argument<String>("name") ?: "handy-boards.zip"
            require(name.matches(Regex("handy-boards\\.(zip|pdf)")))
            result = reply; source = file; cancelled.set(false)
            activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = call.argument<String>("mime") ?: "application/octet-stream"
                putExtra(Intent.EXTRA_TITLE, name)
            }, CODE)
        } catch (_: Exception) { result = null; source = null; reply.error("FILE_SAVE", "Unable to open document destination", null) }
    }
    fun activityResult(code: Int, status: Int, data: Intent?): Boolean {
        if (code != CODE) return false
        val reply = result ?: return true
        val file = source
        val uri = data?.data
        if (status != Activity.RESULT_OK || uri == null || file == null) {
            result = null; source = null; reply.success(null); return true
        }
        executor.execute {
            var error: String? = null
            try {
                activity.contentResolver.openOutputStream(uri, "w")!!.use { output ->
                    file.inputStream().use { input ->
                        val buffer = ByteArray(262144)
                        while (true) {
                            if (cancelled.get()) throw InterruptedException()
                            val n = input.read(buffer); if (n < 0) break
                            output.write(buffer, 0, n)
                        }
                    }
                    output.flush()
                }
                if (cancelled.get()) throw InterruptedException()
            } catch (_: Exception) {
                error = if (cancelled.get()) "FILE_CANCELLED" else "FILE_WRITE"
                try {
                    if (!DocumentsContract.deleteDocument(activity.contentResolver, uri)) error = "FILE_PARTIAL"
                } catch (_: Exception) { error = "FILE_PARTIAL" }
            }
            activity.runOnUiThread {
                result = null; source = null
                if (error == null) reply.success(uri.toString())
                else if (error == "FILE_CANCELLED") reply.success(null)
                else reply.error(error!!, if (error == "FILE_PARTIAL") "Destination provider could not remove the incomplete copy" else "Unable to write export", null)
            }
        }
        return true
    }
    companion object { const val CODE = 5031 }
}
