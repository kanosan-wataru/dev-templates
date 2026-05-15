#!/bin/bash

# Check if vtsls is installed and available in PATH

if command -v vtsls &> /dev/null; then
    exit 0
fi

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo "[vtsls] npm is not installed. Please install Node.js first from https://nodejs.org/"
    echo "        Then run: npm install -g @vtsls/language-server typescript"
    exit 0
fi

# npm is installed but vtsls is not - install it
echo "[vtsls] Installing vtsls..."
npm install -g @vtsls/language-server typescript

if command -v vtsls &> /dev/null; then
    echo "[vtsls] Installed successfully"
else
    echo "[vtsls] Failed to install. Please run manually:"
    echo "        npm install -g @vtsls/language-server typescript"
fi

exit 0
