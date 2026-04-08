#!/bin/bash
# GitHub Actions script to generate coverage data

set -e

echo "Generating code coverage data..."

# Clean build artifacts to ensure clean coverage data
swift package clean

# Run tests with coverage enabled
swift test --enable-code-coverage

echo "Coverage data generation complete"
