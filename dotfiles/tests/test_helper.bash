#!/usr/bin/env bash

# Test helper for BATS tests
# Sources setup.sh helpers in a safe environment

DOTFILES_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"

# Mock DRY_RUN to prevent actual system changes
export DRY_RUN=1

# Source helpers from setup.sh (extract only helper functions)
# We need to source carefully to avoid running the main script
setup_helpers() {
    # Create a temporary file with just the helper functions
    local tmp_helpers
    tmp_helpers=$(mktemp)

    # Extract function definitions from setup.sh
    sed -n '/^run_cmd()/,/^}/p' "$DOTFILES_DIR/setup.sh" > "$tmp_helpers"
    sed -n '/^install_config()/,/^}/p' "$DOTFILES_DIR/setup.sh" >> "$tmp_helpers"
    sed -n '/^ensure_node()/,/^}/p' "$DOTFILES_DIR/setup.sh" >> "$tmp_helpers"

    source "$tmp_helpers"
    rm -f "$tmp_helpers"
}
