#!/bin/bash
# Script to monitor the Docker build progress

echo "========================================="
echo "Monitoring Docker Build Progress"
echo "========================================="
echo ""
echo "To start the build, run this in a separate terminal:"
echo "  docker build -t babelfishpg-devtools . --progress=plain"
echo ""
echo "Build stages to expect:"
echo "  1. base - Ubuntu setup (quick)"
echo "  2. build-deps - Installing dependencies (5-10 mins)"
echo "  3. antlr-builder - Building ANTLR runtime (5-10 mins)"
echo "  4. postgres-builder - Building PostgreSQL/Babelfish (15-25 mins)"
echo "  5. bbfdump-builder - Building backup utilities (5-10 mins)"
echo "  6. runner - Final image assembly (5 mins)"
echo ""
echo "Total expected time: 30-60 minutes"
echo ""
echo "Monitoring Docker build activity..."
echo "========================================="

# Watch for Docker activity
watch -n 5 'echo "Active Docker builds:"; docker ps --filter "label=com.docker.compose.project" --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"; echo ""; echo "Docker images being built:"; docker images --filter "dangling=false" | grep -E "babelfishpg|none" | head -5'