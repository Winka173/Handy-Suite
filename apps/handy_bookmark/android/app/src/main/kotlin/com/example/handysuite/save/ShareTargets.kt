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
                .setIcon(Icon.createWithAdaptiveBitmap(icon(name, color)))
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

    /** The collection's own colour with its initial, as an adaptive icon. */
    private fun icon(name: String, color: Int): Bitmap {
        val size = 216
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(color or 0xFF000000.toInt())
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = Color.WHITE
            textAlign = Paint.Align.CENTER
            textSize = size * .3f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val letter = String(Character.toChars(name.codePointAt(0))).uppercase()
        val baseline = size / 2f - (paint.descent() + paint.ascent()) / 2
        canvas.drawText(letter, size / 2f, baseline, paint)
        return bitmap
    }
}
