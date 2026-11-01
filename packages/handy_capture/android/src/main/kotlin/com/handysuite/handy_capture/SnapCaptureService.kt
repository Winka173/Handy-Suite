package com.handysuite.handy_capture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.MediaMetadataRetriever
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.view.WindowManager
import org.json.JSONObject
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.min
import kotlin.math.sqrt

internal object CaptureBridge {
  @Volatile var owner: Any? = null
  @Volatile var observer: ((String, Map<String, Any?>?, String?) -> Unit)? = null
  @Volatile var busy = false
  @Volatile var canceled = false
  @Volatile var nextRequestCode = 38471
  @Volatile var recording = false
  @Volatile var mode = "image"
  @Volatile var lastResult: Map<String, Any?>? = null
  @Volatile var error: String? = null
  @Volatile var service: SnapCaptureService? = null
  @Volatile var context: Context? = null
  fun publish(event: String, result: Map<String, Any?>? = null, message: String? = null) {
    Handler(Looper.getMainLooper()).post {
      if (result != null) {
        lastResult = result
        context?.getSharedPreferences("handy-snap-capture", Context.MODE_PRIVATE)?.edit()?.putString("lastResult", JSONObject(result).toString())?.apply()
      }
      error = message
      observer?.invoke(event, result, message)
    }
  }
}

