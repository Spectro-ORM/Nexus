# NexusVapor Performance Benchmarks

Comprehensive performance benchmarking suite for the NexusVapor adapter to ensure minimal overhead compared to raw Vapor while providing enhanced middleware composability.

## Overview

These benchmarks measure the NexusVapor adapter's performance across six critical dimensions:

1. **Baseline Adapter Overhead** - Compare NexusVapor vs raw Vapor
2. **Request Throughput** - Measure requests per second 
3. **Memory Allocation** - Track memory per request
4. **Pipeline Composition** - Measure overhead from plug chains
5. **BeforeSend Hooks** - Test lifecycle hook performance
6. **Streaming Performance** - SSE and WebSocket overhead

## Performance Targets

| Metric | Target | Priority |
|--------|--------|----------|
| Adapter overhead | <5% vs raw Vapor | P0 (Critical) |
| Simple throughput | >10,000 req/s | P0 (Critical) |
| 5-plug throughput | >8,000 req/s | P1 (High) |
| Connection memory | <512 bytes | P1 (High) |
| Pipeline execution | <1KB per request | P1 (High) |
| Single plug latency | <50ns | P2 (Medium) |
| BeforeSend hook | <50ns per hook | P2 (Medium) |
| Streaming first byte | <1ms | P2 (Medium) |

## Running Benchmarks

### Run All Benchmarks
```bash
swift test --filter NexusVaporBenchmarks
```

### Run Specific Benchmark Categories
```bash
# Adapter overhead only
swift test --filter "NexusVaporBenchmarks.*Adapter overhead"

# Throughput only
swift test --filter "NexusVaporBenchmarks.*Throughput"

# Memory only
swift test --filter "NexusVaporBenchmarks.*Memory"
```

### Run with Detailed Output
```bash
swift test --filter NexusVaporBenchmarks --verbose
```

### Baseline Comparison
Run benchmarks before and after changes to detect regressions:
```bash
# Before changes
swift test --filter NexusVaporBenchmarks > baseline.txt

# After changes
swift test --filter NexusVaporBenchmarks > after.txt

# Compare (requires custom diff tool or manual review)
diff baseline.txt after.txt
```

## Interpreting Results

### Throughput Benchmarks
- **Higher is better** - More requests per second
- Compare against targets in table above
- Watch for >10% degradation from baseline

### Memory Benchmarks
- **Lower is better** - Less memory per request
- Watch for memory leaks (increasing allocation over time)
- Compare against targets

### Latency Benchmarks
- **Lower is better** - Less time per operation
- Critical for single plug overhead
- Impacts overall pipeline performance

## Benchmark Categories

### 1. Baseline Adapter Overhead
**Purpose**: Establish comparison against raw Vapor

**Key Benchmarks**:
- Raw Vapor response creation
- Simple plug vs raw Vapor
- Request/response conversion
- Empty pipeline overhead

**What to Watch**:
- If overhead exceeds 5%, investigate conversion logic
- Compare against raw Vapor baseline
- Check for unnecessary allocations

### 2. Request Throughput
**Purpose**: Measure practical throughput under various conditions

**Key Benchmarks**:
- Single plug throughput
- 5-plug pipeline
- Request with body
- Header processing

**What to Watch**:
- Throughput should scale with pipeline complexity
- Body processing should be efficient
- Header manipulation should not be bottleneck

### 3. Memory Allocation
**Purpose**: Ensure memory efficiency for production use

**Key Benchmarks**:
- Connection creation
- Pipeline execution
- Response body buffering
- Assigns dictionary

**What to Watch**:
- No memory leaks (allocation should not grow unbounded)
- Linear scaling with data size
- Minimal per-request overhead

### 4. Pipeline Composition
**Purpose**: Measure overhead of plug composition

**Key Benchmarks**:
- Single plug invocation
- pipe() combinator
- 10-plug chain
- Halting behavior

**What to Watch**:
- Linear scaling with plug count
- Minimal overhead from pipe()
- Efficient halt propagation

### 5. BeforeSend Hooks
**Purpose**: Test lifecycle hook performance

**Key Benchmarks**:
- Single hook overhead
- Multiple hooks (LIFO)
- Hook vs inline comparison
- Nested hooks

**What to Watch**:
- Linear scaling with hook count
- Reasonable overhead vs inline (<20%)
- Efficient nested hook handling

### 6. Streaming Performance
**Purpose**: Measure streaming response capabilities

**Key Benchmarks**:
- Empty stream creation
- Single chunk latency
- Multi-chunk throughput
- SSE-style streaming

**What to Watch**:
- Fast first byte (<1ms)
- Efficient chunk yielding
- Low overhead per chunk

## Regression Detection

### Automated Detection
Run benchmarks in CI to catch performance regressions:

```yaml
# .github/workflows/benchmarks.yml
name: Benchmarks
on: [push, pull_request]
jobs:
  benchmark:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run benchmarks
        run: swift test --filter NexusVaporBenchmarks
```

### Manual Detection
1. Establish baseline after major changes
2. Run benchmarks regularly
3. Compare results against baseline
4. Investigate >10% degradation

### Common Performance Issues

**High Adapter Overhead (>5%)**:
- Check request/response conversion logic
- Look for unnecessary data copying
- Optimize header field processing

**Low Throughput (<10,000 req/s)**:
- Profile single plug performance
- Check for unnecessary allocations
- Optimize hot paths in conversion

**High Memory Usage**:
- Check for retained connections
- Look for leaking callbacks/hooks
- Verify proper cleanup

**Slow Streaming (>1ms first byte)**:
- Optimize AsyncStream creation
- Check for unnecessary buffering
- Verify efficient yielding

## Performance Optimization

### Profiling
Use Instruments to identify bottlenecks:

```bash
# Build for profiling
swift build -c release

# Run with Instruments (requires Xcode)
instruments -t "Time Profiler" swift test --filter NexusVaporBenchmarks
```

### Common Optimizations

1. **Reduce Allocations**: Reuse objects where possible
2. **Optimize Hot Paths**: Focus on frequently executed code
3. **Minimize Copying**: Use views/references instead of copies
4. **Lazy Evaluation**: Defer work until necessary
5. **Special Cases**: Fast-path common scenarios

### Before Optimizing

1. **Measure First**: Establish baseline with current benchmarks
2. **Identify Bottleneck**: Use profiling to find hot spots
3. **Set Target**: Define measurable improvement goal
4. **Verify**: Re-run benchmarks to confirm improvement
5. **Document**: Record what was optimized and why

## Contributing

When adding new features to NexusVapor:

1. Add corresponding benchmarks
2. Document performance targets
3. Compare against baseline
4. Update this README with new benchmarks

## References

- [Nexus Architecture](../../../Docs/ADR/ADR-001-architecture.md)
- [Vapor Performance Guide](https://docs.vapor.codes/advanced/performance/)
- [Swift Testing Framework](https://github.com/apple/swift-testing)

## License

Part of the Nexus project. See main project LICENSE file.
