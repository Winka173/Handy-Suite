import Flutter
import Foundation

/// A single Flutter reply. All processors complete on the platform thread.
final class CaptureReply {
  private var callback: FlutterResult?
  init(_ callback: @escaping FlutterResult) { self.callback = callback }
  func resolve(_ value: Any? = nil) { finish(value) }
  func reject(_ code: String, _ message: String) {
    finish(FlutterError(code: code, message: message, details: nil))
  }
  private func finish(_ value: Any?) {
    precondition(Thread.isMainThread)
    let reply = callback
    callback = nil
    reply?(value)
  }
}
