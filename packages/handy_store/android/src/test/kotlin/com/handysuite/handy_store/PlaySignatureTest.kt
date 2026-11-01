package com.handysuite.handy_store

import java.security.KeyPairGenerator
import java.security.Signature
import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertFalse

class PlaySignatureTest {
  @Test fun verifiesRealRsaAndRejectsTamperingAndWrongKeys() {
    val generator = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }
    val pair = generator.generateKeyPair()
    val data = "{\"packageName\":\"com.example.handysuite.tools\",\"productId\":\"tools.pro\",\"purchaseState\":0}".toByteArray()
    val signer = Signature.getInstance("SHA1withRSA").apply { initSign(pair.private); update(data) }
    val signature = signer.sign()
    assertTrue(PlaySignature.verify(pair.public.encoded, data, signature))
    assertFalse(PlaySignature.verify(pair.public.encoded, "$data changed".toByteArray(), signature))
    assertFalse(PlaySignature.verify(generator.generateKeyPair().public.encoded, data, signature))
    signature[0] = (signature[0].toInt() xor 1).toByte()
    assertFalse(PlaySignature.verify(pair.public.encoded, data, signature))
  }
  @Test fun rejectsInvalidOrOversizedProofs() {
    assertFalse(PlaySignature.verify(byteArrayOf(1,2), byteArrayOf(3), byteArrayOf(4)))
    assertFalse(PlaySignature.verify(ByteArray(2000), ByteArray(100001), ByteArray(2000)))
  }
}
