package com.handysuite.handy_store

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.security.KeyStore
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class VerifiedCacheDeviceTest {
  @Test fun encryptsWithNonExportableKeyAndRejectsTampering() {
    val context = InstrumentationRegistry.getInstrumentation().targetContext
    val cache = VerifiedCache(context)
    val product = "handy.test.encryption"
    cache.clear(product)
    try {
      assertTrue(cache.write(product, "private proof fixture"))
      assertEquals("private proof fixture", cache.read(product))
      val prefs = context.getSharedPreferences("handy-store-verified-v1", Context.MODE_PRIVATE)
      val first = prefs.getString("$product.encrypted", "")!!
      assertFalse(first.contains("private proof"))
      assertTrue(cache.write(product, "private proof fixture"))
      val second = prefs.getString("$product.encrypted", "")!!
      assertNotEquals(first, second)
      val keys = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
      assertNull(keys.getKey("handy-store-proof-v1", null).encoded)
      val changed = second.toCharArray(); changed[20] = if (changed[20] == 'A') 'B' else 'A'
      prefs.edit().putString("$product.encrypted", String(changed)).commit()
      assertNull(cache.read(product))
    } finally { cache.clear(product) }
    assertNull(cache.read(product))
  }
}
