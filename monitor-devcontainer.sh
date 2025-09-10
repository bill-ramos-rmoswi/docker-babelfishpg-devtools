#!/bin/bash

# Script to monitor DevContainer build and startup progress

echo "=== Monitoring DevContainer Progress ==="
echo ""

# Function to show container status
show_status() {
    echo "----------------------------------------"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Status Check"
    echo "----------------------------------------"
    
    # Show running containers
    echo "📦 Running Containers:"
    docker ps --filter "label=devcontainer.local_folder=${PWD}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Show recent container events
    echo ""
    echo "📋 Recent Events (last 30 seconds):"
    docker events --since 30s --until 0s --format "{{.Time}} - {{.Actor.Attributes.name}}: {{.Action}}" 2>/dev/null | tail -5
}

# Monitor build progress (if building)
echo "🔨 Checking for active builds..."
docker build . --progress=plain 2>&1 | grep -E "^\[.*\]|Step" &

# Check if docker-compose is being used
if [ -f ".devcontainer/docker-compose.yml" ]; then
    echo ""
    echo "🐳 Docker Compose Status:"
    docker-compose -f .devcontainer/docker-compose.yml ps
fi

echo ""
echo "📊 Real-time Monitoring (Ctrl+C to stop):"
echo "========================================="

# Continuous monitoring
while true; do
    show_status
    sleep 5
done