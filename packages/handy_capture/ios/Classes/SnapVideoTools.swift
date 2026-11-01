// Ported from retained snap-capture iOS AVFoundation tools.
import Flutter
import AVFoundation
import UIKit

enum SnapVideoTools {
  private(set) static var processing = false
  private static var exportSession: AVAssetExportSession?
  private static let cancelLock = NSLock()
  private static var canceled = false
  private struct Movie {
    let url: URL
    let asset: AVURLAsset
    let video: AVAssetTrack
    let audio: AVAssetTrack?
    let duration: Double
  }
  static func cancel() {
    cancelLock.lock(); canceled = true; cancelLock.unlock()
    exportSession?.cancelExport()
  }
  private static func checkCanceled() throws {
    cancelLock.lock(); let value = canceled; cancelLock.unlock()
    if value { throw VideoError("Video operation canceled") }
  }
  private static func begin() throws {
    guard !processing else { throw VideoError("Another video operation is active") }
    processing = true
    cancelLock.lock(); canceled = false; cancelLock.unlock()
  }
  private static func folder() throws -> URL {
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("handy-captures", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
    let used = try files.reduce(0) { try $0 + ($1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
    guard used <= 170_000_000 else { throw VideoError("Clear old captured files before processing another clip") }
    return directory
  }
  static func ownedFile(_ uri: String) throws -> URL {
    guard uri.utf8.count <= 2048, !uri.unicodeScalars.contains(where: { $0.value < 32 }),
      let url = URL(string: uri), url.isFileURL, url.host == nil || url.host == "",
      url.query == nil, url.fragment == nil else { throw VideoError("Invalid owned capture URI") }
    let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
    let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("handy-captures", isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
    let values = try canonical.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
    let limit = canonical.pathExtension == "png" ? 8_000_000 : 30_000_000
    guard canonical.deletingLastPathComponent() == root, ["png", "mp4"].contains(canonical.pathExtension),
      values.isRegularFile == true, let count = values.fileSize, count >= 8, count <= limit else { throw VideoError("Choose an owned capture within size limits") }
    return canonical
  }
  static func read(_ uri: String, promise: CaptureReply) {
    do { try begin() } catch { promise.reject("E_BUSY", error.localizedDescription); return }
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let url = try ownedFile(uri)
        let bytes = try Data(contentsOf: url)
        try checkCanceled()
        let png = bytes.starts(with: [137, 80, 78, 71, 13, 10, 26, 10])
        let mp4 = bytes.count > 32 && String(data: bytes.subdata(in: 4..<8), encoding: .ascii) == "ftyp"
        guard url.pathExtension == "png" ? png : mp4 else { throw VideoError("Capture signature is invalid") }
        DispatchQueue.main.async {
          do { try checkCanceled(); processing = false; promise.resolve(FlutterStandardTypedData(bytes: bytes)) }
          catch { fail(error, promise: promise) }
        }
      } catch { DispatchQueue.main.async { fail(error, promise: promise) } }
    }
  }
  static func importVideo(_ bytes: Data, promise: CaptureReply, completed: @escaping ([String: Any]) -> Void) {
    do { try begin() } catch { promise.reject("E_BUSY", error.localizedDescription); return }
    DispatchQueue.global(qos: .userInitiated).async {
      var source: URL?
      do {
        guard bytes.count > 32 && bytes.count <= 30_000_000,
          String(data: bytes.subdata(in: 4..<8), encoding: .ascii) == "ftyp" else { throw VideoError("Choose MP4 up to 30 MB") }
        let url = try folder().appendingPathComponent("import-\(UUID().uuidString).mp4")
        source = url
        try bytes.write(to: url, options: .atomic)
        let clip = try movie(url.absoluteString)
        try checkCanceled()
        DispatchQueue.main.async {
          let cleanedReply = CaptureReply { value in
            try? FileManager.default.removeItem(at: url)
            if let error = value as? FlutterError { promise.reject(error.code, error.message ?? "Import failed") }
            else { promise.resolve(value) }
          }
          do { try checkCanceled(); try compose([clip], ranges: [(0, clip.duration)], promise: cleanedReply, completed: completed) }
          catch { fail(error, promise: cleanedReply) }
        }
      } catch {
        if let source { try? FileManager.default.removeItem(at: source) }
        DispatchQueue.main.async { fail(error, promise: promise) }
      }
    }
  }
  private static func movie(_ uri: String) throws -> Movie {
    let url = try ownedFile(uri)
    let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
    let root = try folder().standardizedFileURL.resolvingSymlinksInPath()
    guard canonical.deletingLastPathComponent() == root, canonical.pathExtension.lowercased() == "mp4" else { throw VideoError("Video must be in Handy Snap's private captured-file library") }
    let bytes = try canonical.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard bytes > 32 && bytes <= 30_000_000 else { throw VideoError("Video must be 1–30 MB") }
    let asset = AVURLAsset(url: canonical)
    guard let track = asset.tracks(withMediaType: .video).first, asset.tracks(withMediaType: .video).count == 1, asset.tracks(withMediaType: .audio).count <= 1 else { throw VideoError("One video and optional single audio track are supported") }
    let duration = CMTimeGetSeconds(asset.duration), size = track.naturalSize
    guard duration.isFinite && duration > 0 && duration <= 300 && size.width > 0 && size.height > 0 && size.width * size.height <= 16_000_000 else { throw VideoError("Video exceeds five minutes or the pixel budget") }
    return Movie(url: canonical, asset: asset, video: track, audio: asset.tracks(withMediaType: .audio).first, duration: duration)
  }
  private static func compatible(_ first: Movie, _ other: Movie) throws {
    guard first.video.naturalSize == other.video.naturalSize, first.video.preferredTransform == other.video.preferredTransform, (first.audio == nil) == (other.audio == nil) else { throw VideoError("Clips must match dimensions, orientation and audio presence") }
    for (a, b) in [(first.video, other.video), (first.audio, other.audio)] {
      if let a, let b {
        let formatsA = a.formatDescriptions as! [CMFormatDescription], formatsB = b.formatDescriptions as! [CMFormatDescription]
        guard formatsA.count == formatsB.count && zip(formatsA, formatsB).allSatisfy({ CMFormatDescriptionEqual($0.0, $0.1) }) else { throw VideoError("Clip codec configurations differ; convert them before combining") }
      }
    }
  }
  static func trim(_ uri: String, startMs: Int, endMs: Int, promise: CaptureReply, completed: @escaping ([String: Any]) -> Void) {
    do {
      try begin()
      let source = try movie(uri)
      guard startMs >= 0 && endMs > startMs && Double(endMs) <= source.duration * 1000 else { throw VideoError("Trim range must be inside the video") }
      try compose([source], ranges: [(Double(startMs) / 1000, Double(endMs) / 1000)], promise: promise, completed: completed)
    } catch { fail(error, promise: promise) }
  }
  static func combine(_ uris: [String], promise: CaptureReply, completed: @escaping ([String: Any]) -> Void) {
    do {
      try begin()
      guard uris.count >= 2 && uris.count <= 20 else { throw VideoError("Combine 2–20 captured videos") }
      let movies = try uris.map(movie)
      guard movies.reduce(0, { $0 + $1.duration }) <= 300 else { throw VideoError("Combined duration exceeds five minutes") }
      for other in movies.dropFirst() { try compatible(movies[0], other) }
      try compose(movies, ranges: movies.map { (0, $0.duration) }, promise: promise, completed: completed)
    } catch { fail(error, promise: promise) }
  }
  private static func compose(_ movies: [Movie], ranges: [(Double, Double)], promise: CaptureReply, completed: @escaping ([String: Any]) -> Void) throws {
    let composition = AVMutableComposition()
    guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw VideoError("Video composition unavailable") }
    video.preferredTransform = movies[0].video.preferredTransform
    let audio = movies[0].audio != nil ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) : nil
    var cursor = CMTime.zero
    for (index, movie) in movies.enumerated() {
      try checkCanceled()
      let start = CMTime(seconds: ranges[index].0, preferredTimescale: 600), requestedEnd = CMTime(seconds: ranges[index].1, preferredTimescale: 600)
      let duration = CMTimeMinimum(CMTimeSubtract(requestedEnd, start), CMTimeSubtract(movie.video.timeRange.duration, start))
      guard CMTimeGetSeconds(duration) > 0 else { throw VideoError("Selected range has no video frames") }
      let range = CMTimeRange(start: CMTimeAdd(movie.video.timeRange.start, start), duration: duration)
      try video.insertTimeRange(range, of: movie.video, at: cursor)
      if let sourceAudio = movie.audio, let audio {
        let overlap = CMTimeRangeGetIntersection(range, otherRange: sourceAudio.timeRange)
        if CMTimeGetSeconds(overlap.duration) > 0 { try audio.insertTimeRange(overlap, of: sourceAudio, at: CMTimeAdd(cursor, CMTimeSubtract(overlap.start, range.start))) }
      }
      cursor = CMTimeAdd(cursor, duration)
    }
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset1280x720) else { throw VideoError("Video re-encoding unavailable") }
    let target = try folder().appendingPathComponent("snap-\(UUID().uuidString).mp4")
    exporter.outputURL = target; exporter.outputFileType = .mp4
    exportSession = exporter
    exporter.exportAsynchronously {
      DispatchQueue.main.async {
        do {
          try checkCanceled()
          guard exporter.status == .completed else { throw VideoError(exporter.error?.localizedDescription ?? "Video export did not complete") }
          let result = try videoResult(target)
          processing = false; exportSession = nil; completed(result); promise.resolve(result)
        } catch { try? FileManager.default.removeItem(at: target); fail(error, promise: promise) }
      }
    }
  }
  static func transform(_ uri: String, rotation: Int, maxEdge: Int, mute: Bool, promise: CaptureReply, completed: @escaping ([String: Any]) -> Void) {
    var target: URL?
    do {
      try begin()
      guard [0, 90, 180, 270].contains(rotation), [240, 480, 720, 1280].contains(maxEdge) else { throw VideoError("Invalid transform dimensions or rotation") }
      let source = try movie(uri), composition = AVMutableComposition()
      guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw VideoError("Video composition unavailable") }
      let duration = CMTimeMinimum(source.video.timeRange.duration, source.asset.duration)
      let range = CMTimeRange(start: source.video.timeRange.start, duration: duration)
      try video.insertTimeRange(range, of: source.video, at: .zero)
      if !mute, let sourceAudio = source.audio, let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
        let overlap = CMTimeRangeGetIntersection(range, otherRange: sourceAudio.timeRange)
        if CMTimeGetSeconds(overlap.duration) > 0 { try audio.insertTimeRange(overlap, of: sourceAudio, at: CMTimeSubtract(overlap.start, range.start)) }
      }
      var transform = source.video.preferredTransform.concatenating(CGAffineTransform(rotationAngle: CGFloat(rotation) * .pi / 180))
      let rectangle = CGRect(origin: .zero, size: source.video.naturalSize).applying(transform).standardized
      let scale = min(1, CGFloat(maxEdge) / max(rectangle.width, rectangle.height))
      let width = max(2, Int(rectangle.width * scale) / 2 * 2), height = max(2, Int(rectangle.height * scale) / 2 * 2)
      transform = transform.concatenating(CGAffineTransform(translationX: -rectangle.minX, y: -rectangle.minY))
        .concatenating(CGAffineTransform(scaleX: CGFloat(width) / rectangle.width, y: CGFloat(height) / rectangle.height))
      let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: video)
      layer.setTransform(transform, at: .zero)
      let instruction = AVMutableVideoCompositionInstruction()
      instruction.timeRange = CMTimeRange(start: .zero, duration: duration); instruction.layerInstructions = [layer]
      let settings = AVMutableVideoComposition()
      settings.instructions = [instruction]; settings.renderSize = CGSize(width: CGFloat(width), height: CGFloat(height))
      settings.frameDuration = CMTime(value: 1, timescale: 30)
      guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { throw VideoError("H.264 export unavailable") }
      let destination = try folder().appendingPathComponent("snap-\(UUID().uuidString).mp4"); target = destination
      exporter.outputURL = destination; exporter.outputFileType = .mp4; exporter.videoComposition = settings
      exportSession = exporter
      let timer = DispatchSource.makeTimerSource(queue: .main)
      let deadline = Date().addingTimeInterval(180)
      timer.schedule(deadline: .now() + 1, repeating: 1)
      timer.setEventHandler {
        let count = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if Date() > deadline || count > 30_000_000 { exporter.cancelExport() }
      }
      timer.resume()
      exporter.exportAsynchronously {
        DispatchQueue.main.async {
          timer.cancel()
          do {
            try checkCanceled()
            guard exporter.status == .completed else { throw VideoError("Video transform failed or exceeded limits") }
            let output = AVURLAsset(url: destination)
            guard let outputVideo = output.tracks(withMediaType: .video).first,
              !outputVideo.formatDescriptions.isEmpty,
              outputVideo.formatDescriptions.allSatisfy({ CMFormatDescriptionGetMediaSubType($0 as! CMFormatDescription) == kCMVideoCodecType_H264 }),
              !mute || output.tracks(withMediaType: .audio).isEmpty else { throw VideoError("Output codec or audio verification failed") }
            let result = try videoResult(destination)
            guard let outputWidth = result["width"] as? Int, let outputHeight = result["height"] as? Int, max(outputWidth, outputHeight) <= maxEdge else { throw VideoError("Output exceeds requested dimensions") }
            processing = false; exportSession = nil; completed(result); promise.resolve(result)
          } catch { try? FileManager.default.removeItem(at: destination); fail(error, promise: promise) }
        }
      }
    } catch { if let target { try? FileManager.default.removeItem(at: target) }; fail(error, promise: promise) }
  }
  private static func videoResult(_ url: URL) throws -> [String: Any] {
    let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    let asset = AVURLAsset(url: url), duration = CMTimeGetSeconds(asset.duration)
    guard bytes > 32 && bytes <= 30_000_000, let track = asset.tracks(withMediaType: .video).first, duration.isFinite && duration > 0 && duration <= 300 else { throw VideoError("Processed video size/duration could not be verified") }
    let size = track.naturalSize.applying(track.preferredTransform)
    guard abs(size.width) >= 1, abs(size.height) >= 1, abs(size.width * size.height) <= 16_000_000 else { throw VideoError("Invalid output dimensions") }
    return ["uri": url.absoluteString, "width": Int(abs(size.width)), "height": Int(abs(size.height)), "mime": "video/mp4", "durationMs": Int(duration * 1000)]
  }
  static func frame(_ uri: String, timeMs: Int, promise: CaptureReply, completed: @escaping ([String: Any]) -> Void) {
    do { try begin() } catch { promise.reject("E_VIDEO", error.localizedDescription); return }
    DispatchQueue.global(qos: .userInitiated).async {
      var target: URL?
      do {
        let source = try movie(uri)
        guard timeMs >= 0 && Double(timeMs) < source.duration * 1000 else { throw VideoError("Frame time must be inside the video") }
        let generator = AVAssetImageGenerator(asset: source.asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1440, height: 1440)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        var actualTime = CMTime.zero
        let requested = CMTimeMinimum(CMTime(seconds: Double(timeMs) / 1000, preferredTimescale: 600), CMTimeSubtract(CMTimeRangeGetEnd(source.video.timeRange), CMTime(value: 1, timescale: 600)))
        let frame = try generator.copyCGImage(at: requested, actualTime: &actualTime)
        try checkCanceled()
        guard let data = UIImage(cgImage: frame).pngData(), data.count <= 8_000_000 else { throw VideoError("Frame PNG exceeds 8 MB") }
        let output = try folder().appendingPathComponent("snap-\(UUID().uuidString).png"); target = output
        try data.write(to: output, options: .atomic)
        try checkCanceled()
        let result: [String: Any] = ["uri": output.absoluteString, "width": frame.width, "height": frame.height, "mime": "image/png", "frameTimeMs": Int(CMTimeGetSeconds(actualTime) * 1000)]
        DispatchQueue.main.async {
          do { try checkCanceled(); processing = false; completed(result); promise.resolve(result) }
          catch { try? FileManager.default.removeItem(at: output); fail(error, promise: promise) }
        }
      } catch {
        if let target { try? FileManager.default.removeItem(at: target) }
        DispatchQueue.main.async { fail(error, promise: promise) }
      }
    }
  }
  private static func fail(_ error: Error, promise: CaptureReply) { processing = false; exportSession = nil; promise.reject("E_VIDEO", error.localizedDescription) }
}
private struct VideoError: LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}
