#!/usr/bin/env bats

# Platform detection tests

MODULES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../modules" && pwd)"

@test "all modules with _detect_env return valid values" {
    for f in "$MODULES_DIR"/*.sh; do
        local mod_name
        mod_name=$(basename "$f" .sh)
        # Check if module has a detect_env function
        if grep -q '_detect_env()' "$f"; then
            # Extract function name
            local func_name
            func_name=$(grep -o '_[a-z0-9_]*_detect_env' "$f" | head -1)
            # Source the module in a subshell and run detect_env
            run zsh -c "source '$f' 2>/dev/null; ${func_name}"
            if [ "$status" -ne 0 ]; then
                echo "${mod_name}: ${func_name} failed with status $status" >&2
                return 1
            fi
            # Check return value is one of valid options
            if ! [[ "$output" =~ ^(macos|linux|wsl|unknown)$ ]]; then
                echo "${mod_name}: ${func_name} returned unexpected value: $output" >&2
                return 1
            fi
        fi
    done
}

@test "all modules pass zsh syntax check" {
    for f in "$MODULES_DIR"/*.sh; do
        run zsh -n "$f"
        if [ "$status" -ne 0 ]; then
            echo "$(basename "$f") has syntax errors: $output" >&2
            return 1
        fi
    done
}

@test "setup.sh passes zsh syntax check" {
    local setup_sh
    setup_sh="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/setup.sh"
    run zsh -n "$setup_sh"
    if [ "$status" -ne 0 ]; then
        echo "setup.sh has syntax errors: $output" >&2
        return 1
    fi
}
