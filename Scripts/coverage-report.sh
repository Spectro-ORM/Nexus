#!/bin/bash
# coverage-report.sh
# Generate HTML coverage reports from coverage data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

COVERAGE_DIR=".build/coverage"
REPORT_DIR="$COVERAGE_DIR/html"

echo -e "${GREEN}Generating HTML coverage report...${NC}"

# Create report directory
mkdir -p "$REPORT_DIR"

# Find the test bundle (could be .xctest or binary)
TEST_BUNDLE=$(find .build -name "*PackageTests.xctest" -o -name "swift-package-tests" | head -n 1)

if [ -z "$TEST_BUNDLE" ]; then
    echo -e "${RED}Error: Could not find test bundle. Run tests with coverage first.${NC}"
    echo "Run: swift test --enable-code-coverage"
    exit 1
fi

echo "Using test bundle: $TEST_BUNDLE"

# Check if we have profdata files
PROFDATA_FILES=$(find .build -name "*.profdata" | head -n 1)

if [ -z "$PROFDATA_FILES" ]; then
    echo -e "${YELLOW}Warning: No profdata files found. Coverage data may not be available.${NC}"
    echo "Generating basic test report instead..."

    # Just run tests and show summary
    swift test --enable-code-coverage

    echo ""
    echo -e "${GREEN}Coverage generation complete${NC}"
    echo "Note: For detailed coverage reports, ensure Xcode tools are available"
else
    echo "Found coverage data files"

    # Export coverage to lcov format
    LCOV_FILE="$COVERAGE_DIR/coverage.lcov"

    # Use llvm-cov to export coverage
    xcrun llvm-cov export "$TEST_BUNDLE" \
        -instr-profile="$PROFDATA_FILES" \
        --format=lcov \
        --ignore-filename-regex='Tests/|\.build/|Checkouts/' \
        > "$LCOV_FILE" 2>/dev/null || echo "Could not export LCOV format"

    # Generate HTML report if genhtml is available
    if command -v genhtml &> /dev/null && [ -f "$LCOV_FILE" ]; then
        echo "Generating HTML report with genhtml..."
        genhtml "$LCOV_FILE" \
            --output-directory "$REPORT_DIR" \
            --title "Nexus Coverage Report" \
            --legend \
            --show-details

        echo -e "${GREEN}HTML coverage report generated successfully${NC}"
        echo "Report location: $REPORT_DIR/index.html"
        echo "Open in browser: open $REPORT_DIR/index.html"
    else
        echo -e "${YELLOW}HTML report generation skipped (genhtml not available)${NC}"
        echo "Install with: brew install lcov"
    fi

    # Generate summary statistics if we have the tools
    if command -v xcrun &> /dev/null; then
        COVERAGE_SUMMARY="$COVERAGE_DIR/summary.txt"

        echo "Generating coverage summary..."
        xcrun llvm-cov report "$TEST_BUNDLE" \
            -instr-profile="$PROFDATA_FILES" \
            --ignore-filename-regex='Tests/|\.build/|Checkouts/' \
            > "$COVERAGE_SUMMARY" 2>/dev/null || echo "Could not generate summary"

        if [ -f "$COVERAGE_SUMMARY" ]; then
            echo ""
            echo -e "${GREEN}Coverage Summary:${NC}"
            cat "$COVERAGE_SUMMARY"

            # Extract overall coverage percentage
            TOTAL_COVERAGE=$(tail -n 1 "$COVERAGE_SUMMARY" | awk '{print $NF}')

            echo ""
            echo -e "${GREEN}Total Coverage: $TOTAL_COVERAGE${NC}"

            # Check if coverage meets threshold
            COVERAGE_NUMBER=$(echo "$TOTAL_COVERAGE" | sed 's/%//')
            THRESHOLD=85

            if command -v bc &> /dev/null; then
                if (( $(echo "$COVERAGE_NUMBER < $THRESHOLD" | bc -l) )); then
                    echo -e "${RED}Coverage ($COVERAGE_NUMBER%) is below threshold ($THRESHOLD%)${NC}"
                    exit 1
                else
                    echo -e "${GREEN}Coverage ($COVERAGE_NUMBER%) meets threshold ($THRESHOLD%)${NC}"
                fi
            fi
        fi
    else
        echo -e "${YELLOW}Coverage summary generation requires Xcode tools${NC}"
    fi
fi

echo -e "${GREEN}Coverage report generation complete${NC}"
