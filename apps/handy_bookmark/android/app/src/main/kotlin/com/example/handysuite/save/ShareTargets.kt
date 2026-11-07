package com.example.handysuite.save

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.os.Build

/**
 * The person's own collections, offered in the top row of Android's share
 * sheet (sharing shortcuts, Android 10+): one tap saves straight into that
 * collection, without looking for the app in the list. The app decides
 * which collections (the ones saved into most recently); this only draws
 * and publishes them. Nothing here reads or sends the shared content.
 */
object ShareTargets {
    /** Matches res/xml/shortcuts.xml. */
    const val CATEGORY = "com.example.handysuite.save.SHARE_TO_COLLECTION"
    private const val PREFIX = "col:"
    private const val SHORTCUT_ID = "android.intent.extra.shortcut.ID"
    private const val MAX = 4
    const val COLORS = "share_target_colors"

    fun publish(context: Context, targets: List<Map<*, *>>): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val manager = context.getSystemService(ShortcutManager::class.java) ?: return false
        val limit = minOf(MAX, manager.maxShortcutCountPerActivity)
        val shortcuts = targets.take(limit).mapIndexedNotNull { rank, t ->
            val id = (t["id"] as? String)?.takeIf { it.isNotBlank() && it.length <= 512 }
                ?: return@mapIndexedNotNull null
            val name = (t["name"] as? String)?.trim()?.take(64)?.ifBlank { null }
                ?: return@mapIndexedNotNull null
            val color = (t["color"] as? Number)?.toInt() ?: 0xFF0E7490.toInt()
            ShortcutInfo.Builder(context, PREFIX + id)
                .setShortLabel(name)
                .setLongLabel(name)
                .setIcon(Icon.createWithAdaptiveBitmap(icon(context, name, color)))
                // Opening the shortcut itself (where a launcher shows it)
                // just opens the app.
                .setIntent(Intent(Intent.ACTION_VIEW, null, context, MainActivity::class.java))
                .setCategories(setOf(CATEGORY))
                .setLongLived(true)
                .setRank(rank)
                .apply {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                        setExcludedFromSurfaces(ShortcutInfo.SURFACE_LAUNCHER)
                }
                .build()
        }
        // The colours, for the "Saved to …" card the share activity shows.
        context.getSharedPreferences(COLORS, Context.MODE_PRIVATE).edit().apply {
            clear()
            targets.take(limit).forEach { t ->
                val id = t["id"] as? String ?: return@forEach
                putInt(PREFIX + id, (t["color"] as? Number)?.toInt() ?: 0xFF0E7490.toInt())
            }
            apply()
        }
        val keep = shortcuts.map { it.id }.toSet()
        val stale = manager.dynamicShortcuts.map { it.id }
            .filter { it.startsWith(PREFIX) && it !in keep }
        if (stale.isNotEmpty()) {
            manager.removeDynamicShortcuts(stale)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) manager.removeLongLivedShortcuts(stale)
        }
        return manager.setDynamicShortcuts(shortcuts)
    }

    /** The collection a share was sent to through one of these, or null. */
    fun collection(intent: Intent): String? {
        val id = intent.getStringExtra(SHORTCUT_ID) ?: return null
        if (!id.startsWith(PREFIX)) return null
        return id.removePrefix(PREFIX).takeIf { it.isNotBlank() && it.length <= 512 }
    }

    /**
     * The collection's initial in its own colour on a pale tint of it, the
     * way the app shows a collection beside its name, as an adaptive icon
     * (the system crops the outer sixth and adds the app's badge).
     */
    private fun icon(context: Context, name: String, color: Int): Bitmap {
        val size = 216
        val hue = color or 0xFF000000.toInt()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(mix(hue, Color.WHITE, .84f))
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            // Dark enough to read on the tint, even for a light hue.
            this.color = mix(hue, Color.BLACK, .22f)
            textAlign = Paint.Align.CENTER
            textSize = size * .34f
            typeface = face(context)
        }
        val letter = String(Character.toChars(name.codePointAt(0))).uppercase()
        val baseline = size / 2f - (paint.descent() + paint.ascent()) / 2
        canvas.drawText(letter, size / 2f, baseline, paint)
        return bitmap
    }

    /** [a] moved [t] of the way towards [b]. */
    private fun mix(a: Int, b: Int, t: Float): Int {
        fun ch(shift: Int): Int {
            val x = (a shr shift) and 0xFF
            val y = (b shr shift) and 0xFF
            return (x + (y - x) * t).toInt().coerceIn(0, 255)
        }
        return Color.rgb(ch(16), ch(8), ch(0))
    }

    private var geist: Typeface? = null

    /** The app's own face (Geist, bundled with Flutter's assets). */
    private fun face(context: Context): Typeface =
        geist ?: try {
            Typeface.createFromAsset(
                context.assets,
                "flutter_assets/packages/handy_ui/fonts/Geist-Bold.ttf",
            ).also { geist = it }
        } catch (_: RuntimeException) {
            Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
}
