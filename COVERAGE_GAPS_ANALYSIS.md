# Specific Coverage Gaps - Action Items

## Overview

This document provides specific, actionable coverage gaps that need to be filled to reach 95% coverage. Each gap includes file location, specific missing tests, and implementation guidance.

## Critical Gaps (Blocking Coverage Measurement)

### 1. Vapor Adapter Compilation Error
**File**: `Sources/NexusVapor/WebSocketAdapter.swift:248`

**Issue**: `WebSocketErrorCode` type mismatch
```swift
// Current (broken):
await ws.close(code: code)  // code is UInt16

// Fixed version:
await ws.close(code: WebSocketErrorCode(codeNumber: Int(code)))
```

**Action**: Fix the type conversion
**Priority**: CRITICAL (blocks all coverage measurement)
**Effort**: 5 minutes

---

## High-Priority Gaps (5-8% coverage impact)

### 2. Telemetry Plug Coverage
**File**: `Sources/Nexus/Plugs/Telemetry.swift`
**Current Coverage**: ~60%
**Target**: 95%

**Missing Tests**:

1. **Metrics Collection Accuracy**
   ```swift
   @Test func telemetryMetricsCollection准确性() async throws
   ```
   - Verify request count increments
   - Verify error count increments
   - Verify response time recording
   - Test concurrent request tracking

2. **Concurrent Request Tracking**
   ```swift
   @Test func telemetry并发请求追踪() async throws
   ```
   - 100 simultaneous requests
   - Verify no race conditions
   - Verify accurate counts

3. **Performance Overhead**
   ```swift
   @Test func telemetry性能开销() async throws
   ```
   - Measure overhead percentage
   - Verify <5% overhead target
   - Test with varying request rates

**Action**: Create `Tests/NexusTests/TelemetryCoverageTests.swift`
**Effort**: 2-3 hours
**Impact**: +1.5% coverage

---

### 3. WebSocket Error Paths
**File**: `Sources/Nexus/WebSocket/WSConnection.swift`
**Current Coverage**: ~85%
**Target**: 95%

**Missing Tests**:

1. **Upgrade Error Handling**
   ```swift
   @Test func websocket升级错误处理() async throws
   ```
   - Invalid WebSocket upgrade request
   - Missing required headers
   - Connection failure during upgrade

2. **Large Message Fragmentation**
   ```swift
   @Test func websocket大消息分片() async throws
   ```
   - Send 10MB message
   - Verify fragmentation
   - Verify reassembly

3. **Ping/Pong Timeout**
   ```swift
   @Test func websocket Ping超时() async throws
   ```
   - No response to ping
   - Verify connection closes
   - Verify timeout detection

**Action**: Extend `Tests/NexusTests/WebSocketTests.swift`
**Effort**: 2-3 hours
**Impact**: +1% coverage

---

### 4. Security Edge Cases
**Files**: Multiple plug files
**Current Coverage**: Varies (70-85%)
**Target**: 95%

**Missing Tests**:

1. **HTTP Header Injection** (Plugs/CORS.swift)
   ```swift
   @Test func cors防止头注入() async throws
   ```
   - Malformed Origin headers
   - Header value injection attempts
   - Regex denial of service

2. **Request Smuggling** (Connection+Request.swift)
   ```swift
   @Test func request防止走私攻击() async throws
   ```
   - Chunked encoding edge cases
   - Content-Length conflicts
   - Transfer-Encoding manipulation

3. **Compression Bomb** (Plugs/Compression.swift)
   ```swift
   @Test func compression炸弹防护() async throws
   ```
   - 1MB → 1GB decompression
   - Verify size limits
   - Verify decompression ratio limits

**Action**: Create `Tests/NexusTests/SecurityEdgeCasesTests.swift`
**Effort**: 3-4 hours
**Impact**: +1.5% coverage

---

### 5. Adapter Integration Tests
**Files**: `Sources/NexusVapor/`, `Sources/NexusHummingbird/`
**Current Coverage**: 60-75%
**Target**: 90%

**Missing Tests**:

