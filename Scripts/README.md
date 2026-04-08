# Nexus Scripts

This directory contains utility scripts for development, testing, and coverage reporting.

## Coverage Scripts

### `generate-coverage.sh`
Generates code coverage data using Swift's built-in coverage tools.

```bash
./Scripts/generate-coverage.sh
```

**What it does:**
- Cleans previous build artifacts
- Builds tests with code coverage enabled
- Runs tests with coverage instrumentation

**Output:**
- Coverage data in `.build/` directory

### `coverage-report.sh`
Generates HTML coverage reports and summary statistics.

```bash
./Scripts/coverage-report.sh
```

**What it does:**
- Exports coverage data to LCOV format
- Generates HTML report (if `genhtml` is available)
- Displays coverage summary statistics
- Verifies coverage meets minimum threshold (85%)

**Output:**
- HTML report: `.build/coverage/html/index.html`
- LCOV data: `.build/coverage/coverage.lcov`
- Summary: `.build/coverage/summary.txt`

**Dependencies:**
- `genhtml` (optional, for HTML reports): `brew install lcov`

### `check-coverage.sh`
Checks if coverage meets the minimum threshold (85%).

```bash
./Scripts/check-coverage.sh
```

**What it does:**
- Generates coverage data if needed
- Extracts coverage percentage
- Compares against threshold (85%)
- Fails with exit code 1 if below threshold

**Exit codes:**
- 0: Coverage meets or exceeds threshold
- 1: Coverage below threshold or error

## Usage Examples

### Generate coverage report locally
```bash
swift test --enable-code-coverage
./Scripts/coverage-report.sh
open .build/coverage/html/index.html
```

### Verify coverage before commit
```bash
swift test --enable-code-coverage
./Scripts/check-coverage.sh
```

### Run specific test suites with coverage
```bash
swift test --filter NexusTests --enable-code-coverage
./Scripts/coverage-report.sh
```

## CI Integration

These scripts are integrated into GitHub Actions workflows:

- `.github/workflows/coverage.yml` - Full coverage reporting with PR comments
- `.github/workflows/ci.yml` - Basic coverage check in CI

## Troubleshooting

### "genhtml not found"
Install `lcov` package: `brew install lcov`

### "Could not find test bundle"
Run tests with coverage first: `swift test --enable-code-coverage`

### Coverage percentage seems low
- Ensure all test files are included in the test target
- Check that test execution completes successfully
- Verify that `--enable-code-coverage` flag is used
