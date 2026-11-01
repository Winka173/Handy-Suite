package com.handysuite.handy_store

import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec

internal object PlaySignature {
  fun verify(publicKey: ByteArray, data: ByteArray, signature: ByteArray): Boolean {
    if (publicKey.size > 1536 || data.size > 100000 || signature.size > 1024) return false
    return try {
      val key = KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(publicKey))
      val verifier = Signature.getInstance("SHA1withRSA")
      verifier.initVerify(key)
      verifier.update(data)
      verifier.verify(signature)
    } catch (_: Exception) { false }
  }
}
