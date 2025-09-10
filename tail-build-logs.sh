#!/bin/bash

echo "=== Docker Build Log Monitor ==="
echo ""

# Method 1: Check for active builds via docker-compose
if [ -f ".devcontainer/docker-compose.yml" ]; then
    echo "📦 Method 1: Docker Compose Logs"
    echo "--------------------------------"
    echo "Run this command to see build output:"
    echo "docker-compose -f .devcontainer/docker-compose.yml build --progress=plain"
    echo ""
    echo "Or if already building, follow logs:"
    echo "docker-compose -f .devcontainer/docker-compose.yml logs -f --tail=50"
    echo ""
fi

# Method 2: Find building containers
echo "🔨 Method 2: Active Docker Builds"
echo "---------------------------------"
BUILDING=$(docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Status}}" | grep -i "build\|creating")
if [ ! -z "$BUILDING" ]; then
    echo "Found building containers:"
    echo "$BUILDING"
    echo ""
    echo "Get logs with: docker logs -f <container-id>"
else
    echo "No active builds found via docker ps"
fi
echo ""

# Method 3: Docker buildx logs (if using buildkit)
echo "🏗️ Method 3: BuildKit Logs"
echo "-------------------------"
echo "For BuildKit builds, use:"
echo "docker buildx build --progress=plain -f Dockerfile ."
echo ""

# Method 4: VS Code DevContainer specific logs
echo "📝 Method 4: VS Code DevContainer Logs"
echo "--------------------------------------"
echo "In VS Code:"
echo "1. Open Output panel (View > Output)"
echo "2. Select 'Dev Containers' from dropdown"
echo "3. This shows real-time build progress"
echo ""
echo "Or check VS Code log file:"
if [ -d "$HOME/.config/Code/logs" ]; then
    echo "tail -f ~/.config/Code/logs/*/exthost*/output_logging_*/*devcontainer*"
fi
echo ""

# Method 5: Docker events to see what's happening
echo "📊 Method 5: Real-time Docker Events"
echo "------------------------------------"
echo "docker events --filter event=create --filter event=start"
echo ""

# Method 6: Check if VS Code is building in background
echo "🔍 Checking for VS Code DevContainer processes..."
VSCODE_BUILD=$(ps aux | grep -E "docker-compose.*devcontainer|docker.*build.*devcontainer" | grep -v grep)
if [ ! -z "$VSCODE_BUILD" ]; then
    echo "Found VS Code DevContainer build process:"
    echo "$VSCODE_BUILD"
    echo ""
    echo "The build is happening in background. Try:"
    echo "1. Check VS Code Output panel"
    echo "2. Or find the process ID and strace it: sudo strace -p <PID> -s 9999"
else
    echo "No VS Code DevContainer build process found"
fi
echo ""

# Method 7: Direct build with full output
echo "💡 TIP: To see FULL build output, manually build:"
echo "------------------------------------------------"
echo "cd $(pwd)"
echo "docker-compose -f .devcontainer/docker-compose.yml build --no-cache --progress=plain 2>&1 | tee build.log"
echo ""
echo "This will show ALL output including stderr and save to build.log"