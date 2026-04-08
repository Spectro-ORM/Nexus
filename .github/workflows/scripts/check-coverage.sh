#!/bin/bash
# GitHub Actions script to check coverage threshold

set -e

COVERAGE_THRESHOLD=85

echo "Checking coverage threshold (minimum: ${COVERAGE_THRESHOLD}%)..."

# Find the most recent test bundle
TEST_BUNDLE=$(find .build -name "swift-package-tests" -type f | head -n 1)

if [ -z "$TEST_BUNDLE" ]; then
    echo "::error::Could not find test bundle"
    exit 1
fi

# Get coverage summary
COVERAGE_SUMMARY=$(llvm-cov report "$TEST_BUNDLE" \
    --ignore-filename-regex='Tests/|\.build/|Checkouts/' 2>/dev/null)

if [ -z "$COVERAGE_SUMMARY" ]; then
    echo "::error::Could not generate coverage report"
    exit 1
fi

# Extract total coverage percentage
TOTAL_COVERAGE=$(echo "$COVERAGE_SUMMARY" | tail -n 1 | awk '{print $NF}')
COVERAGE_NUMBER=$(echo "$TOTAL_COVERAGE" | sed 's/%//')

# Save summary for PR comment
mkdir -p .build/coverage
echo "$COVERAGE_SUMMARY" > .build/coverage/summary.txt

echo "Current Coverage: $TOTAL_COVERAGE"
echo "Required Threshold: ${COVERAGE_THRESHOLD}%"

# Check if coverage meets threshold
if command -v bc &> /dev/null; then
    if (( $(echo "$COVERAGE_NUMBER < $COVERAGE_THRESHOLD" | bc -l) )); then
        echo "::error::Coverage ($TOTAL_COVERAGE) is below threshold (${COVERAGE_THRESHOLD}%)"
        echo "Coverage breakdown:"
        echo "$COVERAGE_SUMMARY"
        exit 1
    fi
else
    # Fallback for systems without bc
    if [ "$COVERAGE_NUMBER" -lt "$COVERAGE_THRESHOLD" ]; then
        echo "::error::Coverage ($TOTAL_COVERAGE) is below threshold (${COVERAGE_THRESHOLD}%)"
        echo "Coverage breakdown:"
        echo "$COVERAGE_SUMMARY"
        exit 1
    fi
fi

echo "::notice::Coverage check passed: $TOTAL_COVERAGE >= ${COVERAGE_THRESHOLD}%"
