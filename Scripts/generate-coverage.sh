#!/bin/bash
# generate-coverage.sh
# Generate code coverage data for Nexus using Swift's built-in coverage tools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Generating code coverage data...${NC}"

# Clean build artifacts to ensure clean coverage data
echo "Cleaning previous build artifacts..."
swift package clean

# Build tests with coverage enabled
echo "Building tests with code coverage enabled..."
swift build --build-tests

# Run tests with coverage
echo "Running tests with code coverage..."
swift test --enable-code-coverage

# Create coverage directory
COVERAGE_DIR=".build/coverage"
mkdir -p "$COVERAGE_DIR"

echo -e "${GREEN}Coverage data generated successfully${NC}"
echo "Coverage data location: $COVERAGE_DIR"
