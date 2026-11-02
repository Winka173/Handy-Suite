package com.example.handysuite.save

import android.content.ClipData
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import android.content.Context
import org.junit.Assert.*
import org.junit.Before
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

/** Runs against Android's real Intent, AtomicFile and private filesystem. */
@RunWith(AndroidJUnit4::class)
class ShareQueueTest {
    private lateinit var directory: File
    @Before fun setUp() {
        directory = File(ApplicationProvider.getApplicationContext<Context>().cacheDir, "queue-test-${UUID.randomUUID()}")
    }
    @After fun tearDown() { directory.deleteRecursively() }
    private fun share(text: String) = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
    @Test fun testDrainPersistsUntilExactAcknowledgementAcrossInstances() {
        val queue = ShareQueue(directory)
        val intent = share("https://example.com/private?value=42")
        assertTrue(queue.receive(intent))
        val first = queue.drain().single()
        assertEquals(first, ShareQueue(directory).drain().single())
        assertFalse(queue.receive(intent))
        assertFalse(queue.ack(UUID.randomUUID().toString()))
        assertEquals(1, queue.drain().size)
        assertTrue(queue.ack(first["id"] as String))
        assertEquals(0, ShareQueue(directory).drain().size)
    }
    @Test fun testMultipleAndClipTextPreserveAllDistinctInput() {
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).setType("text/plain")
            .putCharSequenceArrayListExtra(Intent.EXTRA_TEXT, arrayListOf<CharSequence>("https://example.com/a", "surrounding https://example.com/b text"))
        intent.clipData = ClipData.newPlainText("link", "https://example.com/a")
        val queue = ShareQueue(directory)
        queue.receive(intent)
        assertEquals("https://example.com/a\nsurrounding https://example.com/b text", queue.drain().single()["text"])
    }
    @Test fun testOversizedAndEmptyDeliveryAreRejectedWithoutPartialCommit() {
        val queue = ShareQueue(directory)
        for (text in listOf("", "x".repeat(ShareQueue.MAX_CHARS + 1))) {
            try { queue.receive(share(text)); fail("Should reject delivery") } catch (_: IllegalStateException) { }
        }
        assertEquals(0, queue.drain().size)
    }
    @Test fun testQueueBoundRetainsAllExistingDeliveries() {
        val queue = ShareQueue(directory)
        repeat(ShareQueue.MAX_PENDING) { queue.receive(share("https://example.com/$it")) }
        try { queue.receive(share("https://example.com/overflow")); fail("Should reject overflow") } catch (_: IllegalStateException) { }
        assertEquals(ShareQueue.MAX_PENDING, ShareQueue(directory).drain().size)
    }
    @Test fun testAckRejectsTraversalAndDoesNotDeleteUnownedFiles() {
        val queue = ShareQueue(directory)
        queue.receive(share("https://example.com"))
        val unrelated = File(directory, "unrelated.json").apply { writeText("keep") }
        try { queue.ack("../unrelated"); fail("Should reject invalid identifier") } catch (_: IllegalArgumentException) { }
        assertTrue(unrelated.exists())
        assertEquals(1, queue.drain().size)
    }
}
