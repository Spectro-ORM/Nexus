#!/bin/bash
# check-coverage.sh
# Check if coverage meets the minimum threshold (85%)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

COVERAGE_THRESHOLD=85
COVERAGE_DIR=".build/coverage"

echo -e "${GREEN}Checking coverage threshold (minimum: ${COVERAGE_THRESHOLD}%)...${NC}"

# Find the most recent test bundle
TEST_BUNDLE=$(find .build -name "swift-package-tests" -type f | head -n 1)

if [ -z "$TEST_BUNDLE" ]; then
    echo -e "${RED}Error: Could not find test bundle. Run tests with coverage first.${NC}"
    echo "Run: swift test --enable-code-coverage"
    exit 1
fi

# Get coverage summary
COVERAGE_SUMMARY=$(llvm-cov report "$TEST_BUNDLE" \
    --ignore-filename-regex='Tests/|\.build/|Checkouts/' 2>/dev/null)

if [ -z "$COVERAGE_SUMMARY" ]; then
    echo -e "${RED}Error: Could not generate coverage report${NC}"
    exit 1
fi

# Extract total coverage percentage (last line, last column)
TOTAL_COVERAGE=$(echo "$COVERAGE_SUMMARY" | tail -n 1 | awk '{print $NF}')

# Remove % sign and convert to number
COVERAGE_NUMBER=$(echo "$TOTAL_COVERAGE" | sed 's/%//')

echo "Current Coverage: $TOTAL_COVERAGE"
echo "Required Threshold: ${COVERAGE_THRESHOLD}%"

# Check if coverage meets threshold
if (( $(echo "$COVERAGE_NUMBER < $COVERAGE_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${RED}FAILED: Coverage ($TOTAL_COVERAGE) is below threshold (${COVERAGE_THRESHOLD}%)${NC}"
    echo ""
    echo "Coverage breakdown:"
    echo "$COVERAGE_SUMMARY"
    exit 1
else
    echo -e "${GREEN}PASSED: Coverage ($TOTAL_COVERAGE) meets threshold (${COVERAGE_THRESHOLD}%)${NC}"
fi

echo -e "${GREEN}Coverage check passed${NC}"
