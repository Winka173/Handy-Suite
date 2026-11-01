import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
      options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for context in connectionOptions.urlContexts {
      (UIApplication.shared.delegate as? AppDelegate)?.receiveLabel(context.url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts where context.url.scheme == "handy-keep" {
      (UIApplication.shared.delegate as? AppDelegate)?.receiveLabel(context.url)
    }
    let other = Set(URLContexts.filter { $0.url.scheme != "handy-keep" })
    if !other.isEmpty { super.scene(scene, openURLContexts: other) }
  }
}
