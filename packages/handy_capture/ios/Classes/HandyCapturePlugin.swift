// Ported from the retained Snap ReplayKit implementation; Flutter bindings only.
import Flutter
import ReplayKit
import AVFoundation
import UIKit

public class HandyCapturePlugin: NSObject, FlutterPlugin {
  private var recording = false
  private var pending = false
  private var rawURL: URL?
  private var lastResult: [String: Any]?
  private var lastError: String?
  private var stopTimer: DispatchWorkItem?
  private var backgroundObserver: NSObjectProtocol?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var generation = 0
  private var discardRequested = false
  private var cancelPromise: CaptureReply?
  private var exportSession: AVAssetExportSession?
  private let historyKey = "handy-media-last-native-capture-v1"


  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = HandyCapturePlugin()
    let channel = FlutterMethodChannel(name: "handy_capture", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  override init() {
    super.init()
      self.lastResult = self.restoredResult()
      self.backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
        guard let self, self.recording, !self.pending else { return }
        self.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finish Handy Media app recording") { [weak self] in
          self?.lastError = "Recording finalization exceeded the system background time; return to Handy Media"
          self?.discardRequested = true
          self?.exportSession?.cancelExport()
          self?.endBackgroundTask()
        }
        self.finishRecording(nil)
      }

  }
  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    cancel(CaptureReply { _ in })
  }
  deinit {
    if let observer = backgroundObserver { NotificationCenter.default.removeObserver(observer) }
    stopTimer?.cancel()
  }
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let promise = CaptureReply(result)
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "capabilities":
      promise.resolve(["screenshot": false, "recording": RPScreenRecorder.shared().isAvailable,
        "videoTools": true, "scope": "this-app", "audio": "app", "trimAccuracy": "reencoded"])
    case "status":
      if !recording && !pending { lastResult = restoredResult() }
      promise.resolve(["recording": recording, "pending": pending || SnapVideoTools.processing,
        "lastResult": lastResult as Any? ?? NSNull(), "error": lastError as Any? ?? NSNull()])
    case "screenshot":
      promise.reject("E_UNSUPPORTED", "iOS cannot capture other apps. Use the system screenshot buttons, then import the image.")
    case "startRecording": startRecording(promise)
    case "stopRecording": finishRecording(promise)
    case "cancel": cancel(promise)
    case "clear": clear(promise)
    case "trim", "frame", "combine", "importVideo", "read", "transform":
      guard !pending && !recording && !SnapVideoTools.processing else {
        promise.reject("E_BUSY", "Stop capture or video processing first"); return
      }
      do {
        switch call.method {
        case "transform":
          guard let uri = args["uri"] as? String, let rotation = args["rotation"] as? Int, let edge = args["maxEdge"] as? Int, let mute = args["mute"] as? Bool else { throw CaptureError("Invalid video transform arguments") }
          SnapVideoTools.transform(uri, rotation: rotation, maxEdge: edge, mute: mute, promise: promise) { self.storeResult($0) }
        case "trim":
          guard let uri = args["uri"] as? String, let start = args["startMs"] as? Int, let end = args["endMs"] as? Int else { throw CaptureError("Invalid trim arguments") }
          trim(uri, startMs: start, endMs: end, promise: promise)
        case "frame":
          guard let uri = args["uri"] as? String, let time = args["timeMs"] as? Int else { throw CaptureError("Invalid frame arguments") }
          frame(uri, timeMs: time, promise: promise)
        case "combine":
          guard let uris = args["uris"] as? [String] else { throw CaptureError("Invalid clip arguments") }
          combine(uris, promise: promise)
        case "importVideo":
          guard let bytes = args["bytes"] as? FlutterStandardTypedData else { throw CaptureError("Choose MP4 bytes") }
          SnapVideoTools.importVideo(bytes.data, promise: promise) { self.storeResult($0) }
        default:
          guard let uri = args["uri"] as? String else { throw CaptureError("Choose an owned capture") }
          SnapVideoTools.read(uri, promise: promise)
        }
      } catch { promise.reject("E_ARGUMENT", error.localizedDescription) }
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func startRecording(_ promise: CaptureReply) {
    guard !self.recording && !self.pending && !SnapVideoTools.processing && !RPScreenRecorder.shared().isRecording else { promise.reject("E_BUSY", "Another capture or video session is active"); return }
      guard RPScreenRecorder.shared().isAvailable else { promise.reject("E_UNAVAILABLE", "ReplayKit app recording is unavailable on this device"); return }
      do {
        let directory = try self.directory()
        let target = directory.appendingPathComponent("snap-\(UUID().uuidString)-raw.mp4")
        self.rawURL = target
        self.pending = true; self.lastError = nil; self.discardRequested = false
        self.generation += 1
        let token = self.generation
        RPScreenRecorder.shared().isMicrophoneEnabled = false
        RPScreenRecorder.shared().isCameraEnabled = false
        RPScreenRecorder.shared().startRecording { error in
          DispatchQueue.main.async {
            if token != self.generation {
              if error == nil {
                RPScreenRecorder.shared().stopRecording(withOutput: target) { _ in
                  DispatchQueue.main.async {
                    self.failRecording("Recording start canceled", source: target, output: nil, promise: promise)
                  }
                }
              } else { self.failRecording("Recording start canceled", source: target, output: nil, promise: promise) }
              return
            }
            self.pending = false
            if let error { self.lastError = error.localizedDescription; self.rawURL = nil; promise.reject("E_CAPTURE", error.localizedDescription); return }
            self.recording = true
            let timer = DispatchWorkItem { [weak self] in self?.finishRecording(nil) }
            self.stopTimer = timer; DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: timer)
            promise.resolve(["recording": true])
            if UIApplication.shared.applicationState != .active { self.finishRecording(nil) }
          }
        }
      } catch { promise.reject("E_STORAGE", error.localizedDescription) }
  }

  private func cancel(_ promise: CaptureReply) {
    guard cancelPromise == nil else { promise.reject("E_BUSY", "Cancellation is already pending"); return }
    if SnapVideoTools.processing { SnapVideoTools.cancel(); promise.resolve(); return }
      self.generation += 1; self.discardRequested = true
      if self.recording && !self.pending {
        self.cancelPromise = promise; self.finishRecording(nil)
      } else if self.recording && self.pending {
        // A ReplayKit stop is already finalizing; do not allow a new session
        // until that callback has discarded its file and resolved cancellation.
        self.cancelPromise = promise
      } else if let export = self.exportSession {
        self.cancelPromise = promise; export.cancelExport()
      } else if self.pending {
        self.cancelPromise = promise
      } else { promise.resolve() }
  }

  private func clear(_ promise: CaptureReply) {
    guard !self.pending && !self.recording && !SnapVideoTools.processing else { promise.reject("E_BUSY", "Stop capture and video processing before clearing its files"); return }
      do {
        let directory = try self.directory(checkBudget: false)
        for item in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) { try FileManager.default.removeItem(at: item) }
        self.lastResult = nil; UserDefaults.standard.removeObject(forKey: self.historyKey); promise.resolve()
      } catch { promise.reject("E_CLEAR", error.localizedDescription) }
  }

  private func trim(_ uri: String, startMs: Int, endMs: Int, promise: CaptureReply) {
    guard !self.pending && !self.recording else { promise.reject("E_BUSY", "Stop capture first"); return }
      SnapVideoTools.trim(uri, startMs: startMs, endMs: endMs, promise: promise) { result in self.storeResult(result) }
  }

  private func combine(_ uris: [String], promise: CaptureReply) {
    guard !self.pending && !self.recording else { promise.reject("E_BUSY", "Stop capture first"); return }
      SnapVideoTools.combine(uris, promise: promise) { result in self.storeResult(result) }
  }

  private func frame(_ uri: String, timeMs: Int, promise: CaptureReply) {
    guard !self.pending && !self.recording else { promise.reject("E_BUSY", "Stop capture first"); return }
      SnapVideoTools.frame(uri, timeMs: timeMs, promise: promise) { result in self.storeResult(result) }
  }
  private func directory(checkBudget: Bool = true) throws -> URL {
    let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("handy-captures", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    var mutable = root
    var values = URLResourceValues(); values.isExcludedFromBackup = true
    try mutable.setResourceValues(values)
    let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey])
    let used = try files.reduce(0) { try $0 + ($1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
    if checkBudget && used > 170_000_000 { throw CaptureError("Captured files exceed the library budget; explicitly clear old captures first") }
    return root
  }
  private func finishRecording(_ promise: CaptureReply?) {
    if self.pending { promise?.reject("E_BUSY", "Capture is starting or finishing"); return }
    guard self.recording, let source = self.rawURL else {
      if let result = restoredResult(), result["mime"] as? String == "video/mp4" { promise?.resolve(result) }
      else { promise?.reject("E_NOT_RECORDING", "No recording is running") }
      return
    }
    self.stopTimer?.cancel(); self.stopTimer = nil
    self.pending = true
    RPScreenRecorder.shared().stopRecording(withOutput: source) { error in
      DispatchQueue.main.async {
        self.recording = false
        if let error { self.failRecording(error.localizedDescription, source: source, output: nil, promise: promise); return }
        if self.discardRequested { self.failRecording("Capture canceled", source: source, output: nil, promise: promise); return }
        let asset = AVURLAsset(url: source)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { self.failRecording("Video compression unavailable", source: source, output: nil, promise: promise); return }
        let target = source.deletingLastPathComponent().appendingPathComponent("snap-\(UUID().uuidString).mp4")
        export.outputURL = target; export.outputFileType = .mp4
        self.exportSession = export
        export.exportAsynchronously {
          DispatchQueue.main.async {
            do {
              guard !self.discardRequested, export.status == .completed else { throw CaptureError(export.error?.localizedDescription ?? "Video export did not complete") }
              let size = try target.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
              let movie = AVURLAsset(url: target)
              guard let track = movie.tracks(withMediaType: .video).first, size > 32 && size <= 30_000_000 else { throw CaptureError("Video is empty or exceeds 30 MB") }
              let dimensions = track.naturalSize.applying(track.preferredTransform), duration = CMTimeGetSeconds(movie.duration)
              guard duration.isFinite && duration > 0 && duration <= 300 && abs(dimensions.width * dimensions.height) <= 16_000_000 else { throw CaptureError("Video duration could not be verified") }
              let result: [String: Any] = ["uri": target.absoluteString, "width": Int(abs(dimensions.width)), "height": Int(abs(dimensions.height)), "mime": "video/mp4", "durationMs": Int(duration * 1000)]
              try? FileManager.default.removeItem(at: source)
              self.rawURL = nil; self.pending = false; self.exportSession = nil; self.storeResult(result); self.endBackgroundTask(); promise?.resolve(result)
            } catch { self.failRecording(error.localizedDescription, source: source, output: target, promise: promise) }
          }
        }
      }
    }
  }
  private func failRecording(_ message: String, source: URL, output: URL?, promise: CaptureReply?) {
    try? FileManager.default.removeItem(at: source)
    if let output { try? FileManager.default.removeItem(at: output) }
    self.pending = false; self.recording = false; self.rawURL = nil; self.lastError = message
    self.exportSession = nil
    self.cancelPromise?.resolve(); self.cancelPromise = nil
    self.endBackgroundTask(); promise?.reject("E_CAPTURE", message)
  }
  private func endBackgroundTask() {
    if self.backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(self.backgroundTask); self.backgroundTask = .invalid }
  }
  private func storeResult(_ result: [String: Any]) {
    self.lastResult = result; self.lastError = nil
    UserDefaults.standard.set(result, forKey: historyKey)
  }
  private func restoredResult() -> [String: Any]? {
    guard let result = UserDefaults.standard.dictionary(forKey: historyKey),
      let uri = result["uri"] as? String,
      (try? SnapVideoTools.ownedFile(uri)) != nil else { return nil }
    return result
  }
}
private struct CaptureError: LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}
