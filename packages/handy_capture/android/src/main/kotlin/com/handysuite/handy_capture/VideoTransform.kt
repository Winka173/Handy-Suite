package com.handysuite.handy_capture

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.effect.ScaleAndRotateTransformation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import java.io.File
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.math.max
import kotlin.math.min

/** Real platform transcode. The Flutter adapter validates input ownership first. */
internal object VideoTransform {
  @Volatile private var canceled = false
  private val main = Handler(Looper.getMainLooper())
  fun cancel() { canceled = true }
  fun prepare() { canceled = false }
  fun run(context: Context, source: File, rotation: Int, maxEdge: Int, mute: Boolean): Map<String, Any?> {
    require(rotation in listOf(0, 90, 180, 270) && maxEdge in listOf(240, 480, 720, 1280))
    require(context.filesDir.usableSpace > 32_000_000) { "Insufficient storage" }
    val root = File(context.filesDir, "snap-captures").canonicalFile
    require(source.canonicalFile.parentFile == root && source.isFile && source.extension == "mp4" && source.length() in 33..30_000_000)
    require((root.listFiles()?.sumOf { it.length() } ?: 0) <= 170_000_000)
    val input = metadata(source)
    val displayW = input["width"] as Int; val displayH = input["height"] as Int
    val rotatedW = if (rotation % 180 == 0) displayW else displayH
    val rotatedH = if (rotation % 180 == 0) displayH else displayW
    val scale = min(1.0, maxEdge.toDouble() / max(rotatedW, rotatedH))
    val width = max(2, ((rotatedW * scale).toInt() / 2) * 2)
    val height = max(2, ((rotatedH * scale).toInt() / 2) * 2)
    val target = File(root, "snap-${UUID.randomUUID()}.mp4")
    val done = CountDownLatch(1)
    var failed = false
    var transformer: Transformer? = null
    main.post {
      try {
        if (canceled) { failed = true; done.countDown(); return@post }
        val effects = listOf(
          ScaleAndRotateTransformation.Builder().setRotationDegrees(-rotation.toFloat()).build(),
          Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_SCALE_TO_FIT)
        )
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(source)))
          .setRemoveAudio(mute).setEffects(Effects(emptyList(), effects)).build()
        transformer = Transformer.Builder(context).setVideoMimeType(MimeTypes.VIDEO_H264)
          .setAudioMimeType(MimeTypes.AUDIO_AAC).addListener(object: Transformer.Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) { done.countDown() }
            override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) { failed = true; done.countDown() }
          }).build()
        transformer!!.start(item, target.absolutePath)
      } catch (_: Exception) { failed = true; done.countDown() }
    }
    try {
      val deadline = System.nanoTime() + TimeUnit.MINUTES.toNanos(3)
      while (!done.await(100, TimeUnit.MILLISECONDS)) {
        check(!canceled && System.nanoTime() < deadline && target.length() <= 30_000_000 && context.filesDir.usableSpace > 2_000_000) { "Video canceled or exceeded processing limits" }
      }
      check(!canceled && !failed) { "Video transformation failed or canceled" }
      val result = metadata(target)
      check((result["width"] as Int) <= maxEdge && (result["height"] as Int) <= maxEdge)
      if (mute) check(!(result["hasAudio"] as Boolean))
      return result.filterKeys { it != "hasAudio" } + ("uri" to Uri.fromFile(target).toString())
    } catch (error: Exception) {
      // Cancel on the same looper, then remove only this operation's partial file.
      val stopped = CountDownLatch(1)
      main.post { try { transformer?.cancel() } finally { target.delete(); stopped.countDown() } }
      stopped.await(5, TimeUnit.SECONDS)
      throw error
    }
  }
  private fun metadata(file: File): Map<String, Any?> {
    require(file.length() in 33..30_000_000)
    val meta = MediaMetadataRetriever(); val extractor = MediaExtractor()
    try {
      meta.setDataSource(file.absolutePath)
      var width = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
      var height = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
      val rotation = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
      val duration = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toIntOrNull() ?: 0
      require(width > 0 && height > 0 && width.toLong() * height <= 16_000_000 && duration in 1..300000)
      if (rotation % 180 != 0) { val old = width; width = height; height = old }
      extractor.setDataSource(file.absolutePath)
      var video = 0; var audio = 0
      for (index in 0 until extractor.trackCount) {
        when(extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)) {
          "video/avc" -> video++
          "audio/mp4a-latm" -> audio++
          else -> throw IllegalArgumentException("Only verified H.264/AAC tracks are supported")
        }
      }
      require(video == 1 && audio <= 1)
      return mapOf("width" to width,"height" to height,"durationMs" to duration,"mime" to "video/mp4","hasAudio" to (audio > 0))
    } finally { meta.release(); extractor.release() }
  }
}
