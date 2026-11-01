package com.example.handysuite.keep

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var labels: MethodChannel? = null
    private var ready = false
    private var pending: String? = null

    private fun label(intent: Intent?): String? = intent?.takeIf {
        it.action == Intent.ACTION_VIEW && it.data?.scheme == "handy-keep"
    }?.dataString?.takeIf { it.length <= 300 }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = label(intent)
        ready = false
        labels = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "handy.keep/labels").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "start") {
                    ready = true
                    val initial = pending
                    pending = null
                    result.success(initial)
                } else result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val value = label(intent) ?: return
        if (ready) labels?.invokeMethod("openLabel", value) else pending = value
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ready = false
        labels?.setMethodCallHandler(null)
        labels = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
