import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var shares: FlutterMethodChannel?
  private let queue = ShareQueue()
  private var home: FlutterMethodChannel?
  private var pendingHomeLink: String?
  private var fileBridge: FlutterMethodChannel?
  private let fileExport = BoardsFileExport()
  override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let fileRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "BoardsFiles")!
    fileBridge = FlutterMethodChannel(name: "handy.boards/files", binaryMessenger: fileRegistrar.messenger())
    fileBridge?.setMethodCallHandler { [weak self] call, result in self?.fileExport.call(call, result: result) }
    let homeRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "BoardsHome")!
    home = FlutterMethodChannel(name: "handy.boards/home", binaryMessenger: homeRegistrar.messenger())
    home?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "pending": result(self.pendingHomeLink); self.pendingHomeLink = nil
      case "ack": if self.pendingHomeLink == call.arguments as? String { self.pendingHomeLink = nil }; result(nil)
      case "publish":
        do {
          guard let args = call.arguments as? [String: Any],
                let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.handysuite.boards") else {
            result(FlutterError(code: "HOME_GROUP", message: "App Group is unavailable", details: nil)); return
          }
          var payload = args
          payload["updated"] = Date().timeIntervalSince1970
          try JSONSerialization.data(withJSONObject: payload).write(to: group.appendingPathComponent("boards-widget.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
          WidgetCenter.shared.reloadTimelines(ofKind: "BoardsDueWidget")
          let vi = args["vi"] as? Bool == true
          UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(type: "capture", localizedTitle: vi ? "Thêm việc" : "Quick capture", localizedSubtitle: nil, icon: UIApplicationShortcutIcon(type: .add), userInfo: nil),
            UIApplicationShortcutItem(type: "today", localizedTitle: vi ? "Hôm nay" : "Today", localizedSubtitle: nil, icon: UIApplicationShortcutIcon(type: .date), userInfo: nil)
          ]
          result(nil)
        } catch { result(FlutterError(code: "HOME_WRITE", message: "Unable to update widget", details: nil)) }
      default: result(FlutterMethodNotImplemented)
      }
    }
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BoardsShares")!
    shares = FlutterMethodChannel(name: "handy.boards/share", binaryMessenger: registrar.messenger())
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
  func openHome(_ url: URL) {
    guard url.scheme == "handy-boards", ["today", "capture", "task"].contains(url.host ?? "") else { return }
    pendingHomeLink = url.absoluteString
    home?.invokeMethod("open", arguments: url.absoluteString)
  }
}

final class BoardsFileExport: NSObject, UIDocumentPickerDelegate {
  private var pending: FlutterResult?
  private var picker: UIDocumentPickerViewController?
  func call(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "cancel" {
      picker?.dismiss(animated: true); finish(nil); result(nil); return
    }
    guard call.method == "save" else { result(FlutterMethodNotImplemented); return }
    guard pending == nil else { result(FlutterError(code: "FILE_BUSY", message: "A file operation is already open", details: nil)); return }
    guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else { result(FlutterError(code: "FILE_SOURCE", message: "Export source unavailable", details: nil)); return }
    let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
    let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.resolvingSymlinksInPath().path + "/"
    guard url.path.hasPrefix(cache), FileManager.default.fileExists(atPath: url.path),
          let root = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else {
      result(FlutterError(code: "FILE_SOURCE", message: "Export source unavailable", details: nil)); return
    }
    var presenter = root
    while let next = presenter.presentedViewController { presenter = next }
    let controller = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    controller.delegate = self; pending = result; picker = controller
    presenter.present(controller, animated: true)
  }
  private func finish(_ value: Any?) { let result = pending; pending = nil; picker = nil; result?(value) }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish(nil) }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { finish(urls.first?.absoluteString) }
}
