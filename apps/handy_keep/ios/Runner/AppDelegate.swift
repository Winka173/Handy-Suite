import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var labels: FlutterMethodChannel?
  private var labelsReady = false
  private var pendingLabel: String?

  func receiveLabel(_ url: URL) {
    guard url.scheme == "handy-keep", url.absoluteString.count <= 300 else { return }
    if labelsReady {
      labels?.invokeMethod("openLabel", arguments: url.absoluteString)
    } else {
      pendingLabel = url.absoluteString
    }
  }

  override func application(_ app: UIApplication, open url: URL,
      options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if url.scheme == "handy-keep" {
      receiveLabel(url)
      return true
    }
    return super.application(app, open: url, options: options)
  }
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL { receiveLabel(url) }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KeepLabels")!
    labelsReady = false
    labels = FlutterMethodChannel(name: "handy.keep/labels", binaryMessenger: registrar.messenger())
    labels?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "start" {
        self.labelsReady = true
        let initial = self.pendingLabel
        self.pendingLabel = nil
        result(initial)
      } else { result(FlutterMethodNotImplemented) }
    }
  }
}
