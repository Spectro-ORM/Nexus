# Coverage Improvement Checklist

## Status Legend
- ⛔ **BLOCKER** - Prevents progress
- 🔴 **HIGH** - High priority, high impact
- 🟡 **MEDIUM** - Medium priority, moderate impact
- 🟢 **LOW** - Low priority, minimal impact
- ✅ **DONE** - Completed

---

## Critical Path (Must Complete First)

### Fix Compilation Issues
- [ ] Fix Vapor WebSocketErrorCode conversion (`WebSocketAdapter.swift:248`)
- [ ] Verify all targets compile successfully
- [ ] Run full test suite to confirm no breakage
- [ ] Generate baseline coverage report

**Estimated**: 1 hour
**Impact**: Unblocks all coverage work

---

## High-Priority Gaps (5-8% coverage impact)

### 1. Telemetry Plug Coverage 🔴
**File**: `Sources/Nexus/Plugs/Telemetry.swift`
**Current**: ~60% → **Target**: 95%

- [ ] Test metrics collection accuracy
  - [ ] Request count increments
  - [ ] Error count increments
  - [ ] Response time recording
- [ ] Test concurrent request tracking
  - [ ] 100 simultaneous requests
  - [ ] No race conditions
- [ ] Test performance overhead
  - [ ] Overhead <5%
  - [ ] Varying request rates

**File to Create**: `Tests/NexusTests/TelemetryCoverageTests.swift`
**Estimated**: 2-3 hours

### 2. WebSocket Error Paths 🔴
**File**: `Sources/Nexus/WebSocket/WSConnection.swift`
**Current**: ~85% → **Target**: 95%

- [ ] Test upgrade error handling
  - [ ] Invalid upgrade requests
  - [ ] Missing headers
  - [ ] Connection failures
- [ ] Test large message fragmentation
  - [ ] 10MB message handling
  - [ ] Fragmentation verification
- [ ] Test ping/pong timeout
  - [ ] No response handling
  - [ ] Connection closure
  - [ ] Timeout detection

**File to Extend**: `Tests/NexusTests/WebSocketTests.swift`
**Estimated**: 2-3 hours

### 3. Security Edge Cases 🔴
**Multiple Files** → **Target**: 95%

- [ ] HTTP Header Injection (CORS)
  - [ ] Malformed Origin headers
  - [ ] Header value injection
  - [ ] Regex DoS prevention
- [ ] Request Smuggling
  - [ ] Chunked encoding edge cases
  - [ ] Content-Length conflicts
  - [ ] Transfer-Encoding manipulation
- [ ] Compression Bomb
  - [ ] 1MB → 1GB decompression
  - [ ] Size limit enforcement
  - [ ] Decompression ratio limits

**File to Create**: `Tests/NexusTests/SecurityEdgeCasesTests.swift`
**Estimated**: 3-4 hours

### 4. Adapter Integration Tests 🔴
**Files**: `Sources/NexusVapor/`, `Sources/NexusHummingbird/`
**Current**: 60-75% → **Target**: 90%

- [ ] Vapor integration
  - [ ] Full request lifecycle
  - [ ] Middleware chain execution
  - [ ] Error propagation
- [ ] Hummingbird integration
  - [ ] Full request lifecycle
  - [ ] Adapter-specific features
  - [ ] Error handling
- [ ] Adapter error recovery
  - [ ] Partial response failures
  - [ ] Connection errors
  - [ ] Timeout handling

**File to Extend**: `Tests/NexusVaporTests/IntegrationTests.swift`
**Estimated**: 4-5 hours

---

## Medium-Priority Gaps (3-5% coverage impact)

### 5. Compression Plug 🟡
**File**: `Sources/Nexus/Plugs/Compression.swift`
**Current**: ~70% → **Target**: 95%

- [ ] Compression error handling
  - [ ] Corrupted data handling
  - [ ] Unsupported format
  - [ ] Memory limits
- [ ] Already-compressed detection
  - [ ] Pre-compressed content
  - [ ] Image skip logic
  - [ ] Content-Encoding header
- [ ] Memory efficiency
  - [ ] Streaming compression
  - [ ] Constant memory
  - [ ] Large files

**Estimated**: 2 hours

### 6. Timeout Plug 🟡
**File**: `Sources/Nexus/Plugs/Timeout.swift`
**Current**: ~70% → **Target**: 95%

- [ ] Timeout cancellation propagation
  - [ ] Task.cancel() propagation
  - [ ] Cleanup execution
  - [ ] Resource release
