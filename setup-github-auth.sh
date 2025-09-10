#!/bin/bash

# Script to set up GitHub CLI authentication with Personal Access Token

echo "GitHub CLI Authentication Setup"
echo "================================"
echo ""
echo "You'll need a GitHub Personal Access Token with the following scopes:"
echo "  - repo (full control of private repositories)"
echo "  - workflow (optional, for GitHub Actions)"
echo ""
echo "To create a token:"
echo "1. Go to https://github.com/settings/tokens/new"
echo "2. Give it a descriptive name (e.g., 'Babelfish DevTools CLI')"
echo "3. Select expiration (recommend 90 days)"
echo "4. Check 'repo' scope (and 'workflow' if needed)"
echo "5. Click 'Generate token' and copy it"
echo ""
read -p "Enter your GitHub Personal Access Token: " -s TOKEN
echo ""

if [ -z "$TOKEN" ]; then
    echo "Error: No token provided"
    exit 1
fi

# Authenticate with the token
echo "$TOKEN" | gh auth login --with-token

# Check if authentication was successful
if gh auth status 2>/dev/null; then
    echo ""
    echo "✅ Successfully authenticated with GitHub!"
    echo ""
    gh auth status
    echo ""
    echo "You can now run ./create-github-issues.sh to create the project issues."
else
    echo ""
    echo "❌ Authentication failed. Please check your token and try again."
    exit 1
fi