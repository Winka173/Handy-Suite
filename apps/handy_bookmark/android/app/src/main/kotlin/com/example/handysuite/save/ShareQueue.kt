package com.example.handysuite.save

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.util.UUID

/** Private durable delivery inbox. Reading never consumes a delivery. */
class ShareQueue(private val directory: File) {
    companion object {
        const val MAX_CHARS = 262144
        const val MAX_PENDING = 100
        /** Pictures per share, and bytes per picture (the app's own limit). */
        const val MAX_IMAGES = 20
        const val MAX_IMAGE_BYTES = 25L * 1024 * 1024
        private const val ID_EXTRA = "com.example.handysuite.save.DELIVERY_ID"
        private val uuid = Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
        private val imageTypes = setOf("image/jpeg", "image/png", "image/webp")
    }
    private fun files(): List<File> {
        check(directory.exists() || directory.mkdirs()) { "Cannot access share queue" }
        return (directory.listFiles() ?: error("Cannot read share queue"))
            .filter { it.name.endsWith(".json") && uuid.matches(it.name.removeSuffix(".json")) }
            .sortedBy { it.name }
    }

    /** The picture URIs a share carries: the stream extra(s) and the clip. */
    @Suppress("DEPRECATION")
    private fun imageUris(intent: Intent): List<Uri> {
        val out = linkedSetOf<Uri>()
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            val list = if (Build.VERSION.SDK_INT >= 33)
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            list?.let { out.addAll(it) }
        } else {
            val one = if (Build.VERSION.SDK_INT >= 33)
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            one?.let { out.add(it) }
        }
        intent.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) clip.getItemAt(index).uri?.let { out.add(it) }
        }
        // Only content the sending app granted us; never a file path, never the network.
        return out.filter { it.scheme == ContentResolver.SCHEME_CONTENT }
    }

    @Synchronized fun receive(intent: Intent, resolver: ContentResolver? = null): Boolean {
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
            // Never coerce file/content URIs into text or access the network.
            val text = item.text ?: item.uri?.takeIf { it.scheme == "http" || it.scheme == "https" }?.toString()
            if (text != null && !chunks.contains(text.toString())) add(text)
        }
        val pictures = if (resolver != null && intent.type?.startsWith("image/") == true) imageUris(intent) else emptyList()
        check(pictures.size <= MAX_IMAGES) { "Too many shared pictures" }
        check(chunks.isNotEmpty() || pictures.isNotEmpty()) { "No shared text, URL or picture" }
        check(files().size < MAX_PENDING) { "Share queue is full" }
        val title = intent.getCharSequenceExtra(Intent.EXTRA_SUBJECT)?.toString()
        check((title?.length ?: 0) <= 4096) { "Shared title is too large" }
        val id = UUID.randomUUID().toString()
        // Pictures are copied into the private queue before the delivery
        // record exists, so a record never points at a missing file.
        val images = JSONArray()
        if (pictures.isNotEmpty()) {
            val folder = File(directory, "$id.d")
            check(folder.mkdirs()) { "Cannot store shared pictures" }
            try {
                pictures.forEachIndexed { index, uri ->
                    val mime = resolver!!.getType(uri)
                    check(mime in imageTypes) { "Unsupported picture" }
                    val target = File(folder, "$index")
                    resolver.openInputStream(uri).use { input ->
                        checkNotNull(input) { "Picture unavailable" }
                        target.outputStream().use { output ->
                            val buffer = ByteArray(64 * 1024)
                            var copied = 0L
                            while (true) {
                                val read = input.read(buffer)
                                if (read < 0) break
                                copied += read
                                check(copied <= MAX_IMAGE_BYTES) { "Picture too large" }
                                output.write(buffer, 0, read)
                            }
                            output.fd.sync()
                        }
                    }
                    images.put(JSONObject().put("file", "$index").put("mime", mime).put("name", displayName(resolver, uri)))
                }
            } catch (error: Exception) {
                folder.deleteRecursively()
                throw error
            }
        }
        val record = JSONObject().put("id", id).put("text", chunks.joinToString("\n"))
            .put("receivedAt", Instant.now().toString())
        if (images.length() > 0) record.put("images", images)
        if (!title.isNullOrBlank()) record.put("title", title)
        // Shared through one of the person's collections in the share sheet.
        ShareTargets.collection(intent)?.let { record.put("collection", it) }
        val atomic = AtomicFile(File(directory, "$id.json"))
        val stream = atomic.startWrite()
        try { stream.write(record.toString().toByteArray(Charsets.UTF_8)); atomic.finishWrite(stream) }
        catch (error: Exception) { atomic.failWrite(stream); File(directory, "$id.d").deleteRecursively(); throw error }
        intent.putExtra(ID_EXTRA, id)
        return true
    }

    private fun displayName(resolver: ContentResolver, uri: Uri): String = try {
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0)?.take(255) ?: "" else ""
        } ?: ""
    } catch (_: Exception) { "" }

    @Synchronized fun drain(): List<Map<String, Any>> = files().map { file ->
        check(file.length() <= MAX_CHARS * 6L + 32768) { "Invalid queued share" }
        val json = JSONObject(AtomicFile(file).openRead().bufferedReader().use { it.readText() })
        check(json.getString("id") == file.name.removeSuffix(".json")) { "Invalid queued share" }
        val text = json.getString("text")
        check(text.length <= MAX_CHARS) { "Invalid queued share" }
        buildMap {
            put("id", json.getString("id")); put("text", text); put("receivedAt", json.getString("receivedAt"))
            if (json.has("title")) put("title", json.getString("title"))
            json.optString("collection").takeIf { it.isNotEmpty() && it.length <= 512 }?.let { put("collection", it) }
            json.optJSONArray("images")?.let { list ->
                val folder = File(directory, "${json.getString("id")}.d")
                put("images", (0 until list.length()).map { i ->
                    val item = list.getJSONObject(i)
                    val target = File(folder, item.getString("file"))
                    check(target.canonicalFile.parentFile == folder.canonicalFile) { "Invalid queue path" }
                    mapOf("path" to target.absolutePath, "mime" to item.getString("mime"), "name" to item.optString("name"))
                })
            }
        }
    }.sortedBy { it["receivedAt"].toString() }
    @Synchronized fun ack(id: String): Boolean {
        require(uuid.matches(id)) { "Invalid delivery identifier" }
        val file = File(directory, "$id.json")
        check(file.canonicalFile.parentFile == directory.canonicalFile) { "Invalid queue path" }
        if (!file.exists()) return false
        check(file.delete()) { "Cannot acknowledge share" }
        // The record went first; its pictures follow (a leftover folder is
        // never read again and holds no record).
        File(directory, "$id.d").deleteRecursively()
        return true
    }
}
