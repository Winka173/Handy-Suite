package com.handysuite.handy_store

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Device-bound cache; Android backup cannot export its Keystore key. */
internal class VerifiedCache(private val context: Context) {
  private val alias = "handy-store-proof-v1"
  private val prefs get() = context.getSharedPreferences("handy-store-verified-v1", Context.MODE_PRIVATE)
  private fun key(create: Boolean): SecretKey? {
    val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    val existing = store.getKey(alias, null) as? SecretKey
    if (existing != null || !create) return existing
    return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
      init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
    }.generateKey()
  }
  fun read(product: String): String? = try {
    val text = prefs.getString("$product.encrypted", null)
    if (text == null || text.length > 200000) null else {
      val bytes = Base64.decode(text, Base64.DEFAULT)
      if (bytes.size < 29 || bytes.size > 150000) null else {
        val secret = key(false)
        if (secret == null) null else {
          val cipher = Cipher.getInstance("AES/GCM/NoPadding")
          cipher.init(Cipher.DECRYPT_MODE, secret, GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
          cipher.updateAAD(product.toByteArray(Charsets.UTF_8))
          String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8)
        }
      }
    }
  } catch (_: Exception) { null }
  fun write(product: String, proof: String): Boolean = try {
    if (proof.length > 110000) false else {
      val cipher = Cipher.getInstance("AES/GCM/NoPadding")
      cipher.init(Cipher.ENCRYPT_MODE, key(true))
      cipher.updateAAD(product.toByteArray(Charsets.UTF_8))
      val encrypted = cipher.iv + cipher.doFinal(proof.toByteArray(Charsets.UTF_8))
      prefs.edit().putString("$product.encrypted", Base64.encodeToString(encrypted, Base64.NO_WRAP)).remove("$product.json").remove("$product.signature").commit()
    }
  } catch (_: Exception) { false }
  fun clear(product: String) { prefs.edit().remove("$product.encrypted").remove("$product.json").remove("$product.signature").commit() }
}
