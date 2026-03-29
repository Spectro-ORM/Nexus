# Spec: Key Generator (PBKDF2)

**Status:** Proposed
**Date:** 2026-03-29
**Depends on:** Nexus core (complete)

---

## 1. Goal

Elixir's `Plug.Crypto.KeyGenerator` provides PBKDF2-HMAC-SHA256 key
derivation for turning human-readable secrets into cryptographic keys.
This is used internally by Plug for session encryption key derivation
and is exposed for user-land code that needs the same.

CryptoKit does not ship a built-in PBKDF2 function on all platforms.
On Apple platforms `SecKeyDeriveFromPassword` / `CC_PBKDF2` exists but
differs from Linux. A cross-platform Nexus wrapper ensures consistent
behavior.

**Note:** If `HKDF` (spec 11 — MessageEncryptor) is sufficient for all
internal key derivation needs, this spec's priority drops. PBKDF2 is
primarily needed when deriving keys from low-entropy human passwords
rather than from high-entropy secrets.

---

## 2. Scope

### 2.1 The API

```swift
// Sources/Nexus/KeyGenerator.swift

/// PBKDF2-HMAC-SHA256 key derivation.
///
/// Derives a fixed-length cryptographic key from a password and salt.
/// This is the Nexus equivalent of Elixir's `Plug.Crypto.KeyGenerator`.
///
/// ```swift
/// let key = KeyGenerator.derive(
///     password: "user-secret",
///     salt: Data("my-app-salt".utf8),
///     iterations: 100_000,
///     keyLength: 32
/// )
/// ```
public enum KeyGenerator {

    /// Derives a key using PBKDF2-HMAC-SHA256.
    ///
    /// - Parameters:
    ///   - password: The input password string.
    ///   - salt: Random salt bytes. Should be at least 16 bytes.
    ///   - iterations: Number of PBKDF2 iterations. Minimum 1000,
    ///     recommended 100_000+ for password-derived keys.
    ///   - keyLength: Desired output key length in bytes. Defaults to 32.
    /// - Returns: The derived key as `Data`.
    public static func derive(
        password: String,
        salt: Data,
        iterations: Int = 100_000,
        keyLength: Int = 32
    ) -> Data
}
```

### 2.2 Implementation

- On Apple platforms: use `CryptoKit` or CommonCrypto (`CCKeyDerivationPBKDF`).
- On Linux: use `swift-crypto` which provides HMAC, then implement PBKDF2
  manually using `HMAC<SHA256>` per RFC 2898 §5.2.
- Alternatively, if `swift-crypto` exposes PBKDF2 by the time this is
  implemented, use it directly.

### 2.3 Validation

- `iterations` must be ≥ 1. Values below 1000 emit a debug warning.
- `keyLength` must be > 0 and ≤ `Int(UInt32.max) * 32` (PBKDF2 limit).
- `salt` should be non-empty. Empty salt works but emits a debug warning.

---

## 3. Acceptance Criteria

- [ ] `derive` produces a key of the requested `keyLength`
- [ ] Same inputs → same output (deterministic)
- [ ] Different salt → different output
- [ ] Different password → different output
- [ ] Different iterations → different output
- [ ] Output matches known PBKDF2-HMAC-SHA256 test vectors (RFC 6070)
- [ ] Works on macOS (CryptoKit / CommonCrypto)
- [ ] Works on Linux (swift-crypto)
- [ ] `iterations < 1000` logs a debug warning
- [ ] `keyLength` of 16, 32, and 64 bytes all work
- [ ] `swift test` passes

---

## 4. Non-goals

- No Argon2 or scrypt support (PBKDF2 only, matching Plug).
- No automatic salt generation (caller provides salt).
- No password hashing for user auth (this is key derivation, not bcrypt).
- Not a replacement for HKDF — use HKDF for high-entropy secret expansion,
  PBKDF2 for low-entropy password derivation.
