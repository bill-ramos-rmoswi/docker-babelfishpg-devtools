#!/bin/bash
# Helper script to build the DevContainer image with progress monitoring
# This handles the long build time (30-60 minutes) for first build

echo "========================================="
echo "Building Babelfish DevContainer"
echo "First build takes 30-60 minutes"
echo "========================================="

# Build with docker-compose directly to see progress
docker-compose -f .devcontainer/docker-compose.yml build --progress=plain

if [ $? -eq 0 ]; then
    echo "========================================="
    echo "Build completed successfully!"
    echo "Now you can open in DevContainer from VS Code/Cursor"
    echo "========================================="
else
    echo "========================================="
    echo "Build failed. Check the output above for errors."
    echo "========================================="
    exit 1
fi