1. **Vapor Integration**
   ```swift
   @Test func vapor完整请求生命周期() async throws
   ```
   - Full request → response cycle
   - Middleware chain execution
   - Error propagation

2. **Hummingbird Integration**
   ```swift
   @Test func hummingbird完整请求生命周期() async throws
   ```
   - Full request → response cycle
   - Adapter-specific features
   - Error handling

3. **Adapter Error Recovery**
   ```swift
   @Test func adapter错误恢复() async throws
   ```
   - Partial response failures
   - Connection errors
   - Timeout handling

**Action**: Extend `Tests/NexusVaporTests/IntegrationTests.swift`
**Effort**: 4-5 hours
**Impact**: +2-3% coverage

---

## Medium-Priority Gaps (3-5% coverage impact)

### 6. Compression Plug Edge Cases
**File**: `Sources/Nexus/Plugs/Compression.swift`
**Current Coverage**: ~70%
**Target**: 95%

**Missing Tests**:

1. **Compression Error Handling**
   ```swift
   @Test func compression错误处理() async throws
   ```
   - Corrupted compressed data
   - Unsupported compression format
   - Memory limit exceeded

2. **Already-Compressed Detection**
   ```swift
   @Test func compression已压缩检测() async throws
   ```
   - Detect pre-compressed content
   - Skip compression for images
   - Verify Content-Encoding header

3. **Memory Efficiency**
   ```swift
   @Test func compression内存效率() async throws
   ```
   - Streaming compression
   - Constant memory verification
   - Large file compression

**Action**: Add to `Tests/NexusTests/AdditionalPlugsTests.swift`
**Effort**: 2 hours
**Impact**: +0.5% coverage

---

### 7. Timeout Plug Error Paths
**File**: `Sources/Nexus/Plugs/Timeout.swift`
**Current Coverage**: ~70%
**Target**: 95%

**Missing Tests**:

1. **Timeout Cancellation Propagation**
   ```swift
   @Test func timeout取消传播() async throws
   ```
   - Verify Task.cancel() propagation
   - Verify cleanup execution
   - Verify resource release

2. **Task Cancellation Handling**
   ```swift
   @Test func timeout任务取消() async throws
   ```
   - Cancel before timeout
   - Cancel during execution
   - Verify no partial state

3. **Resource Cleanup Verification**
   ```swift
   @Test func timeout资源清理() async throws
   ```
   - File handles closed
   - Network connections closed
   - Memory released

**Action**: Add to `Tests/NexusTests/AdditionalPlugsTests.swift`
**Effort**: 2 hours
**Impact**: +0.5% coverage

---

### 8. Async Error Propagation
**Files**: Multiple files with async operations
**Current Coverage**: ~80% for async paths
**Target**: 95%

**Missing Tests**:

1. **Stream Cancellation Propagation**
   ```swift
   @Test func asyncStream取消传播() async throws
   ```
   - Cancel RequestBody stream
   - Cancel ResponseBody stream
   - Verify upstream cancellation

2. **Network Timeout Cascading**
   ```swift
   @Test func network超时级联() async throws
   ```
   - Timeout in middleware
   - Timeout in plug
   - Verify error propagation

3. **Concurrent Access Race Conditions**
   ```swift
   @Test func并发访问竞态() async throws
   ```
   - Simultaneous Connection mutations
   - Verify actor isolation
   - Verify data race freedom

**Action**: Create `Tests/NexusTests/AsyncErrorPathTests.swift`
**Effort**: 3 hours
**Impact**: +1% coverage

---

## Low-Priority Gaps (2-3% coverage impact)

### 9. SSE Streaming Edge Cases
**File**: `Sources/Nexus/SSE.swift`
**Current Coverage**: ~70%
**Target**: 90%

**Missing Tests**:

1. **Client Disconnect Scenarios**
   ```swift
   @Test func sse客户端断开() async throws
   ```
   - Disconnect during event send
   - Verify error handling
   - Verify resource cleanup

2. **Event Serialization Edge Cases**
   ```swift
   @Test func sse事件序列化边界() async throws
   ```
   - Unicode in event data
   - Newlines in event data
   - Very long event data

