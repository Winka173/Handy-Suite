package com.handysuite.handy_store

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Base64
import com.android.billingclient.api.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec

class HandyStorePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var activity: Activity? = null
  private var client: BillingClient? = null
  private var product = ""
  private var publicKey = ""
  private var busy = false
  private val main = Handler(Looper.getMainLooper())
  private val cache get() = VerifiedCache(context)
  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "handy_store")
    channel.setMethodCallHandler(this)
  }
  /**
   * Whether a purchase Google Play reported is this app's product, bought.
   * Without a public key (the default) Play's word is taken, as most apps
   * do; with the app's licence key the purchase's signature is checked too,
   * which stops faked answers on a tampered device.
   */
  private fun proof(json: String, signature: String): Boolean {
    if (json.length > 100000 || signature.length > 2048) return false
    if (publicKey.isNotEmpty() && publicKey.length !in 64..2048) return false
    return try {
      val body = JSONObject(json)
      val ids = body.optJSONArray("productIds")
      val matches = body.optString("productId") == product || ids != null && (0 until ids.length()).any { ids.optString(it) == product }
      if (!matches || body.optString("packageName") != context.packageName || body.optInt("purchaseState", -1) != 0 || body.optString("purchaseToken").isEmpty()) return false
      publicKey.isEmpty() || PlaySignature.verify(Base64.decode(publicKey, Base64.DEFAULT), json.toByteArray(Charsets.UTF_8), Base64.decode(signature, Base64.DEFAULT))
    } catch (_: Exception) { false }
  }
  private fun cached(): Boolean = try {
    val data = cache.read(product)
    if (data == null) false else {
      val saved = JSONObject(data)
      proof(saved.optString("json"), saved.optString("signature"))
    }
  } catch (_: Exception) { false }
  private fun state(status: String, reason: String = "", owned: Boolean = cached(), price: String? = null): Map<String, Any?> = mapOf("status" to status, "reason" to reason, "owned" to owned, "verified" to owned, "productId" to product, "price" to price)
  private fun emit(value: Map<String, Any?>) { main.post { channel.invokeMethod("stateChanged", value) } }
  private fun clearProof() { cache.clear(product) }
  private fun verifyPurchase(purchase: Purchase, done: (Map<String, Any?>) -> Unit) {
    if (!purchase.products.contains(product)) { done(state("error", "foreign_product", false)); return }
    if (purchase.purchaseState == Purchase.PurchaseState.PENDING) { clearProof(); done(state("pending", owned = false)); return }
    if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED || !proof(purchase.originalJson, purchase.signature)) { clearProof(); done(state("error", "verification_failed", false)); return }
    fun grant() {
      val persisted = cache.write(product, JSONObject().put("json", purchase.originalJson).put("signature", purchase.signature).toString())
      done(state("owned", if (persisted) "" else "cache_write_failed", true))
    }
    if (purchase.isAcknowledged) { grant(); return }
    client!!.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()) { result ->
      if (result.responseCode == BillingClient.BillingResponseCode.OK) grant() else done(state("error", "acknowledgement_failed", false))
    }
  }
  private fun connect(done: (Boolean) -> Unit) {
    if (client?.isReady == true) { done(true); return }
    if (client == null) client = BillingClient.newBuilder(context)
      .setListener { result, purchases ->
        when (result.responseCode) {
          BillingClient.BillingResponseCode.OK -> purchases?.filter { it.products.contains(product) }?.forEach { purchase -> verifyPurchase(purchase) { emit(it) } }
          BillingClient.BillingResponseCode.USER_CANCELED -> emit(state("canceled"))
          else -> emit(state("error", "purchase_failed"))
        }
      }.enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
      .enableAutoServiceReconnection().build()
    client!!.startConnection(object : BillingClientStateListener {
      override fun onBillingSetupFinished(result: BillingResult) { done(result.responseCode == BillingClient.BillingResponseCode.OK) }
      override fun onBillingServiceDisconnected() { emit(state("unavailable", "store_disconnected")) }
    })
  }
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method !in listOf("read", "buy", "restore")) { result.notImplemented(); return }
    if (busy) { result.success(state("pending", "operation_in_progress")); return }
    product = call.argument<String>("productId") ?: ""
    publicKey = call.argument<String>("publicKey") ?: ""
    if (!Regex("^[a-zA-Z0-9_.-]{1,200}$").matches(product)) { result.success(state("unavailable", "configuration_required", false)); return }
    // The key is optional; one that is given must be a real RSA public key.
    val validKey = publicKey.isEmpty() || try { KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(Base64.decode(publicKey, Base64.DEFAULT))); true } catch (_: Exception) { false }
    if (!validKey) { result.success(state("unavailable", "configuration_required", false)); return }
    busy = true
    var finished = false
    fun finish(value: Map<String, Any?>) { main.post { if (!finished) { finished = true; busy = false; result.success(value) } } }
    main.postDelayed({ finish(state("unavailable", "store_timeout")) }, 35000)
    connect { connected ->
      if (!connected) { finish(state("unavailable", "store_unavailable")); return@connect }
      if (call.method != "buy") {
        client!!.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()) { response, purchases ->
          if (response.responseCode != BillingClient.BillingResponseCode.OK) finish(state("unavailable", "ownership_query_failed"))
          else {
            val owned = purchases.firstOrNull { it.products.contains(product) }
            if (owned == null) { clearProof(); finish(state("ready", owned = false)) } else verifyPurchase(owned) { finish(it) }
          }
        }
      } else {
        val params = QueryProductDetailsParams.newBuilder().setProductList(listOf(QueryProductDetailsParams.Product.newBuilder().setProductId(product).setProductType(BillingClient.ProductType.INAPP).build())).build()
        client!!.queryProductDetailsAsync(params) { response, detailsResult ->
          val details = detailsResult.productDetailsList.firstOrNull { it.productId == product }
          val offer = details?.oneTimePurchaseOfferDetailsList?.firstOrNull() ?: details?.oneTimePurchaseOfferDetails
          main.post {
            val owner = activity
            if (response.responseCode != BillingClient.BillingResponseCode.OK || details == null || offer == null || owner == null) finish(state("unavailable", "product_unavailable"))
            else {
              val itemBuilder = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(details)
              offer.offerToken?.let { itemBuilder.setOfferToken(it) }
              val item = itemBuilder.build()
              val launched = client!!.launchBillingFlow(owner, BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(item)).build())
              finish(state(if (launched.responseCode == BillingClient.BillingResponseCode.OK) "pending" else "error", if (launched.responseCode == BillingClient.BillingResponseCode.OK) "" else "purchase_not_started", price = offer.formattedPrice))
            }
          }
        }
      }
    }
  }
  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel.setMethodCallHandler(null); client?.endConnection(); client = null }
  override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
  override fun onDetachedFromActivityForConfigChanges() { activity = null }
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
  override fun onDetachedFromActivity() { activity = null }
}
