#!/usr/bin/env bats

# Module metadata validation tests

MODULES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../modules" && pwd)"

@test "all modules have MODULE_ID" {
    for f in "$MODULES_DIR"/*.sh; do
        run grep -q '^MODULE_ID=' "$f"
        if [ "$status" -ne 0 ]; then
            echo "$(basename "$f") is missing MODULE_ID" >&2
            return 1
        fi
    done
}

@test "all modules have MODULE_NAME" {
    for f in "$MODULES_DIR"/*.sh; do
        run grep -q '^MODULE_NAME=' "$f"
        if [ "$status" -ne 0 ]; then
            echo "$(basename "$f") is missing MODULE_NAME" >&2
            return 1
        fi
    done
}

@test "all modules have MODULE_DESC" {
    for f in "$MODULES_DIR"/*.sh; do
        run grep -q '^MODULE_DESC=' "$f"
        if [ "$status" -ne 0 ]; then
            echo "$(basename "$f") is missing MODULE_DESC" >&2
            return 1
        fi
    done
}

@test "all modules have MODULE_ORDER" {
    for f in "$MODULES_DIR"/*.sh; do
        run grep -q '^MODULE_ORDER=' "$f"
        if [ "$status" -ne 0 ]; then
            echo "$(basename "$f") is missing MODULE_ORDER" >&2
            return 1
        fi
    done
}

@test "all modules define setup_<safe_id> function" {
    for f in "$MODULES_DIR"/*.sh; do
        # Extract MODULE_ID and convert hyphens to underscores for safe_id
        local module_id
        module_id=$(grep '^MODULE_ID=' "$f" | head -1 | cut -d= -f2 | tr -d '"')
        local safe_id="${module_id//-/_}"
        run grep -q "^setup_${safe_id}()" "$f"
        if [ "$status" -ne 0 ]; then
            echo "$(basename "$f") is missing setup_${safe_id}()" >&2
            return 1
        fi
    done
}

@test "MODULE_ORDER values are unique" {
    local orders=()
    for f in "$MODULES_DIR"/*.sh; do
        local order
        order=$(grep '^MODULE_ORDER=' "$f" | head -1 | cut -d= -f2)
        for existing in "${orders[@]}"; do
            if [ "$existing" = "$order" ]; then
                echo "Duplicate MODULE_ORDER=$order in $(basename "$f")" >&2
                return 1
            fi
        done
        orders+=("$order")
    done
}

@test "MODULE_ID values are unique" {
    local ids=()
    for f in "$MODULES_DIR"/*.sh; do
        local id
        id=$(grep '^MODULE_ID=' "$f" | head -1 | cut -d= -f2 | tr -d '"')
        for existing in "${ids[@]}"; do
            if [ "$existing" = "$id" ]; then
                echo "Duplicate MODULE_ID=$id in $(basename "$f")" >&2
                return 1
            fi
        done
        ids+=("$id")
    done
}