**Action**: Extend `Tests/NexusTests/SSETests.swift`
**Effort**: 1-2 hours
**Impact**: +0.3% coverage

---

### 10. Content Negotiation Edge Cases
**File**: `Sources/Nexus/Plugs/ContentNegotiation.swift`
**Current Coverage**: ~75%
**Target**: 90%

**Missing Tests**:

1. **Complex Accept Header Scenarios**
   ```swift
   @Test func contentNegotiation复杂头() async throws
   ```
   - Multiple types with quality values
   - Wildcard matching
   - Invalid syntax handling

2. **Charset Negotiation**
   ```swift
   @Test func contentNegotiation字符集() async throws
   ```
   - UTF-8 vs Latin-1
   - Invalid charset handling
   - Default charset fallback

**Action**: Add to `Tests/NexusTests/AdditionalPlugsTests.swift`
**Effort**: 1-2 hours
**Impact**: +0.3% coverage

---

## Property-Based Testing Gaps

### 11. Connection Mutation Properties
**File**: `Sources/Nexus/Connection.swift`

**Missing Properties**:

1. **Associative Property**
   ```swift
   @Test func connectionAssign结合性() async throws
   ```
   - (conn.assign("a", 1).assign("b", 2)).assign("c", 3)
   - Should equal: conn.assign("a", 1).assign("b", 2).assign("c", 3)

2. **Identity Property**
   ```swift
   @Test func connectionAssign恒等() async throws
   ```
   - conn.assign("a", 1).assign("a", nil)
   - Should equal: conn

**Action**: Extend `Tests/NexusTests/PropertyTests/ConnectionProperties.swift`
**Effort**: 2-3 hours
**Impact**: +0.5% coverage + improved confidence

---

### 12. Round-Trip Properties
**Files**: Cookie, MessageSigning, etc.

**Missing Properties**:

1. **Cookie Serialization Round-Trip**
   ```swift
   @Test func cookie序列化往返() async throws
   ```
   - Serialize → Deserialize should preserve all attributes

2. **Message Signing Round-Trip**
   ```swift
   @Test func messageSigning往返() async throws
   ```
   - Sign → Verify should always succeed for unmodified data

**Action**: Extend `Tests/NexusTests/PropertyTests/`
**Effort**: 2-3 hours
**Impact**: +0.5% coverage + improved confidence

---

## Implementation Order

### Week 1: Critical & High Priority
1. Day 1: Fix Vapor adapter compilation
2. Day 2-3: Telemetry coverage (6-8 tests)
3. Day 4-5: WebSocket error paths (5-6 tests)

### Week 2: High & Medium Priority
1. Day 1-2: Security edge cases (8-10 tests)
2. Day 3-4: Adapter integration tests (10-15 tests)
3. Day 5: Compression plug (4-5 tests)

### Week 3: Medium Priority
1. Day 1-2: Timeout plug (4-5 tests)
2. Day 3: Async error paths (5-6 tests)
3. Day 4-5: Property-based tests (15-20 tests)

### Week 4: Low Priority & Polish
1. Day 1-2: SSE edge cases
2. Day 3: Content negotiation
3. Day 4-5: Final coverage gaps

---

## Success Criteria

### 95% Coverage Targets
- Nexus Core: 90% → 95%
- NexusRouter: 90% → 95%
- NexusVapor: 60% → 90%
- NexusHummingbird: 70% → 90%

### Quality Metrics
- All tests pass
- No flaky tests
- Test execution time <5 minutes
- Code coverage verified with llvm-cov

---

## Summary

**Total Tests Needed**: ~100-120 additional tests
**Total Effort**: 60-80 hours
**Coverage Impact**: +7-10% (from ~88% to 95%)

**Critical Path**:
1. Fix compilation → Measure coverage
2. High-priority gaps → +5-8%
3. Medium-priority gaps → +3-5%
4. Polish → Final 95% target

---

**Last Updated**: 2026-04-08
**Status**: Ready for implementation
**Next Action**: Fix Vapor adapter compilation error
