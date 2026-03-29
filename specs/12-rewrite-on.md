# Spec: RewriteOn Plug

**Status:** Proposed
**Date:** 2026-03-29
**Depends on:** Nexus core (complete), Connection+RemoteIP (complete)

---

## 1. Goal

Applications behind reverse proxies (nginx, AWS ALB, Cloudflare) receive
requests where the scheme is `http` (proxy → app), the host is the internal
hostname, and the remote IP is the proxy's IP — not the client's.

The real values are forwarded in standard headers:
- `X-Forwarded-For` → client IP
- `X-Forwarded-Proto` → original scheme (https)
- `X-Forwarded-Host` → original host

Elixir's `Plug.RewriteOn` reads these headers and rewrites the connection
fields so downstream plugs see the real client values. Without this,
`SSLRedirect` sees `http` and loops, `remoteIP` returns the proxy's IP,
and URL generation uses the wrong host.

---

## 2. Scope

### 2.1 The Plug

```swift
// Sources/Nexus/Plugs/RewriteOn.swift

/// Rewrites connection fields from reverse proxy headers.
///
/// Place this as the **first** plug in the pipeline, before anything
/// that depends on scheme, host, or remote IP:
///
/// ```swift
/// let app = pipeline([
///     rewriteOn([.forwardedFor, .forwardedProto, .forwardedHost]),
///     sslRedirect(),
///     requestId(),
///     router,
/// ])
/// ```
public func rewriteOn(_ headers: Set<RewriteHeader>) -> Plug

/// The headers that `rewriteOn` can process.
public enum RewriteHeader: Sendable {
    case forwardedFor
    case forwardedProto
    case forwardedHost
}
```

### 2.2 Behavior

For each header in the set:

**`forwardedFor`:**
1. Read `X-Forwarded-For` header.
2. Take the first (leftmost) IP — this is the original client.
3. Store in `assigns` under the `remoteIPKey` (same key `Connection+RemoteIP` uses).

**`forwardedProto`:**
1. Read `X-Forwarded-Proto` header.
2. Rewrite `conn.request.scheme` to the value (`"https"` or `"http"`).

**`forwardedHost`:**
1. Read `X-Forwarded-Host` header.
2. Rewrite `conn.request.authority` to the value.

### 2.3 Security

- Only trust these headers if your app is actually behind a proxy.
  Using `rewriteOn` without a proxy lets clients spoof their IP/scheme/host.
- The plug does NOT validate that the values are well-formed IPs or
  hostnames — it passes them through as-is (same as Elixir's Plug.RewriteOn).

---

## 3. Acceptance Criteria

- [ ] `X-Forwarded-Proto: https` → `conn.request.scheme` becomes `"https"`
- [ ] `X-Forwarded-Host: example.com` → `conn.request.authority` becomes `"example.com"`
- [ ] `X-Forwarded-For: 1.2.3.4, 10.0.0.1` → remote IP becomes `"1.2.3.4"` (first IP)
- [ ] `X-Forwarded-For: 1.2.3.4` (single IP) → remote IP becomes `"1.2.3.4"`
- [ ] Missing header → corresponding field is not rewritten
- [ ] Selective opt-in: `rewriteOn([.forwardedProto])` only rewrites scheme, ignores others
- [ ] All three headers together → all three fields rewritten
- [ ] Empty header value → field is not rewritten
- [ ] Remote IP uses the same assign key as `Connection+RemoteIP`
- [ ] Composable with `sslRedirect` (scheme rewrite prevents redirect loop)
- [ ] `swift test` passes

---

## 4. Non-goals

- No `Forwarded` header (RFC 7239) parsing — only the `X-Forwarded-*` de facto standard.
- No IP validation or allowlisting of trusted proxy IPs.
- No multi-hop IP chain handling beyond taking the first entry.
