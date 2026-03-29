# Spec: Message Encryptor

**Status:** Proposed
**Date:** 2026-03-29
**Depends on:** MessageSigning (complete), Base64URL (complete)

---

## 1. Goal

`MessageSigning` provides tamper-proof tokens (sign + verify), but the
payload is visible to anyone who base64-decodes the token. For session
data, auth tokens, and other sensitive payloads, we need encryption —
the payload must be both confidential and tamper-proof.

Elixir's `Plug.Crypto.MessageEncryptor` provides encrypt-then-sign
using AES-256-GCM. Nexus needs the same primitive to enable encrypted
cookie sessions and any feature where the payload itself must be secret.

---

## 2. Scope

### 2.1 The API

```swift
// Sources/Nexus/MessageEncryption.swift

/// AES-256-GCM encryption with HMAC-SHA256 signing.
///
/// Encrypts a payload so it is both confidential and tamper-proof.
/// This is the Nexus equivalent of Elixir's `Plug.Crypto.MessageEncryptor`.
///
/// ```swift
/// let secret = Data("32-byte-secret-key-for-aes256!!".utf8)
/// let token = try MessageEncryption.encrypt(payload: Data("secret".utf8), secret: secret)
/// let payload = try MessageEncryption.decrypt(token: token, secret: secret)
/// // payload == Data("secret".utf8)
/// ```
public enum MessageEncryption {

    /// Encrypts and signs a payload. Returns a base64url-encoded token.
    public static func encrypt(payload: Data, secret: Data) throws -> String

    /// Decrypts and verifies a token. Returns the original payload.
    /// Throws if the token is tampered with, corrupted, or the key is wrong.
    public static func decrypt(token: String, secret: Data) throws -> Data
}
```

### 2.2 Token Format

The token is three base64url-encoded segments joined by `.`:

```
<base64url(nonce)>.<base64url(ciphertext+tag)>.<base64url(hmac)>
```

1. Generate a random 12-byte nonce (AES-256-GCM standard).
2. Derive an encryption key and a signing key from `secret` (see §2.3).
3. Encrypt with AES-256-GCM using the encryption key and nonce.
4. HMAC-SHA256 sign `nonce + ciphertext` using the signing key.
5. Concatenate with `.` separators.

### 2.3 Key Derivation

Use `HKDF<SHA256>` (available in CryptoKit) to derive two 32-byte keys
from the caller's secret:

- Encryption key: `HKDF.deriveKey(inputKeyMaterial: secret, info: "encryption")`
- Signing key: `HKDF.deriveKey(inputKeyMaterial: secret, info: "signing")`

This ensures the same secret produces distinct keys for distinct purposes,
following cryptographic best practice.

### 2.4 Decryption Flow

1. Split token on `.` — must have exactly 3 segments.
2. Base64url-decode each segment → nonce, ciphertext+tag, hmac.
3. Verify HMAC first (fail fast on tampering before attempting decryption).
4. Decrypt with AES-256-GCM using the encryption key and nonce.
5. Return plaintext payload.

### 2.5 Error Handling

Throw a `NexusHTTPError` or a dedicated `MessageEncryptionError` for:
- Token format invalid (wrong number of segments)
- HMAC verification failed (tampering)
- Decryption failed (wrong key, corrupted data)

Error messages must NOT leak the secret or plaintext.

---

## 3. Acceptance Criteria

- [ ] `encrypt` → `decrypt` round-trips arbitrary `Data` payloads
- [ ] Empty payload encrypts and decrypts correctly
- [ ] Large payload (1 MB) encrypts and decrypts correctly
- [ ] Tampered ciphertext → `decrypt` throws
- [ ] Tampered HMAC → `decrypt` throws
- [ ] Tampered nonce → `decrypt` throws
- [ ] Wrong secret → `decrypt` throws
- [ ] Truncated token → `decrypt` throws
- [ ] Two encryptions of the same payload produce different tokens (random nonce)
- [ ] Uses CryptoKit on Apple platforms, swift-crypto on Linux
- [ ] Token format is `<nonce>.<ciphertext>.<hmac>` (three base64url segments)
- [ ] Key derivation uses HKDF with distinct info strings for encryption and signing
- [ ] `swift test` passes

---

## 4. Non-goals

- No key rotation / multi-key support (single secret per call).
- No token expiration (the caller can embed timestamps in the payload).
- No streaming encryption (payload must fit in memory).
- No integration with Session plug in this spec (that's a follow-up).