class SnapCaptureService : Service() {
  private val main = Handler(Looper.getMainLooper())
  private val finished = AtomicBoolean(false)
  private val processingFrame = AtomicBoolean(false)
  private var projection: MediaProjection? = null
  private var display: VirtualDisplay? = null
  private var reader: ImageReader? = null
  private var recorder: MediaRecorder? = null
  private var worker: HandlerThread? = null
  private var output: File? = null
  private var width = 0
  private var height = 0
  private var recorderStarted = false
  private var startedAt = 0L
  private var mode = "image"
  private val limit = Runnable { if (mode == "video") finishCapture(true) else fail("No screenshot frame arrived; selected content may be protected") }
  private val projectionCallback = object : MediaProjection.Callback() {
    override fun onStop() {
      if (!finished.get()) { if (mode == "video") finishCapture(true) else fail("Screen capture permission ended before a frame was saved") }
    }
  }
  override fun onBind(intent: Intent?): IBinder? = null
  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (intent?.action == "STOP_CAPTURE") { finishCapture(true); return START_NOT_STICKY }
    if (CaptureBridge.service != null && CaptureBridge.service !== this) { stopSelf(); return START_NOT_STICKY }
    if (projection != null) return START_NOT_STICKY
    CaptureBridge.service = this
    CaptureBridge.context = applicationContext
    mode = intent?.getStringExtra("mode") ?: "image"
    try {
      showNotification()
      if (CaptureBridge.canceled) throw IllegalStateException("Capture canceled before the service started")
      if (intent == null) throw IllegalStateException("Capture session cannot restart without fresh system consent")
      if (filesDir.usableSpace < 32_000_000) throw IllegalStateException("Insufficient storage for screen capture")
      val directory = File(filesDir, "snap-captures").apply { mkdirs() }
      if ((directory.listFiles()?.sumOf { it.length() } ?: 0L) > 170_000_000) throw IllegalStateException("Captured files exceed the storage budget; explicitly clear old captures first")
      val metrics = resources.displayMetrics
      val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
      val bounds = if (Build.VERSION.SDK_INT >= 30) wm.maximumWindowMetrics.bounds else null
      val sourceWidth = bounds?.width() ?: metrics.widthPixels
      val sourceHeight = bounds?.height() ?: metrics.heightPixels
      if (sourceWidth < 1 || sourceHeight < 1) throw IllegalStateException("Display dimensions are unavailable")
      val scale = if (mode == "video") min(1.0, 1280.0 / maxOf(sourceWidth, sourceHeight)) else minOf(1.0, 2048.0 / sourceWidth, 4096.0 / sourceHeight, sqrt(8_000_000.0 / sourceWidth / sourceHeight))
      width = maxOf(2, ((sourceWidth * scale).toInt() / 2) * 2)
      height = maxOf(2, ((sourceHeight * scale).toInt() / 2) * 2)
      val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
      @Suppress("DEPRECATION")
      val data = intent.getParcelableExtra<Intent>("projectionData") ?: throw IllegalArgumentException("Missing one-time projection consent")
      projection = manager.getMediaProjection(intent.getIntExtra("resultCode", 0), data)
      projection!!.registerCallback(projectionCallback, main)
      output = File(directory, "snap-${System.currentTimeMillis()}-${java.util.UUID.randomUUID()}.${if (mode == "video") "mp4" else "png"}")
      if (mode == "video") startVideo(metrics.densityDpi)
      else {
        val delay = intent.getIntExtra("delay", 3000).coerceIn(0, 10000)
        main.postDelayed({ if (!finished.get()) startImage(metrics.densityDpi) }, delay.toLong())
        main.postDelayed(limit, delay.toLong() + 20000L)
      }
    } catch (error: Exception) { fail(error.message ?: "Screen capture could not start") }
    return START_NOT_STICKY
  }

  private fun showNotification() {
    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("snap-capture", "Screen capture", NotificationManager.IMPORTANCE_LOW))
    val stop = PendingIntent.getService(this, 7701, Intent(this, SnapCaptureService::class.java).setAction("STOP_CAPTURE"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "snap-capture") else Notification.Builder(this)
    val notification = builder.setSmallIcon(android.R.drawable.ic_menu_camera).setContentTitle("Handy Media screen capture").setContentText("System capture is active. Tap Stop to end it.").setOngoing(true).addAction(Notification.Action.Builder(android.R.drawable.ic_media_pause, "Stop", stop).build()).build()
    if (Build.VERSION.SDK_INT >= 29) startForeground(7701, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION) else startForeground(7701, notification)
  }

  private fun startImage(density: Int) {
    try {
      worker = HandlerThread("SnapCaptureImage").apply { start() }
      reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
      reader!!.setOnImageAvailableListener({ imageReader ->
        val image = try { imageReader.acquireLatestImage() } catch (_: Exception) { null }
        if (image != null) {
          if (finished.get() || !processingFrame.compareAndSet(false, true)) image.close()
          else {
            var padded: Bitmap? = null
            var cropped: Bitmap? = null
            try {
              val plane = image.planes[0]
              val extra = (plane.rowStride - plane.pixelStride * width) / plane.pixelStride
              padded = Bitmap.createBitmap(width + extra, height, Bitmap.Config.ARGB_8888)
              padded.copyPixelsFromBuffer(plane.buffer)
              cropped = Bitmap.createBitmap(padded, 0, 0, width, height)
              val target = output ?: throw IllegalStateException("Screenshot output was removed")
              target.outputStream().use { if (!cropped.compress(Bitmap.CompressFormat.PNG, 100, it)) throw IllegalStateException("PNG encoding failed") }
              if (target.length() <= 8 || target.length() > 8_000_000) throw IllegalStateException("Screenshot PNG exceeds the 8 MB budget")
              main.post {
                if (!finished.get()) {
                  val result = mapOf<String, Any?>("uri" to Uri.fromFile(target).toString(), "width" to width, "height" to height, "mime" to "image/png")
                  releaseResources(); CaptureBridge.publish("complete", result)
                } else target.delete()
              }
            } catch (error: Exception) { main.post { if (!finished.get()) fail(error.message ?: "Screenshot encoding failed") } }
            finally { image.close(); if (cropped !== padded) cropped?.recycle(); padded?.recycle() }
          }
        }
      }, Handler(worker!!.looper))
      display = projection!!.createVirtualDisplay("HandySnapImage", width, height, density, DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, reader!!.surface, null, null)
    } catch (error: Exception) { fail(error.message ?: "Screenshot surface failed") }
  }

  private fun startVideo(density: Int) {
    recorder = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(this) else @Suppress("DEPRECATION") MediaRecorder()
    recorder!!.apply {
      setVideoSource(MediaRecorder.VideoSource.SURFACE)
      setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
      setVideoEncoder(MediaRecorder.VideoEncoder.H264)
      setVideoSize(width, height)
      setVideoFrameRate(30)
      setVideoEncodingBitRate(4_000_000)
      setMaxFileSize(25_000_000)
      setMaxDuration(300000)
      setOutputFile(output!!.absolutePath)
      setOnInfoListener { _, what, _ -> if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED || what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) main.post { finishCapture(true) } }
      setOnErrorListener { _, _, _ -> main.post { fail("Screen recorder reported an encoder error") } }
      prepare()
    }
    display = projection!!.createVirtualDisplay("HandySnapVideo", width, height, density, DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, recorder!!.surface, null, null)
    recorder!!.start(); recorderStarted = true; startedAt = SystemClock.elapsedRealtime()
    CaptureBridge.recording = true
    CaptureBridge.publish("started")
    main.postDelayed(limit, 300000L)
  }

  fun finishCapture(keep: Boolean) {
    if (finished.get()) return
    val target = output
    var failure: String? = null
    if (mode == "video" && recorderStarted) {
      try { recorder?.stop(); recorderStarted = false }
      catch (_: Exception) { failure = "Recording was too short or was interrupted before a playable frame was saved" }
    }
    var result: Map<String, Any?>? = null
    if (keep && mode == "video" && target != null && target.exists() && target.length() > 32 && target.length() < 30_000_000) {
      val metadata = MediaMetadataRetriever()
      try {
        metadata.setDataSource(target.absolutePath)
        val actualWidth = metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
        val actualHeight = metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
        val duration = metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
        if (actualWidth < 1 || actualHeight < 1 || duration < 1) throw IllegalStateException("The captured video could not be verified")
        failure = null
        result = mapOf("uri" to Uri.fromFile(target).toString(), "width" to actualWidth, "height" to actualHeight, "mime" to "video/mp4", "durationMs" to duration)
      } catch (error: Exception) { failure = error.message ?: "Video verification failed" }
      finally { metadata.release() }
    } else if (keep && mode == "video" && failure == null) failure = "Recording file is empty or exceeds the 30 MB export budget"
    releaseResources()
    if (result != null) CaptureBridge.publish("complete", result)
    else { target?.delete(); CaptureBridge.publish("error", message = failure ?: "Capture canceled") }
  }

  private fun fail(message: String) {
    if (finished.get()) return
    val target = output
    releaseResources(); target?.delete(); CaptureBridge.publish("error", message = message)
  }
  private fun releaseResources() {
    if (!finished.compareAndSet(false, true)) return
    main.removeCallbacksAndMessages(null)
    try { display?.release() } catch (_: Exception) {}
    display = null
    try { reader?.setOnImageAvailableListener(null, null); reader?.close() } catch (_: Exception) {}
    reader = null
    try { recorder?.reset(); recorder?.release() } catch (_: Exception) {}
    recorder = null
    try { projection?.unregisterCallback(projectionCallback); projection?.stop() } catch (_: Exception) {}
    projection = null
    worker?.quitSafely(); worker = null
    CaptureBridge.recording = false; CaptureBridge.busy = false; CaptureBridge.service = null
    if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
    stopSelf()
  }
  override fun onDestroy() { if (!finished.get()) fail("Screen capture service was stopped"); super.onDestroy() }
  override fun onTaskRemoved(rootIntent: Intent?) { if (!finished.get()) finishCapture(mode == "video"); super.onTaskRemoved(rootIntent) }
}
