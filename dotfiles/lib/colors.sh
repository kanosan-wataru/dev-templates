#!/usr/bin/env bash
# Color output helpers for setup scripts
# Replaces zsh print -P "%F{N}..." pattern with bash ANSI equivalents

# Initialize color variables (call once at script start)
# Respects NO_COLOR standard and TTY detection
_setup_colors() {
    if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
        C_RESET="" C_BOLD="" C_BOLD_OFF="" C_DIM=""
        C_RED="" C_GREEN="" C_YELLOW="" C_CYAN="" C_GRAY=""
    else
        C_RESET=$'\e[0m'
        C_BOLD=$'\e[1m'
        C_BOLD_OFF=$'\e[22m'
        C_DIM=$'\e[2m'
        # Match zsh %F{N} color numbers
        C_RED=$'\e[38;5;160m'    # %F{160}
        C_GREEN=$'\e[38;5;34m'   # %F{34}
        C_YELLOW=$'\e[38;5;220m' # %F{220}
        C_CYAN=$'\e[38;5;36m'    # %F{36}
        C_GRAY=$'\e[38;5;242m'   # %F{242}
    fi
}

# Message helpers
msg_error() { printf '%s%sエラー: %s%s\n' "${C_RED}" "${C_BOLD}" "$1" "${C_RESET}" >&2; }
msg_warn() { printf '%s警告: %s%s\n' "${C_YELLOW}" "$1" "${C_RESET}"; }
msg_info() { printf '情報: %s\n' "$1"; }
msg_success() { printf '%s%s%s\n' "${C_GREEN}" "$1" "${C_RESET}"; }
msg_header() { printf '\n%s%s[%s]%s\n' "${C_CYAN}" "${C_BOLD}" "$1" "${C_RESET}"; }
msg_dry_run() { printf '%s  [DRY-RUN] %s%s\n' "${C_GRAY}" "$1" "${C_RESET}"; }
msg_step() { printf '  %s\n' "$1"; }

# Formatted output (for custom color needs)
# Usage: color_print "$C_RED" "text"
color_print() {
    local color="$1" text="$2"
    printf '%s%s%s\n' "$color" "$text" "${C_RESET}"
}

# Print separator line
print_separator() {
    printf '%s\n' "---------------------------------------------"
}
