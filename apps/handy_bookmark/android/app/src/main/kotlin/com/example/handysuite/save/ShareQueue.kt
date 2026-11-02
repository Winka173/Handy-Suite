package com.example.handysuite.save

import android.content.Intent
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.util.UUID

/** Private durable delivery inbox. Reading never consumes a delivery. */
class ShareQueue(private val directory: File) {
    companion object {
        const val MAX_CHARS = 262144
        const val MAX_PENDING = 100
        private const val ID_EXTRA = "com.example.handysuite.save.DELIVERY_ID"
        private val uuid = Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
    }
    private fun files(): List<File> {
        check(directory.exists() || directory.mkdirs()) { "Cannot access share queue" }
        return (directory.listFiles() ?: error("Cannot read share queue"))
            .filter { it.name.endsWith(".json") && uuid.matches(it.name.removeSuffix(".json")) }
            .sortedBy { it.name }
    }
    @Synchronized fun receive(intent: Intent): Boolean {
        if (intent.action != Intent.ACTION_SEND && intent.action != Intent.ACTION_SEND_MULTIPLE) return false
        val existing = intent.getStringExtra(ID_EXTRA)
        if (existing != null && uuid.matches(existing)) return false
        val chunks = mutableListOf<String>()
        var total = 0
        fun add(value: CharSequence?) {
            if (value.isNullOrBlank()) return
            check(value.length <= MAX_CHARS && total + value.length + chunks.size <= MAX_CHARS) { "Shared text is too large" }
            total += value.length
            chunks.add(value.toString())
        }
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            val values = intent.getCharSequenceArrayListExtra(Intent.EXTRA_TEXT)
            check((values?.size ?: 0) <= MAX_PENDING) { "Too many shared items" }
            values?.forEach { add(it) }
        } else add(intent.getCharSequenceExtra(Intent.EXTRA_TEXT))
        val clip = intent.clipData
        check((clip?.itemCount ?: 0) <= MAX_PENDING) { "Too many shared items" }
        if (clip != null) for (index in 0 until clip.itemCount) {
            val item = clip.getItemAt(index)
            // Never coerce file/content URIs, load attachments, or access the network.
            val text = item.text ?: item.uri?.takeIf { it.scheme == "http" || it.scheme == "https" }?.toString()
            if (text != null && !chunks.contains(text.toString())) add(text)
        }
        check(chunks.isNotEmpty()) { "No shared text or URL" }
        check(files().size < MAX_PENDING) { "Share queue is full" }
        val title = intent.getCharSequenceExtra(Intent.EXTRA_SUBJECT)?.toString()
        check((title?.length ?: 0) <= 4096) { "Shared title is too large" }
        val id = UUID.randomUUID().toString()
        val record = JSONObject().put("id", id).put("text", chunks.joinToString("\n"))
            .put("receivedAt", Instant.now().toString())
        if (!title.isNullOrBlank()) record.put("title", title)
        val atomic = AtomicFile(File(directory, "$id.json"))
        val stream = atomic.startWrite()
        try { stream.write(record.toString().toByteArray(Charsets.UTF_8)); atomic.finishWrite(stream) }
        catch (error: Exception) { atomic.failWrite(stream); throw error }
        intent.putExtra(ID_EXTRA, id)
        return true
    }
    @Synchronized fun drain(): List<Map<String, Any>> = files().map { file ->
        check(file.length() <= MAX_CHARS * 6L + 32768) { "Invalid queued share" }
        val json = JSONObject(AtomicFile(file).openRead().bufferedReader().use { it.readText() })
        check(json.getString("id") == file.name.removeSuffix(".json")) { "Invalid queued share" }
        val text = json.getString("text")
        check(text.length <= MAX_CHARS) { "Invalid queued share" }
        buildMap {
            put("id", json.getString("id")); put("text", text); put("receivedAt", json.getString("receivedAt"))
            if (json.has("title")) put("title", json.getString("title"))
        }
    }.sortedBy { it["receivedAt"].toString() }
    @Synchronized fun ack(id: String): Boolean {
        require(uuid.matches(id)) { "Invalid delivery identifier" }
        val file = File(directory, "$id.json")
        check(file.canonicalFile.parentFile == directory.canonicalFile) { "Invalid queue path" }
        if (!file.exists()) return false
        check(file.delete()) { "Cannot acknowledge share" }
        return true
    }
}
