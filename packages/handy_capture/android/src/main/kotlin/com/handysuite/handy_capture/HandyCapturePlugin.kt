package com.handysuite.handy_capture

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** Flutter adapter for the existing local Snap MediaProjection/codec engine. */
class HandyCapturePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
  PluginRegistry.ActivityResultListener {
  private lateinit var context: Context
  private lateinit var channel: MethodChannel
  private val main = Handler(Looper.getMainLooper())
  private val worker = Executors.newSingleThreadExecutor()
  private var binding: ActivityPluginBinding? = null
  private var permission: MethodChannel.Result? = null
  private var operation: MethodChannel.Result? = null
  private var stopping: MethodChannel.Result? = null
  @Volatile private var processing = false
  private var requestCode = 0
  private var mode = "image"
  private var delay = 3000
  override fun onAttachedToEngine(engine: FlutterPlugin.FlutterPluginBinding) {
    context = engine.applicationContext
    channel = MethodChannel(engine.binaryMessenger, "handy_capture")
    channel.setMethodCallHandler(this)
    CaptureBridge.context = context
    CaptureBridge.owner = this
    if (CaptureBridge.lastResult == null) {
      try {
        val raw = context.getSharedPreferences("handy-snap-capture", Context.MODE_PRIVATE).getString("lastResult", null)
        if (raw != null) {
          val data = JSONObject(raw)
          owned(data.getString("uri"))
          CaptureBridge.lastResult = data.keys().asSequence().associateWith { data.get(it) }
        }
      } catch (_: Exception) { /* Never follow an invalid saved path. */ }
    }
    CaptureBridge.observer = { event, result, message ->
      when (event) {
        "started" -> if (CaptureBridge.mode == "video") {
          operation?.success(mapOf("recording" to true)); operation = null
        }
        "complete" -> {
          operation?.success(result); operation = null
          stopping?.success(result); stopping = null
        }
        "error" -> {
          operation?.error("E_CAPTURE", message ?: "Capture failed", null); operation = null
          stopping?.error("E_CAPTURE", message ?: "Capture failed", null); stopping = null
        }
      }
    }
  }
  override fun onDetachedFromEngine(engine: FlutterPlugin.FlutterPluginBinding) {
    VideoTransform.cancel()
    channel.setMethodCallHandler(null)
    cancelPromises("Capture connection closed")
    if (CaptureBridge.owner === this) { CaptureBridge.observer = null; CaptureBridge.owner = null }
    worker.shutdown()
  }
  private fun cancelPromises(message: String) {
    if (permission != null) CaptureBridge.busy = false
    permission?.error("E_CANCELED", message, null); permission = null
    operation?.error("E_CANCELED", message, null); operation = null
    stopping?.error("E_CANCELED", message, null); stopping = null
  }
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    this.binding = binding; binding.addActivityResultListener(this)
  }
  override fun onDetachedFromActivityForConfigChanges() { detachActivity() }
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { onAttachedToActivity(binding) }
  override fun onDetachedFromActivity() { detachActivity(); cancelPromises("Capture activity closed") }
  private fun detachActivity() { binding?.removeActivityResultListener(this); binding = null }

  private fun owned(uri: String): File {
    if (uri.length > 2048 || uri.any { it.code < 32 }) throw IllegalArgumentException("Invalid capture URI")
    val parsed = Uri.parse(uri)
    val root = File(context.filesDir, "snap-captures").canonicalFile
    val file = File(parsed.path ?: "").canonicalFile
    if (parsed.scheme != "file" || parsed.query != null || parsed.fragment != null || file.parentFile != root ||
      !file.isFile || file.extension.lowercase() !in listOf("png", "mp4") || file.length() !in 8..30_000_000) {
      throw IllegalArgumentException("Choose a capture owned by Handy Media, maximum 30 MB")
    }
    return file
  }
  private fun background(result: MethodChannel.Result, action: () -> Any?) {
    if (processing) { result.error("E_BUSY", "A native file operation is active", null); return }
    processing = true
    worker.execute {
      // Clear busy on the reply thread before resolving the Flutter future.
      // Clearing in a worker finally block races a fast next MethodChannel call.
      try { val value = action(); main.post { processing = false; result.success(value) } }
      catch (_: Exception) { main.post { processing = false; result.error("E_VIDEO", "Local video operation failed or was canceled. Source files were preserved; check codec, dimensions, duration and storage limits.", null) } }
    }
  }
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    try {
      when (call.method) {
        "capabilities" -> result.success(mapOf("screenshot" to true, "recording" to true, "videoTools" to true,
          "scope" to "display-or-selected-app", "audio" to "none", "trimAccuracy" to "keyframe"))
        "status" -> result.success(mapOf("recording" to CaptureBridge.recording,
          "pending" to (CaptureBridge.busy || permission != null || SnapVideoTools.processing || processing),
          "lastResult" to CaptureBridge.lastResult, "error" to CaptureBridge.error))
        "screenshot" -> begin("image", call.argument<Int>("delayMs") ?: 3000, result)
        "startRecording" -> begin("video", 0, result)
        "stopRecording" -> {
          if (stopping != null) result.error("E_BUSY", "Recording stop is in progress", null)
          else if (CaptureBridge.recording && CaptureBridge.service != null) {
            stopping = result; CaptureBridge.service?.finishCapture(true)
          } else result.error("E_NOT_RECORDING", "No recording is running", null)
        }
        "cancel" -> {
          cancelPromises("Capture canceled")
          CaptureBridge.canceled = true; SnapVideoTools.cancel(); VideoTransform.cancel()
          CaptureBridge.service?.finishCapture(false)
          result.success(null)
        }
        "read" -> background(result) { owned(call.argument<String>("uri") ?: "").readBytes() }
        "transform" -> {
          if (CaptureBridge.busy || permission != null || SnapVideoTools.processing || processing) throw IllegalStateException("Stop capture before transforming video")
          val source = owned(call.argument<String>("uri") ?: "")
          val rotation = call.argument<Int>("rotation") ?: -1
          val maxEdge = call.argument<Int>("maxEdge") ?: -1
          val mute = call.argument<Boolean>("mute") ?: throw IllegalArgumentException("Missing audio choice")
          VideoTransform.prepare()
          background(result) {
            val output = VideoTransform.run(context, source, rotation, maxEdge, mute)
            CaptureBridge.publish("complete", output)
            output
          }
        }
        "trim" -> background(result) { SnapVideoTools.trim(context, call.argument<String>("uri") ?: "",
          call.argument<Int>("startMs") ?: -1, call.argument<Int>("endMs") ?: -1) }
        "combine" -> background(result) { SnapVideoTools.combine(context, call.argument<List<String>>("uris") ?: emptyList()) }
        "frame" -> background(result) { SnapVideoTools.frame(context, call.argument<String>("uri") ?: "", call.argument<Int>("timeMs") ?: -1) }
        "importVideo" -> background(result) {
          if (CaptureBridge.busy || permission != null || SnapVideoTools.processing) throw IllegalStateException("Capture is busy")
          val bytes = call.argument<ByteArray>("bytes") ?: throw IllegalArgumentException("Missing MP4")
          if (bytes.size !in 33..30_000_000 || context.filesDir.usableSpace < 32_000_000) throw IllegalArgumentException("Video exceeds byte/storage limit")
          val folder = File(context.filesDir, "snap-captures").apply { mkdirs() }
          if ((folder.listFiles()?.sumOf { it.length() } ?: 0L) > 170_000_000) throw IllegalStateException("Capture storage limit exceeded")
          val file = File(folder, "snap-${UUID.randomUUID()}.mp4")
          try {
            file.outputStream().use { it.write(bytes); it.flush() }
            // A full-duration remux validates codec/tracks and leaves the import untouched.
            val metadata = android.media.MediaMetadataRetriever()
            val duration = try { metadata.setDataSource(file.absolutePath); metadata.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)?.toIntOrNull() ?: 0 }
              finally { metadata.release() }
            val verified = SnapVideoTools.trim(context, Uri.fromFile(file).toString(), 0, duration)
            verified
          } finally { file.delete() }
        }
        "clear" -> {
          if (CaptureBridge.busy || permission != null || SnapVideoTools.processing || processing) throw IllegalStateException("Stop capture before clearing")
          val folder = File(context.filesDir, "snap-captures").canonicalFile
          folder.listFiles()?.forEach { file ->
            if (file.canonicalFile.parentFile == folder && file.isFile && !file.delete()) throw java.io.IOException("Could not clear a capture")
          }
          CaptureBridge.lastResult = null
          context.getSharedPreferences("handy-snap-capture", Context.MODE_PRIVATE).edit().remove("lastResult").apply()
          result.success(null)
        }
        else -> result.notImplemented()
      }
    } catch (_: Exception) { result.error("E_CAPTURE_INPUT", "Invalid capture operation or capture is busy", null) }
  }
  private fun begin(requestedMode: String, delayMs: Int, result: MethodChannel.Result) {
    if (permission != null || CaptureBridge.busy || SnapVideoTools.processing || processing) {
      result.error("E_BUSY", "A capture or video operation is already active", null); return
    }
    val activity = binding?.activity
    if (activity == null || delayMs !in 0..10000) { result.error("E_INPUT", "Open Handy Media; delay must be 0-10000 ms", null); return }
    mode = requestedMode; delay = delayMs; permission = result; CaptureBridge.busy = true
    requestCode = CaptureBridge.nextRequestCode
    CaptureBridge.nextRequestCode = if (requestCode >= 50000) 38471 else requestCode + 1
    try {
      val manager = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
      activity.startActivityForResult(manager.createScreenCaptureIntent(), requestCode)
    } catch (_: Exception) {
      permission = null; CaptureBridge.busy = false; result.error("E_PERMISSION", "System capture consent could not be opened", null)
    }
  }
  override fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
    if (code != requestCode) return false
    val result = permission; permission = null
    if (result == null) return true
    val activity = binding?.activity
    if (resultCode != Activity.RESULT_OK || data == null || activity == null) {
      CaptureBridge.busy = false; result.error("E_CANCELED", "System screen capture consent was canceled", null); return true
    }
    CaptureBridge.busy = true; CaptureBridge.canceled = false; CaptureBridge.mode = mode
    CaptureBridge.lastResult = null; CaptureBridge.error = null; operation = result
    val intent = Intent(activity, SnapCaptureService::class.java).putExtra("resultCode", resultCode)
      .putExtra("projectionData", data).putExtra("mode", mode).putExtra("delay", delay)
    try { if (Build.VERSION.SDK_INT >= 26) activity.startForegroundService(intent) else activity.startService(intent) }
    catch (_: Exception) { operation = null; CaptureBridge.busy = false; result.error("E_CAPTURE_START", "Foreground capture could not start", null) }
    return true
  }
}