- [ ] Task cancellation handling
  - [ ] Cancel before timeout
  - [ ] Cancel during execution
  - [ ] No partial state
- [ ] Resource cleanup verification
  - [ ] File handles closed
  - [ ] Network connections closed
  - [ ] Memory released

**Estimated**: 2 hours

### 7. Async Error Propagation 🟡
**Multiple Files** → **Target**: 95%

- [ ] Stream cancellation propagation
  - [ ] RequestBody stream cancellation
  - [ ] ResponseBody stream cancellation
  - [ ] Upstream cancellation
- [ ] Network timeout cascading
  - [ ] Middleware timeout
  - [ ] Plug timeout
  - [ ] Error propagation
- [ ] Concurrent access race conditions
  - [ ] Simultaneous mutations
  - [ ] Actor isolation
  - [ ] Data race freedom

**File to Create**: `Tests/NexusTests/AsyncErrorPathTests.swift`
**Estimated**: 3 hours

---

## Low-Priority Gaps (2-3% coverage impact)

### 8. SSE Streaming 🟢
**File**: `Sources/Nexus/SSE.swift`
**Current**: ~70% → **Target**: 90%

- [ ] Client disconnect scenarios
- [ ] Event serialization edge cases

**Estimated**: 1-2 hours

### 9. Content Negotiation 🟢
**File**: `Sources/Nexus/Plugs/ContentNegotiation.swift`
**Current**: ~75% → **Target**: 90%

- [ ] Complex accept header scenarios
- [ ] Charset negotiation

**Estimated**: 1-2 hours

### 10. Connection Convenience 🟢
**File**: `Sources/Nexus/Connection+Convenience.swift`
**Current**: ~85% → **Target**: 95%

- [ ] Async convenience method edge cases
- [ ] Error propagation scenarios

**Estimated**: 1 hour

---

## Property-Based Testing (Bonus Confidence)

### 11. Connection Properties 🟡
**File**: `Tests/NexusTests/PropertyTests/ConnectionProperties.swift`

- [ ] Associative property for assign()
- [ ] Identity property for assign()
- [ ] Commutative property for mutations

**Estimated**: 2-3 hours

### 12. Round-Trip Properties 🟡
**Multiple Files**

- [ ] Cookie serialization round-trip
- [ ] Message signing round-trip
- [ ] Header parsing idempotency

**Estimated**: 2-3 hours

---

## Progress Tracking

### Overall Progress
- [ ] **Week 1**: Critical & High Priority (20-25 hours)
- [ ] **Week 2**: High & Medium Priority (20-25 hours)
- [ ] **Week 3**: Medium Priority (15-20 hours)
- [ ] **Week 4**: Low Priority & Polish (10-15 hours)

### Coverage Milestones
- [ ] **Baseline**: Measure current coverage (after fixing compilation)
- [ ] **Milestone 1**: Reach 90% coverage (complete high-priority items)
- [ ] **Milestone 2**: Reach 93% coverage (complete medium-priority items)
- [ ] **Milestone 3**: Reach 95% coverage (complete all items)

### Quality Gates
- [ ] All new tests pass
- [ ] No flaky tests introduced
- [ ] Test execution time <5 minutes
- [ ] Code coverage verified with llvm-cov
- [ ] Security tests pass
- [ ] Property tests find no counterexamples

---

## Quick Reference Summary

**Total Tests Needed**: ~100-120 additional tests
**Total Estimated Time**: 60-80 hours
**Expected Coverage Increase**: +7-10% (from ~88% to 95%)

### Critical Path (Start Here)
1. Fix compilation → Measure baseline
2. Telemetry coverage → +1.5%
3. WebSocket errors → +1%
4. Security edge cases → +1.5%
5. Adapter integration → +2-3%

### Medium Impact
6. Compression plug → +0.5%
7. Timeout plug → +0.5%
8. Async errors → +1%

### Final Polish
9. SSE & Content negotiation → +0.6%
10. Property-based tests → +0.5%

---

## Commands

### Generate Coverage Report
```bash
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/swift-package-tests \
  --use-color \
  --ignore-filename-regex='Tests/|\.build/|Checkouts/'
```

### Run Specific Test Suite
```bash
swift test --filter NexusTests.WebSocketTests
swift test --filter NexusTests.TelemetryCoverageTests
swift test --filter NexusTests.SecurityEdgeCasesTests
```

### Measure Test Execution Time
```bash
time swift test
```

---

**Last Updated**: 2026-04-08
**Next Action**: Fix Vapor adapter compilation
**Target Date**: 95% coverage within 4 weeks
