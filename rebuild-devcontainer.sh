#!/bin/bash

echo "=== DevContainer Rebuild Script ==="
echo ""

# Clean up any existing containers
echo "1. Cleaning up existing containers..."
docker ps -a | grep -E "docker-babelfishpg-devtools|devcontainer" | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null

# Clean up compose resources
echo "2. Cleaning up docker-compose resources..."
docker-compose -f .devcontainer/docker-compose.yml down 2>/dev/null

# Remove any dangling images
echo "3. Removing dangling images..."
docker image prune -f

# Clear VS Code/Cursor DevContainer cache
echo "4. Clearing DevContainer cache..."
if [ -d "$HOME/.vscode-server" ]; then
    rm -rf $HOME/.vscode-server/data/Machine/devcontainers.json 2>/dev/null
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Now you can rebuild the DevContainer in VS Code/Cursor:"
echo "1. Open VS Code/Cursor"
echo "2. Press F1 or Ctrl+Shift+P"
echo "3. Run: 'Dev Containers: Rebuild Container'"
echo ""
echo "Or build manually:"
echo "docker-compose -f .devcontainer/docker-compose.yml build --no-cache"