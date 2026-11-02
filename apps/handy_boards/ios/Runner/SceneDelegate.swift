import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let item = connectionOptions.shortcutItem, let url = URL(string: "handy-boards://\(item.type)") {
      (UIApplication.shared.delegate as? AppDelegate)?.openHome(url)
    }
    for context in connectionOptions.urlContexts {
      (UIApplication.shared.delegate as? AppDelegate)?.openHome(context.url)
    }
  }
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts { (UIApplication.shared.delegate as? AppDelegate)?.openHome(context.url) }
  }
  override func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
    guard ["capture", "today"].contains(shortcutItem.type), let url = URL(string: "handy-boards://\(shortcutItem.type)") else { completionHandler(false); return }
    (UIApplication.shared.delegate as? AppDelegate)?.openHome(url)
    completionHandler(true)
  }
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    (UIApplication.shared.delegate as? AppDelegate)?.sharesMayBePending()
  }
}
