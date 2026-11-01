package com.handysuite.handy_capture

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import java.io.File
import java.nio.ByteBuffer
import java.util.UUID
import kotlin.math.min
import kotlin.math.sqrt

/** Streaming MP4 transforms. No source is overwritten and no arbitrary URI is read. */
internal object SnapVideoTools {
  @Volatile var processing = false
    private set
  @Volatile private var canceled = false
  private val lock = Any()
  private const val MAX_BYTES = 30_000_000L
  private const val MAX_DURATION_MS = 300000L
  private data class Movie(val file: File, val width: Int, val height: Int, val duration: Long, val rotation: Int, val tracks: List<Track>)
  private data class Track(val index: Int, val mime: String, val format: MediaFormat)
  fun cancel() { canceled = true }
  private fun checkCanceled() { if (canceled) throw IllegalStateException("Video operation canceled") }
  private fun <T> operation(context: Context, action: () -> T): T {
    synchronized(lock) {
      if (processing || CaptureBridge.busy) throw IllegalStateException("Stop the current capture or video operation first")
      processing = true; canceled = false
    }
    try {
      if (context.filesDir.usableSpace < 32_000_000) throw IllegalStateException("Insufficient storage for video processing")
      val used = File(context.filesDir, "snap-captures").listFiles()?.sumOf { it.length() } ?: 0L
      if (used > 170_000_000) throw IllegalStateException("Clear old captured files before adding a processed video")
      return action()
    } finally { processing = false }
  }
  private fun owned(context: Context, uri: String): File {
    val parsed = Uri.parse(uri)
    if (parsed.scheme != "file" || parsed.query != null || parsed.fragment != null) throw IllegalArgumentException("Choose a local Handy Media captured video")
    val root = File(context.filesDir, "snap-captures").canonicalFile
    val file = File(parsed.path ?: "").canonicalFile
    if (file.parentFile != root || !file.isFile || file.extension.lowercase() != "mp4" || file.length() !in 33..MAX_BYTES) throw IllegalArgumentException("Video must be a verified Handy Media capture, maximum 30 MB")
    return file
  }
  private fun inspect(context: Context, uri: String): Movie {
    val file = owned(context, uri)
    val meta = MediaMetadataRetriever()
    val extractor = MediaExtractor()
    try {
      meta.setDataSource(file.absolutePath)
      val width = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
      val height = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
      val duration = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
      val rotation = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
      if (width < 1 || height < 1 || width.toLong() * height > 16_000_000 || duration !in 1..MAX_DURATION_MS) throw IllegalArgumentException("Video dimensions or duration exceed supported limits")
      extractor.setDataSource(file.absolutePath)
      val tracks = (0 until extractor.trackCount).map { index -> val format = extractor.getTrackFormat(index); Track(index, format.getString(MediaFormat.KEY_MIME) ?: "", format) }
      if (tracks.count { it.mime == "video/avc" } != 1 || tracks.any { it.mime != "video/avc" && it.mime != "audio/mp4a-latm" } || tracks.count { it.mime.startsWith("audio/") } > 1) throw IllegalArgumentException("Video tools support one H.264 track and optional AAC audio only")
      return Movie(file, width, height, duration, rotation, tracks)
    } finally { meta.release(); extractor.release() }
  }
  private fun target(context: Context, extension: String): File = File(context.filesDir, "snap-captures").apply { mkdirs() }.resolve("snap-${UUID.randomUUID()}.$extension")
  private fun result(context: Context, file: File, extra: Map<String, Any?> = emptyMap()): Map<String, Any?> {
    val movie = inspect(context, Uri.fromFile(file).toString())
    return mapOf<String, Any?>("uri" to Uri.fromFile(file).toString(), "width" to movie.width, "height" to movie.height, "mime" to "video/mp4", "durationMs" to movie.duration) + extra
  }
  private fun bytes(format: MediaFormat, key: String): ByteArray? {
    if (!format.containsKey(key)) return null
    val data = format.getByteBuffer(key)?.duplicate() ?: return null
    data.position(0)
    return ByteArray(data.remaining()).also { data.get(it) }
  }
  private fun compatible(first: Movie, other: Movie) {
    if (first.width != other.width || first.height != other.height || first.rotation != other.rotation || first.tracks.size != other.tracks.size) throw IllegalArgumentException("Clips must have matching dimensions, orientation and audio presence")
    for (a in first.tracks) {
      val b = other.tracks.firstOrNull { it.mime == a.mime } ?: throw IllegalArgumentException("Clip codec mismatch")
      for (key in listOf("csd-0", "csd-1", "csd-2")) {
        val x = bytes(a.format, key); val y = bytes(b.format, key)
        if ((x == null) != (y == null) || (x != null && y != null && !x.contentEquals(y))) throw IllegalArgumentException("Clip codec configuration differs; re-encoding is required before joining")
      }
      if (a.mime.startsWith("audio/")) for (key in listOf(MediaFormat.KEY_SAMPLE_RATE, MediaFormat.KEY_CHANNEL_COUNT)) {
        if (!a.format.containsKey(key) || !b.format.containsKey(key) || a.format.getInteger(key) != b.format.getInteger(key)) throw IllegalArgumentException("Audio sample rate or channel layout differs")
      }
    }
  }
  private fun syncStart(movie: Movie, requestedUs: Long): Long {
    val extractor = MediaExtractor()
    try {
      extractor.setDataSource(movie.file.absolutePath)
      extractor.selectTrack(movie.tracks.first { it.mime.startsWith("video/") }.index)
      extractor.seekTo(requestedUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
      if (extractor.sampleTime < 0 || extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC == 0) throw IllegalArgumentException("No decodable keyframe before the requested start")
      return extractor.sampleTime
    } finally { extractor.release() }
  }
  fun trim(context: Context, uri: String, startMs: Int, endMs: Int): Map<String, Any?> = operation(context) {
    val source = inspect(context, uri)
    if (startMs < 0 || endMs <= startMs || endMs.toLong() > source.duration) throw IllegalArgumentException("Trim range must be inside the captured video")
    val base = syncStart(source, startMs.toLong() * 1000)
    mux(context, listOf(source), listOf(base), listOf(endMs.toLong() * 1000), mapOf("actualStartMs" to base / 1000, "requestedStartMs" to startMs))
  }
  fun combine(context: Context, uris: List<String>): Map<String, Any?> = operation(context) {
    if (uris.size !in 2..20) throw IllegalArgumentException("Combine 2–20 captured clips")
    val movies = uris.map { inspect(context, it) }
    if (movies.sumOf { it.duration } > MAX_DURATION_MS) throw IllegalArgumentException("Combined duration must not exceed 5 minutes")
    movies.drop(1).forEach { compatible(movies[0], it) }
    mux(context, movies, movies.map { syncStart(it, 0) }, movies.map { it.duration * 1000 }, emptyMap())
  }
  private fun mux(context: Context, movies: List<Movie>, starts: List<Long>, ends: List<Long>, extra: Map<String, Any?>): Map<String, Any?> {
    val partial = target(context, "partial.mp4")
    val completed = target(context, "mp4")
    var muxer: MediaMuxer? = null
    var started = false
    try {
      val activeMuxer = MediaMuxer(partial.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
      muxer = activeMuxer
      activeMuxer.setOrientationHint(movies[0].rotation)
      val outputTracks = movies[0].tracks.associate { it.mime to activeMuxer.addTrack(it.format) }
      activeMuxer.start(); started = true
      val buffer = ByteBuffer.allocateDirect(4 * 1024 * 1024)
      val info = MediaCodec.BufferInfo()
      val previousPts = mutableMapOf<String, Long>()
      var offset = 0L
      for ((clipIndex, movie) in movies.withIndex()) {
        checkCanceled()
        var segmentEnd = 0L
        var videoSamples = 0
        for (track in movie.tracks) {
          val extractor = MediaExtractor()
          try {
            extractor.setDataSource(movie.file.absolutePath); extractor.selectTrack(track.index)
            extractor.seekTo(starts[clipIndex], MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            while (extractor.sampleTime >= 0 && extractor.sampleTime < ends[clipIndex]) {
              checkCanceled()
              val pts = extractor.sampleTime
              if (pts < starts[clipIndex]) { extractor.advance(); continue }
              if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_ENCRYPTED != 0) throw IllegalArgumentException("Encrypted media is unsupported")
              if (Build.VERSION.SDK_INT >= 28 && extractor.sampleSize > buffer.capacity()) throw IllegalArgumentException("Video sample exceeds the 4 MB memory budget")
              buffer.clear()
              val size = extractor.readSampleData(buffer, 0)
              if (size < 0) break
              val outputPts = pts - starts[clipIndex] + offset
              if (outputPts <= (previousPts[track.mime] ?: -1L)) throw IllegalArgumentException("Non-monotonic samples require transcoding; this clip cannot be safely joined")
              info.set(0, size, outputPts, extractor.sampleFlags and MediaCodec.BUFFER_FLAG_KEY_FRAME)
              activeMuxer.writeSampleData(outputTracks.getValue(track.mime), buffer, info)
              previousPts[track.mime] = outputPts
              val sampleDuration = if (track.mime.startsWith("audio/")) 1024_000_000L / track.format.getInteger(MediaFormat.KEY_SAMPLE_RATE) else 33334L
              segmentEnd = maxOf(segmentEnd, pts - starts[clipIndex] + sampleDuration)
              if (track.mime.startsWith("video/")) videoSamples++
              if (partial.length() > 25_000_000) throw IllegalArgumentException("Processed video exceeds the 25 MB budget")
              extractor.advance()
            }
          } finally { extractor.release() }
          // Surface recordings can be variable-frame-rate: a static screen may
          // contain only a few samples. Preserve the selected hold duration,
          // rather than collapsing the last still frame to a nominal 33 ms.
          if (clipIndex == movies.lastIndex && previousPts.containsKey(track.mime)) {
            val endPts = offset + ends[clipIndex] - starts[clipIndex]
            if (endPts > previousPts.getValue(track.mime)) {
              info.set(0, 0, endPts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
              activeMuxer.writeSampleData(outputTracks.getValue(track.mime), ByteBuffer.allocate(0), info)
            }
          }
        }
        if (videoSamples == 0) throw IllegalArgumentException("Selected range contains no decodable video frames")
        offset += maxOf(segmentEnd, ends[clipIndex] - starts[clipIndex])
      }
      checkCanceled(); activeMuxer.stop(); started = false; activeMuxer.release(); muxer = null
      if (partial.length() !in 33..MAX_BYTES) throw IllegalStateException("Video output size could not be verified")
      if (!partial.renameTo(completed)) throw IllegalStateException("Video output could not be saved atomically")
      val output = result(context, completed, extra)
      checkCanceled(); CaptureBridge.publish("complete", output)
      return output
    } catch (error: Exception) { completed.delete(); throw error }
    finally {
      if (started) try { muxer?.stop() } catch (_: Exception) {}
      try { muxer?.release() } catch (_: Exception) {}
      partial.delete()
    }
  }
  fun frame(context: Context, uri: String, timeMs: Int): Map<String, Any?> = operation(context) {
    val movie = inspect(context, uri)
    if (timeMs < 0 || timeMs.toLong() >= movie.duration) throw IllegalArgumentException("Frame time must be inside the video duration")
    val extractor = MediaMetadataRetriever()
    var original: Bitmap? = null
    var bitmap: Bitmap? = null
    val output = target(context, "png")
    try {
      extractor.setDataSource(movie.file.absolutePath)
      val scale = min(1.0, min(2048.0 / maxOf(movie.width, movie.height), sqrt(2_000_000.0 / movie.width / movie.height)))
      val width = maxOf(1, (movie.width * scale).toInt())
      val height = maxOf(1, (movie.height * scale).toInt())
      original = if (Build.VERSION.SDK_INT >= 27) extractor.getScaledFrameAtTime(timeMs.toLong() * 1000, MediaMetadataRetriever.OPTION_CLOSEST, width, height) else extractor.getFrameAtTime(timeMs.toLong() * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
      val frame = original ?: throw IllegalStateException("No frame is available at the requested time")
      val rendered = if (frame.width > width || frame.height > height) Bitmap.createScaledBitmap(frame, width, height, true) else frame
      bitmap = rendered
      checkCanceled()
      output.outputStream().use { if (!rendered.compress(Bitmap.CompressFormat.PNG, 100, it)) throw IllegalStateException("Frame PNG encoding failed") }
      if (output.length() !in 9..8_000_000) throw IllegalArgumentException("Frame PNG exceeds 8 MB")
      checkCanceled()
      val result = mapOf<String, Any?>("uri" to Uri.fromFile(output).toString(), "width" to rendered.width, "height" to rendered.height, "mime" to "image/png")
      CaptureBridge.publish("complete", result)
      result
    } catch (error: Exception) { output.delete(); throw error }
    finally { if (bitmap !== original) bitmap?.recycle(); original?.recycle(); extractor.release() }
  }
}
