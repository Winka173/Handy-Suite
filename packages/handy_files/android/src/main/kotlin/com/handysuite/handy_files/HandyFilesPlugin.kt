package com.handysuite.handy_files

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

/**
 * A folder the user picked through the Storage Access Framework (a local
 * folder, Google Drive, OneDrive…), kept with a persistable grant so the app
 * can write backups there later. Only files the app lists and names are
 * touched; nothing outside the picked tree is reachable.
 */
class HandyFilesPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
  PluginRegistry.ActivityResultListener {
  private lateinit var context: Context
  private lateinit var channel: MethodChannel
  private val main = Handler(Looper.getMainLooper())
  private val worker = Executors.newSingleThreadExecutor()
  private var binding: ActivityPluginBinding? = null
  private var picking: MethodChannel.Result? = null

  override fun onAttachedToEngine(engine: FlutterPlugin.FlutterPluginBinding) {
    context = engine.applicationContext
    channel = MethodChannel(engine.binaryMessenger, "handy_files/folder")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(engine: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    worker.shutdown()
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    this.binding = binding
    binding.addActivityResultListener(this)
  }
  override fun onDetachedFromActivityForConfigChanges() { detach() }
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { onAttachedToActivity(binding) }
  override fun onDetachedFromActivity() {
    detach()
    picking?.success(null); picking = null
  }
  private fun detach() {
    binding?.removeActivityResultListener(this)
    binding = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "pick" -> {
        val activity = binding?.activity
        if (activity == null) { result.error("E_ACTIVITY", "No activity", null); return }
        if (picking != null) { result.error("E_BUSY", "Already picking", null); return }
        picking = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
          Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
        )
        try {
          activity.startActivityForResult(intent, PICK)
        } catch (e: Exception) {
          picking = null
          result.error("E_PICK", e.message, null)
        }
      }
      "access" -> result.success(granted(call.argument<String>("tree")!!))
      "release" -> {
        val tree = Uri.parse(call.argument<String>("tree")!!)
        try {
          context.contentResolver.releasePersistableUriPermission(
            tree, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
          )
        } catch (_: Exception) { /* Already gone. */ }
        result.success(null)
      }
      "list" -> background(result) { children(Uri.parse(call.argument<String>("tree")!!)) }
      "write" -> background(result) {
        write(
          Uri.parse(call.argument<String>("tree")!!),
          call.argument<String>("name")!!,
          call.argument<String>("mime")!!,
          call.argument<ByteArray>("bytes")!!
        )
      }
      "delete" -> background(result) {
        val tree = Uri.parse(call.argument<String>("tree")!!)
        val uri = Uri.parse(call.argument<String>("uri")!!)
        // Only a direct child of the picked tree.
        if (children(tree).none { it["uri"] == uri.toString() }) throw IllegalArgumentException("Not in folder")
        DocumentsContract.deleteDocument(context.contentResolver, uri)
      }
      else -> result.notImplemented()
    }
  }

  override fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
    if (code != PICK) return false
    val result = picking ?: return true
    picking = null
    val tree = data?.data
    if (resultCode != Activity.RESULT_OK || tree == null) { result.success(null); return true }
    try {
      context.contentResolver.takePersistableUriPermission(
        tree, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
      )
      result.success(mapOf("uri" to tree.toString(), "name" to name(tree)))
    } catch (e: Exception) {
      result.error("E_PERMISSION", e.message, null)
    }
    return true
  }

  private fun background(result: MethodChannel.Result, work: () -> Any?) {
    worker.execute {
      try {
        val value = work()
        main.post { result.success(value) }
      } catch (e: Exception) {
        main.post { result.error("E_FOLDER", e.message, null) }
      }
    }
  }

  private fun granted(tree: String) = context.contentResolver.persistedUriPermissions.any {
    it.uri.toString() == tree && it.isWritePermission
  }

  private fun root(tree: Uri) = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

  private fun name(tree: Uri): String {
    context.contentResolver.query(root(tree), arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
      if (it.moveToFirst()) return it.getString(0) ?: ""
    }
    return ""
  }

  private fun children(tree: Uri): List<Map<String, Any?>> {
    if (!granted(tree.toString())) throw SecurityException("No access to folder")
    val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
    val out = mutableListOf<Map<String, Any?>>()
    context.contentResolver.query(
      uri,
      arrayOf(
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_SIZE,
        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        DocumentsContract.Document.COLUMN_MIME_TYPE
      ),
      null, null, null
    )?.use {
      while (it.moveToNext()) {
        if (it.getString(4) == DocumentsContract.Document.MIME_TYPE_DIR) continue
        out.add(
          mapOf(
            "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, it.getString(0)).toString(),
            "name" to it.getString(1),
            "size" to if (it.isNull(2)) null else it.getLong(2),
            "modified" to if (it.isNull(3)) null else it.getLong(3)
          )
        )
      }
    }
    return out
  }

  /** A new file; an existing one of that name is never replaced. */
  private fun write(tree: Uri, name: String, mime: String, bytes: ByteArray): Map<String, Any?> {
    if (!granted(tree.toString())) throw SecurityException("No access to folder")
    if (name.contains('/') || name.startsWith(".")) throw IllegalArgumentException("Bad name")
    val doc = DocumentsContract.createDocument(context.contentResolver, root(tree), mime, name)
      ?: throw IllegalStateException("Could not create file")
    try {
      context.contentResolver.openOutputStream(doc, "w")?.use { it.write(bytes) }
        ?: throw IllegalStateException("Could not open file")
    } catch (e: Exception) {
      try { DocumentsContract.deleteDocument(context.contentResolver, doc) } catch (_: Exception) {}
      throw e
    }
    var written = name
    context.contentResolver.query(doc, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
      if (it.moveToFirst()) written = it.getString(0) ?: name
    }
    return mapOf("uri" to doc.toString(), "name" to written)
  }

  companion object { private const val PICK = 0x4846 }
}
