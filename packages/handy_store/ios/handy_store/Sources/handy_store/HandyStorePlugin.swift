import Flutter
import UIKit
import StoreKit

public class HandyStorePlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel?
  private var productID = ""
  private var observer: Task<Void, Never>?
  private var busy = false
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "handy_store", binaryMessenger: registrar.messenger())
    let instance = HandyStorePlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  private func state(_ status: String, _ reason: String = "", owned: Bool = false, price: String? = nil) -> [String: Any] {
    var value: [String: Any] = ["status": status, "reason": reason, "owned": owned, "verified": owned, "productId": productID]
    if let price = price { value["price"] = price }
    return value
  }
  @available(iOS 15.0, *)
  private func ownership() async -> Bool {
    for await verification in Transaction.currentEntitlements {
      guard case .verified(let transaction) = verification else { continue }
      if transaction.productID == productID && transaction.productType == .nonConsumable && transaction.revocationDate == nil && transaction.expirationDate == nil { return true }
    }
    return false
  }
  @available(iOS 15.0, *)
  private func observe() {
    if observer != nil { return }
    observer = Task { [weak self] in
      for await update in Transaction.updates {
        guard let self = self else { return }
        guard case .verified(let transaction) = update, transaction.productID == self.productID else { continue }
        let owned = await self.ownership()
        await transaction.finish()
        await MainActor.run { self.channel?.invokeMethod("stateChanged", arguments: self.state(owned ? "owned" : "ready", owned: owned)) }
      }
    }
  }
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard ["read", "buy", "restore"].contains(call.method) else { result(FlutterMethodNotImplemented); return }
    let args = call.arguments as? [String: Any]
    productID = args?["productId"] as? String ?? ""
    guard !productID.isEmpty && productID.count <= 200 else { result(state("unavailable", "configuration_required")); return }
    guard #available(iOS 15.0, *) else { result(state("unavailable", "ios15_required")); return }
    guard !busy else { result(state("pending", "operation_in_progress")); return }
    busy = true
    observe()
    Task { [weak self] in
      guard let self = self else { return }
      var output: [String: Any]
      do {
        if call.method == "restore" { try await AppStore.sync() }
        if call.method == "buy" {
          let products = try await Product.products(for: [self.productID])
          guard let product = products.first, product.id == self.productID, product.type == .nonConsumable else {
            await MainActor.run { self.busy = false; result(self.state("unavailable", "product_unavailable")) }; return
          }
          switch try await product.purchase() {
          case .success(let verification):
            if case .verified(let transaction) = verification, transaction.productID == self.productID, transaction.productType == .nonConsumable, transaction.revocationDate == nil, transaction.expirationDate == nil {
              await transaction.finish()
              output = self.state("owned", owned: true, price: product.displayPrice)
            } else { output = self.state("error", "verification_failed") }
          case .pending: output = self.state("pending")
          case .userCancelled: output = self.state("canceled", owned: await self.ownership())
          @unknown default: output = self.state("error", "unknown_purchase_status")
          }
        } else {
          let owned = await self.ownership()
          output = self.state(owned ? "owned" : "ready", owned: owned)
        }
      } catch { output = self.state("unavailable", "store_unavailable", owned: await self.ownership()) }
      await MainActor.run { self.busy = false; result(output) }
    }
  }
  deinit { observer?.cancel() }
}
