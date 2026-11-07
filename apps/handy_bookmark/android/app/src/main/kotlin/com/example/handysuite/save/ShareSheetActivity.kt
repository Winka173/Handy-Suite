package com.example.handysuite.save

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The sheet over the app someone shares from: what is being saved (its
 * picture and title, read by the app's own page reader) and where it goes.
 * The share is already in the private queue when this opens; the sheet
 * only adds the person's choice to it. Drawn by Flutter (`shareSheet` in
 * main.dart) on a transparent window, kept out of Recents.
 */
class ShareSheetActivity : FlutterFragmentActivity() {
    companion object {
        const val EXTRA_ID = "com.example.handysuite.save.SHEET_ID"
        const val SNAPSHOT = "share_sheet"
    }

    private val queue by lazy { ShareQueue(File(filesDir, "share_queue")) }
    private var channel: MethodChannel? = null
    private var share: Map<String, Any>? = null

    override fun getDartEntrypointFunctionName() = "shareSheet"
    override fun getBackgroundMode() = BackgroundMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        share = try {
            intent.getStringExtra(EXTRA_ID)?.let { queue.peek(it) }
        } catch (_: Exception) {
            null
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "handy.save/sheet").also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> {
                            val s = share
                            if (s == null) {
                                result.error("SHARE_GONE", "The share is no longer queued", null)
                            } else {
                                @Suppress("UNCHECKED_CAST")
                                val images = (s["images"] as? List<Map<String, Any>>)
                                    ?.mapNotNull { it["path"] as? String } ?: emptyList()
                                result.success(
                                    mapOf(
                                        "id" to s["id"],
                                        "text" to s["text"],
                                        "title" to s["title"],
                                        "collection" to s["collection"],
                                        "images" to images,
                                        "snapshot" to getSharedPreferences(SNAPSHOT, Context.MODE_PRIVATE)
                                            .getString("snapshot", null),
                                    ),
                                )
                            }
                        }
                        "save" -> {
                            share?.let { s ->
                                queue.amend(
                                    id = s["id"] as String,
                                    text = s["text"] as? String ?: "",
                                    title = s["title"] as? String,
                                    collection = call.argument<String>("collection"),
                                    newCollection = call.argument<String>("newCollection"),
                                    metadata = call.argument<Map<*, *>>("metadata"),
                                    thumbnail = call.argument<ByteArray>("thumbnail"),
                                )
                            }
                            result.success(null)
                            close()
                        }
                        "discard" -> {
                            (share?.get("id") as? String)?.let { queue.ack(it) }
                            result.success(null)
                            close()
                        }
                        "close" -> {
                            result.success(null)
                            close()
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    // Whatever went wrong, the share stays saved in Not sorted.
                    result.error("SHARE_SHEET_ERROR", "Unable to update the share", null)
                    close()
                }
            }
        }
    }

    private fun close() {
        if (isFinishing) return
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, android.R.anim.fade_out)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
