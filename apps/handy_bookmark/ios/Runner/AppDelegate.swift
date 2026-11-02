import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var shares: FlutterMethodChannel?
  private let queue = ShareQueue()
  override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SaveShares")!
    shares = FlutterMethodChannel(name: "handy.save/share", binaryMessenger: registrar.messenger())
    shares?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      do {
        switch call.method {
        case "drain": result(try self.queue.drain())
        case "ack":
          guard let args = call.arguments as? [String: Any], let id = args["id"] as? String else { throw ShareQueue.QueueError() }
          result(try self.queue.ack(id))
        default: result(FlutterMethodNotImplemented)
        }
      } catch { result(FlutterError(code: "SHARE_QUEUE_ERROR", message: "Unable to access pending shares", details: nil)) }
    }
  }
  func sharesMayBePending() { shares?.invokeMethod("incoming", arguments: nil) }
}
