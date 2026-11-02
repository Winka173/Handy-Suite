package com.example.handysuite.handy_boards

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.appwidget.AppWidgetManager
import android.content.ComponentName

class MainActivity : FlutterActivity() {
    private val queue by lazy { ShareQueue(File(filesDir, "share_queue")) }
    private var channel: MethodChannel? = null
    private var homeChannel: MethodChannel? = null
    private var pendingLink: String? = null
    private val boardsFiles by lazy { BoardsFiles(this) }
    override fun onCreate(savedInstanceState: Bundle?) {
        // Recover the persisted delivery marker across Activity recreation.
        savedInstanceState?.getString("deliveryId")?.let { intent.putExtra("com.example.handysuite.handy_boards.DELIVERY_ID", it) }
        receive(intent)
        super.onCreate(savedInstanceState)
    }
    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString("deliveryId", intent.getStringExtra("com.example.handysuite.handy_boards.DELIVERY_ID"))
        super.onSaveInstanceState(outState)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
    }
    private fun receive(intent: Intent) {
        intent.data?.let { uri ->
            if (uri.scheme == "handy-boards" && uri.host in listOf("today", "capture", "task")) {
                pendingLink = uri.toString()
                homeChannel?.invokeMethod("open", pendingLink)
            }
        }
        try { if (queue.receive(intent)) channel?.invokeMethod("incoming", null) }
        catch (_: Exception) {
            Toast.makeText(this, if (resources.configuration.locales[0].language == "vi")
                "Không thể nhận liên kết. Hãy mở Handy Boards và thử dán liên kết (tối đa 262144 ký tự, 100 lượt chờ)."
                else "Unable to receive share. Open Handy Boards and paste the link (262144 characters, 100 pending shares maximum).", Toast.LENGTH_LONG).show()
            channel?.invokeMethod("shareError", "SHARE_QUEUE_ERROR")
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "handy.boards/files").setMethodCallHandler(boardsFiles::call)
        homeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "handy.boards/home").also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pending" -> { result.success(pendingLink); pendingLink = null }
                    "ack" -> { if (pendingLink == call.arguments) pendingLink = null; result.success(null) }
                    "publish" -> {
                        try {
                            // Atomically replace/clear the widget payload, including
                            // revocation, even when another native adapter failed.
                            val edit = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE).edit()
                            for (key in listOf("title", "value", "detail", "uri", "row0_text", "row0_uri", "row1_text", "row1_uri", "row2_text", "row2_uri")) {
                                val value = call.argument<String>(key)
                                if (value == null) edit.remove(key) else edit.putString(key, value)
                            }
                            check(edit.commit())
                            val component = ComponentName(this, HandyWidget::class.java)
                            val ids = AppWidgetManager.getInstance(this).getAppWidgetIds(component)
                            sendBroadcast(Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).setComponent(component)
                                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids))
                            if (Build.VERSION.SDK_INT >= 25) {
                                val vi = call.argument<Boolean>("vi") == true
                                getSystemService(ShortcutManager::class.java).dynamicShortcuts = listOf(
                                    "capture" to if (vi) "Thêm việc" else "Quick capture",
                                    "today" to if (vi) "Hôm nay" else "Today"
                                ).map { (key, label) -> ShortcutInfo.Builder(this, "boards-$key")
                                    .setShortLabel(label)
                                    .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
                                    .setIntent(Intent(Intent.ACTION_VIEW, Uri.parse("handy-boards://$key"), this, MainActivity::class.java))
                                    .build() }
                            }
                            result.success(null)
                        } catch (_: Exception) { result.error("HOME_UPDATE", "Unable to update launcher shortcuts", null) }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "handy.boards/share").also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "drain" -> result.success(queue.drain())
                        "ack" -> result.success(queue.ack(call.argument<String>("id") ?: ""))
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) { result.error("SHARE_QUEUE_ERROR", "Unable to access pending shares", null) }
            }
        }
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null); channel = null
        homeChannel?.setMethodCallHandler(null); homeChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!boardsFiles.activityResult(requestCode, resultCode, data)) super.onActivityResult(requestCode, resultCode, data)
    }
}
