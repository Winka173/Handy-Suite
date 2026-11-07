package com.example.handysuite.save

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutManager
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.io.File

/**
 * Receives Share from other apps without opening Handy Bookmark: the share
 * is written to the app's private queue (durably, as before), then
 * [ShareSheetActivity] shows it and asks where it goes (shared through one
 * of the collections in the system share sheet's top row, that one is
 * already chosen). The person stays in the app they shared from. The small
 * card here is left for a share that could not be saved. The library takes the queued shares in the next
 * time the app opens. Invisible otherwise, and kept out of Recents.
 */
class ShareActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val vi = resources.configuration.locales[0].language == "vi"
        val (title, place, color) = try {
            val queue = ShareQueue(File(filesDir, "share_queue"))
            queue.receive(intent, contentResolver)
            // Saved; then the sheet to see it and choose where it goes (a
            // collection's own shortcut arrives with that one chosen).
            val id = ShareQueue.deliveryId(intent)
            if (id != null) {
                startActivity(
                    Intent(this, ShareSheetActivity::class.java)
                        .putExtra(ShareSheetActivity.EXTRA_ID, id)
                        .addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION),
                )
                finish()
                @Suppress("DEPRECATION")
                overridePendingTransition(0, 0)
                return
            }
            val target = collection(intent)
            Triple(
                if (vi) "Đã lưu" else "Saved",
                target?.first ?: if (vi) "Vào Chưa xếp" else "In Not sorted",
                target?.second,
            )
        } catch (_: Exception) {
            Triple(
                if (vi) "Chưa lưu được" else "Could not save it",
                if (vi) "Mở Handy Bookmark và dán link vào ô Lưu."
                else "Open Handy Bookmark and paste the link.",
                null,
            )
        }
        setContentView(card(title, place, color))
        handler.postDelayed({ close() }, 1600)
    }

    private fun close() {
        if (isFinishing) return
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, android.R.anim.fade_out)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun dp(v: Float) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics)

    /** The card at the foot of the screen; a tap anywhere closes it. */
    private fun card(title: String, place: String, color: Int?): View {
        val night = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val ground = if (night) Color.parseColor("#1F2A2D") else Color.WHITE
        val ink = if (night) Color.parseColor("#EEF2F3") else Color.parseColor("#141414")
        val muted = if (night) Color.parseColor("#AAB4B7") else Color.parseColor("#5B5E63")

        val icon = ImageView(this).apply {
            setImageDrawable(applicationInfo.loadIcon(packageManager))
            layoutParams = LinearLayout.LayoutParams(dp(40f).toInt(), dp(40f).toInt())
            contentDescription = "Handy Bookmark"
        }
        val heading = TextView(this).apply {
            text = title
            setTextColor(ink)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
        }
        val where = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            if (color != null) addView(
                View(context).apply {
                    background = GradientDrawable().apply {
                        shape = GradientDrawable.OVAL
                        setColor(color)
                    }
                    layoutParams = LinearLayout.LayoutParams(dp(10f).toInt(), dp(10f).toInt())
                        .apply { marginEnd = dp(6f).toInt() }
                },
            )
            addView(
                TextView(context).apply {
                    text = place
                    setTextColor(if (color != null) ink else muted)
                    textSize = 14f
                    if (color != null) typeface = Typeface.DEFAULT_BOLD
                    maxLines = 2
                },
            )
        }
        val words = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(heading)
            addView(where)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                .apply { marginStart = dp(12f).toInt() }
        }
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val pad = dp(14f).toInt()
            setPadding(pad, pad, dp(18f).toInt(), pad)
            background = GradientDrawable().apply {
                cornerRadius = dp(18f)
                setColor(ground)
            }
            elevation = dp(8f)
            addView(icon)
            addView(words)
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            contentDescription = "$title. $place"
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        return FrameLayout(this).apply {
            setOnClickListener { close() }
            addView(
                card,
                FrameLayout.LayoutParams(
                    minOf(dp(420f).toInt(), resources.displayMetrics.widthPixels - dp(32f).toInt()),
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
                ).apply { bottomMargin = dp(48f).toInt() },
            )
        }
    }

    /** The collection's name and colour when the share went through its shortcut. */
    private fun collection(intent: Intent): Pair<String, Int>? {
        if (ShareTargets.collection(intent) == null) return null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val id = intent.getStringExtra("android.intent.extra.shortcut.ID") ?: return null
        return try {
            val name = getSystemService(ShortcutManager::class.java)
                ?.dynamicShortcuts
                ?.firstOrNull { it.id == id }
                ?.shortLabel
                ?.toString() ?: return null
            val color = getSharedPreferences(ShareTargets.COLORS, Context.MODE_PRIVATE)
                .getInt(id, 0xFF0E7490.toInt())
            name to color
        } catch (_: Exception) {
            null
        }
    }
}
