#!/usr/bin/env bash
# TUI checkbox menu for module selection
# Replaces zsh checkbox_menu() with bash-compatible implementation
#
# Dependencies: lib/colors.sh (_setup_colors, $C_CYAN, $C_BOLD, etc.)
#
# Usage:
#   checkbox_menu "Select modules:" "Name1|Desc1|1" "Name2|Desc2|0" ...
#   echo "$REPLY"  # => "0 2" (space-separated 0-based indices)

# Guard: only source colors.sh if _setup_colors is not yet defined
if ! declare -f _setup_colors >/dev/null 2>&1; then
    _TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=./colors.sh
    source "${_TUI_DIR}/colors.sh"
    _setup_colors
fi

# --- Internal state (module-level) ---
# These are set by checkbox_menu and used by _cb_draw / _cb_cleanup.
declare -a _CB_LABELS=()
declare -a _CB_DESCS=()
declare -a _CB_SELECTED=()
declare -i _CB_COUNT=0
declare -i _CB_CURSOR=0
declare -i _CB_HEADER_LINES=2
declare -i _CB_TOTAL_LINES=0

# Cleanup handler: restore terminal state on interrupt/exit
_cb_cleanup() {
    # Show cursor
    printf '\e[?25h'
    # Reset all attributes
    printf '\e[0m'
    printf '\n'
    exit 130
}

# Prompt text stored for _cb_draw
declare _CB_PROMPT=""

# Draw the menu (internal)
# Arguments: $1 = 1 if redrawing (move cursor up first)
_cb_draw() {
    local redraw="${1:-0}"
    local max_width="${COLUMNS:-80}"

    # On redraw, move cursor up to start of menu
    if ((redraw)); then
        printf '\e[%dA' "$_CB_TOTAL_LINES"
    fi

    # Header
    printf '\e[2K' # Clear line
    printf '%s%s %s %s\n' \
        "${C_CYAN}" "${C_BOLD}" "$_CB_PROMPT" "${C_RESET}"
    printf '\e[2K' # Clear line
    printf '%s (up/down:move  Space:toggle  a:all  n:none  Enter:confirm  q:cancel)%s\n' \
        "${C_GRAY}" "${C_RESET}"

    # Menu items
    local i
    for ((i = 0; i < _CB_COUNT; i++)); do
        printf '\e[2K' # Clear line

        local prefix="  "
        local check="[ ]"

        if ((_CB_SELECTED[i])); then
            check="[x]"
        fi

        if ((i == _CB_CURSOR)); then
            prefix="> "
        fi

        # Build display line
        local label="${_CB_LABELS[$i]}"
        local desc="${_CB_DESCS[$i]}"

        # Pad label to fixed width for alignment
        local label_width=20
        local padded_label
        padded_label=$(printf '%-*s' "$label_width" "$label")

        local line="${prefix}${check} ${padded_label} ${desc}"

        # Truncate to terminal width
        if ((${#line} > max_width - 1)); then
            line="${line:0:$((max_width - 2))}"
        fi

        if ((i == _CB_CURSOR)); then
            # Reverse video (highlighted)
            printf '\e[7m%s\e[0m\n' "$line"
        else
            printf '%s\n' "$line"
        fi
    done
}

# Checkbox menu: display interactive selection UI
#
# Arguments:
#   $1        - prompt text displayed in the header line
#   $2..$N    - menu items in "name|description|default(0/1)" format
#
# Sets:
#   REPLY     - space-separated list of selected indices (0-based)
#
# Returns:
#   0 = confirmed (Enter)
#   1 = cancelled (q)
checkbox_menu() {
    if [[ $# -lt 2 ]]; then
        msg_error "checkbox_menu: 引数が不足しています (プロンプト + 1つ以上の項目が必要)"
        return 1
    fi

    _CB_PROMPT="$1"
    shift

    # Parse items
    _CB_COUNT=$#
    _CB_LABELS=()
    _CB_DESCS=()
    _CB_SELECTED=()
    _CB_CURSOR=0
    _CB_HEADER_LINES=2
    _CB_TOTAL_LINES=$((_CB_HEADER_LINES + _CB_COUNT))

    local item label desc default_val i
    for item in "$@"; do
        # Split by pipe delimiter
        IFS='|' read -r label desc default_val <<<"$item"

        _CB_LABELS+=("$label")
        _CB_DESCS+=("$desc")
        _CB_SELECTED+=("${default_val:-0}")
    done

    # Set up signal handlers for clean exit
    trap '_cb_cleanup' INT TERM QUIT

    # Hide cursor
    printf '\e[?25h' # Ensure visible first (reset state)
    printf '\e[?25l' # Then hide

    # Reserve vertical space by printing blank lines, then move back up
    local j
    for ((j = 0; j < _CB_TOTAL_LINES; j++)); do
        printf '\n'
    done
    printf '\e[%dA' "$_CB_TOTAL_LINES"

    # Initial draw
    _cb_draw 0

    # Input loop
    local key
    while true; do
        # Read single character (silent, raw)
        IFS= read -rsn1 key || {
            _cb_cleanup
            return 1
        }

        case "$key" in
        $'\e')
            # Escape sequence: read remaining bytes for arrow keys
            local key2="" key3=""
            IFS= read -rsn1 -t 0.1 key2 2>/dev/null || true
            if [[ "$key2" == "[" || "$key2" == "O" ]]; then
                IFS= read -rsn1 -t 0.1 key3 2>/dev/null || true
                case "$key3" in
                A) # Up arrow
                    if ((_CB_CURSOR > 0)); then _CB_CURSOR=$((_CB_CURSOR - 1)); fi
                    ;;
                B) # Down arrow
                    if ((_CB_CURSOR < _CB_COUNT - 1)); then _CB_CURSOR=$((_CB_CURSOR + 1)); fi
                    ;;
                esac
            fi
            ;;
        k) # vim: up
            if ((_CB_CURSOR > 0)); then _CB_CURSOR=$((_CB_CURSOR - 1)); fi
            ;;
        j) # vim: down
            if ((_CB_CURSOR < _CB_COUNT - 1)); then _CB_CURSOR=$((_CB_CURSOR + 1)); fi
            ;;
        ' ') # Space: toggle selection
            if ((_CB_SELECTED[_CB_CURSOR])); then
                _CB_SELECTED[_CB_CURSOR]=0
            else
                _CB_SELECTED[_CB_CURSOR]=1
            fi
            ;;
        a) # Select all
            for ((i = 0; i < _CB_COUNT; i++)); do
                _CB_SELECTED[i]=1
            done
            ;;
        n) # Deselect all
            for ((i = 0; i < _CB_COUNT; i++)); do
                _CB_SELECTED[i]=0
            done
            ;;
        q)                   # Cancel
            printf '\e[?25h' # Show cursor
            trap - INT TERM QUIT
            return 1
            ;;
        '') # Enter key (read -n1 returns empty string for newline)
            break
            ;;
        esac

        # Redraw
        _cb_draw 1
    done

    # Restore terminal state
    printf '\e[?25h' # Show cursor
    trap - INT TERM QUIT

    # Build result: space-separated list of selected 0-based indices
    REPLY=""
    for ((i = 0; i < _CB_COUNT; i++)); do
        if ((_CB_SELECTED[i])); then
            if [[ -n "$REPLY" ]]; then
                REPLY+=" "
            fi
            REPLY+="$i"
        fi
    done

    return 0
}
