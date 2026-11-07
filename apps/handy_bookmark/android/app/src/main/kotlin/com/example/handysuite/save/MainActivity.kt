package com.example.handysuite.save

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// A FragmentActivity: the app lock's biometric prompt needs one.
class MainActivity : FlutterFragmentActivity() {
    private val queue by lazy { ShareQueue(File(filesDir, "share_queue")) }
    private var channel: MethodChannel? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        // Recover the persisted delivery marker across Activity recreation.
        savedInstanceState?.getString("deliveryId")?.let { intent.putExtra("com.example.handysuite.save.DELIVERY_ID", it) }
        receive(intent)
        super.onCreate(savedInstanceState)
    }
    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString("deliveryId", intent.getStringExtra("com.example.handysuite.save.DELIVERY_ID"))
        super.onSaveInstanceState(outState)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
    }
    private fun receive(intent: Intent) {
        try { if (queue.receive(intent, contentResolver)) channel?.invokeMethod("incoming", null) }
        catch (_: Exception) {
            Toast.makeText(this, if (resources.configuration.locales[0].language == "vi")
                "Không thể nhận liên kết. Hãy mở Handy Save và thử dán liên kết (tối đa 262144 ký tự, 100 lượt chờ)."
                else "Unable to receive share. Open Handy Save and paste the link (262144 characters, 100 pending shares maximum).", Toast.LENGTH_LONG).show()
            channel?.invokeMethod("shareError", "SHARE_QUEUE_ERROR")
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "handy.save/share").also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "drain" -> result.success(queue.drain())
                        "ack" -> result.success(queue.ack(call.argument<String>("id") ?: ""))
                        "shareTargets" -> result.success(
                            ShareTargets.publish(this, call.argument<List<Map<*, *>>>("targets") ?: emptyList())
                        )
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) { result.error("SHARE_QUEUE_ERROR", "Unable to access pending shares", null) }
            }
        }
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null); channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
