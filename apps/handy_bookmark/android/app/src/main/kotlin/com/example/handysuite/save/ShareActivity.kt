package com.example.handysuite.save

import android.app.Activity
import android.content.Intent
import android.content.pm.ShortcutManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import java.io.File

/**
 * Receives Share from other apps without opening Handy Bookmark: the share
 * is written to the app's private queue (durably, as before), a short
 * "Saved" note shows, and the person stays in the app they shared from.
 * The library takes the queued shares in the next time the app opens.
 * Invisible and kept out of Recents.
 */
class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val vi = resources.configuration.locales[0].language == "vi"
        try {
            val queue = ShareQueue(File(filesDir, "share_queue"))
            if (queue.receive(intent, contentResolver)) {
                val into = collectionName(intent)
                val words = when {
                    into != null && vi -> "Đã lưu vào $into"
                    into != null -> "Saved to $into"
                    vi -> "Đã lưu vào Handy Bookmark"
                    else -> "Saved to Handy Bookmark"
                }
                Toast.makeText(applicationContext, words, Toast.LENGTH_SHORT).show()
            }
        } catch (_: Exception) {
            Toast.makeText(
                applicationContext,
                if (vi) "Chưa lưu được. Hãy mở Handy Bookmark và dán link vào ô Lưu."
                else "Could not save it. Open Handy Bookmark and paste the link.",
                Toast.LENGTH_LONG,
            ).show()
        }
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    /** The collection's name when the share went through its shortcut. */
    private fun collectionName(intent: Intent): String? {
        if (ShareTargets.collection(intent) == null) return null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val id = intent.getStringExtra("android.intent.extra.shortcut.ID") ?: return null
        return try {
            getSystemService(ShortcutManager::class.java)
                ?.dynamicShortcuts
                ?.firstOrNull { it.id == id }
                ?.shortLabel
                ?.toString()
        } catch (_: Exception) {
            null
        }
    }
}
