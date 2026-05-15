#!/bin/bash

# Check if pyright-langserver is installed and available in PATH

if command -v pyright-langserver &> /dev/null; then
    exit 0
fi

# Prefer pipx (isolated venv, avoids PEP 668 externally-managed-environment)
if command -v pipx &> /dev/null; then
    echo "[pyright] Installing pyright via pipx..."
    pipx install pyright

    if command -v pyright-langserver &> /dev/null; then
        echo "[pyright] Installed successfully"
    else
        echo "[pyright] Failed to install. Please run manually:"
        echo "          pipx install pyright"
    fi
    exit 0
fi

# Fallback: pip with --user (avoids system-wide install)
if command -v pip &> /dev/null; then
    echo "[pyright] pipx not found. Installing via pip --user..."
    pip install --user pyright 2>&1 || \
        echo "[pyright] pip install failed. Install pipx first: sudo apt install pipx"

    if command -v pyright-langserver &> /dev/null; then
        echo "[pyright] Installed successfully"
    else
        echo "[pyright] Failed to install. Please run manually:"
        echo "          pipx install pyright  (recommended)"
        echo "          or: pip install --user pyright"
    fi
    exit 0
fi

echo "[pyright] Neither pipx nor pip is installed. Please install Python + pipx first."
echo "          sudo apt install pipx && pipx install pyright"
exit 0
