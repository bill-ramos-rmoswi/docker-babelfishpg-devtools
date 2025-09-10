#!/bin/bash

echo "=== Capturing Docker Build Errors ==="
echo ""
echo "Starting build with full error capture..."
echo "Output will be saved to: build-error.log"
echo ""

# Build with full output capture
docker-compose -f .devcontainer/docker-compose.yml build --no-cache --progress=plain 2>&1 | tee build-error.log

# Check if build failed
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "❌ Build failed! Analyzing error..."
    echo ""
    echo "=== Last 50 lines of error log ==="
    tail -50 build-error.log
    echo ""
    echo "=== Searching for common error patterns ==="
    grep -E "ERROR|FAILED|error:|fatal:|cannot|unable|not found|No such" build-error.log | tail -20
    echo ""
    echo "Full log saved to: build-error.log"
else
    echo ""
    echo "✅ Build completed successfully!"
fi