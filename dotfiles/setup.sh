#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------
# Development environment setup script
#
# Usage:
#   bash setup.sh                  Interactive mode (module selection)
#   bash setup.sh --all            Install all modules at once
#   bash setup.sh --select zsh     Specify modules (multiple allowed)
#   bash setup.sh --dry-run        Preview changes only
#   bash setup.sh --force          Skip diff confirmation (backup + overwrite)
#   bash setup.sh --upgrade         Upgrade installed tools to latest
#   bash setup.sh --uninstall      Restore from backups
#   bash setup.sh --status         Show installation status of all modules
#   bash setup.sh zsh git docker   Specify modules as positional args
#   bash setup.sh --help           Show help
#
# Modules are dynamically loaded from the modules/ directory.
# To add new modules, refer to existing files in modules/.
# ---------------------------------------------

# --- Script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Source helper libraries ---
# shellcheck source=./lib/colors.sh
source "${SCRIPT_DIR}/lib/colors.sh"
# shellcheck source=./lib/array.sh
source "${SCRIPT_DIR}/lib/array.sh"
# shellcheck source=./lib/backup.sh
source "${SCRIPT_DIR}/lib/backup.sh"
# shellcheck source=./lib/tui.sh
source "${SCRIPT_DIR}/lib/tui.sh"
# shellcheck source=./lib/install_tree.sh
source "${SCRIPT_DIR}/lib/install_tree.sh"
_setup_colors

# ==============================================
# Argument parsing
# ==============================================
DRY_RUN=0
UNINSTALL=0
ALL_FLAG=0
HELP_FLAG=0
STATUS_FLAG=0
FORCE=0
UPGRADE=0
declare -a SELECT_MODULES=()
declare -A MODULE_DEPS_MAP=()
declare -A MODULE_ID_SET=()

while (($# > 0)); do
    case "$1" in
    --dry-run)
        DRY_RUN=1
        ;;
    --uninstall)
        UNINSTALL=1
        ;;
    --force | -f)
        FORCE=1
        ;;
    --all)
        ALL_FLAG=1
        ;;
    --select)
        if (($# < 2)); then
            msg_error "--select にはモジュール名が必要です"
            exit 1
        fi
        shift
        SELECT_MODULES+=("$1")
        ;;
    --upgrade)
        UPGRADE=1
        ;;
    --status)
        STATUS_FLAG=1
        ;;
    --help | -h)
        HELP_FLAG=1
        ;;
    *)
        # Positional args: treat as module names if not prefixed with -
        if [[ "$1" == -* ]]; then
            msg_error "不明なオプション: $1"
            printf '  ヘルプ: bash %s --help\n' "$0" >&2
            exit 1
        fi
        SELECT_MODULES+=("$1")
        ;;
    esac
    shift
done

# --- Mutual exclusion checks ---
if ((UPGRADE)) && ((UNINSTALL)); then
    msg_error "--upgrade と --uninstall は同時に指定できません"
    exit 1
fi

if ((UNINSTALL)) && ((${#SELECT_MODULES[@]} > 0)); then
    msg_error "--uninstall はモジュール指定と併用できません（全モジュールが対象です）"
    exit 1
fi

# ==============================================
# Common variables
# ==============================================
BACKUP_SUFFIX=".backup.$(command date +%Y%m%d%H%M%S)"

# ==============================================
# Helper functions
# ==============================================

# Dry-run aware command wrapper
# When DRY_RUN=1, print the command instead of executing it
run_cmd() {
    if ((DRY_RUN)); then
        msg_dry_run "$(printf '%q ' "$@")"
    else
        "$@"
    fi
}

# Config file backup and deployment helper (idempotent)
# Args: $1=source path $2=destination path $3=display name $4=hint when missing
#
# Behavior:
#   - If destination does not exist: deploy without asking (new file)
#   - If destination exists and is identical: skip (idempotent)
#   - If destination exists and differs:
#       --force:   backup + overwrite without confirmation
#       --dry-run: show preview message only
#       otherwise: show diff and ask user for confirmation
install_config() {
    local src="$1" dst="$2" label="$3" missing_hint="${4:-}"

    # Warn if source file does not exist
    if [[ ! -f "$src" ]]; then
        if [[ -n "$missing_hint" ]]; then
            msg_warn "${label} が見つかりません。${missing_hint}"
        else
            msg_error "配布元の ${label} が見つかりません: ${src}"
            exit 1
        fi
        return 0
    fi

    # Idempotency check: skip if not a symlink and content is identical
    if [[ -f "$dst" && ! -L "$dst" ]] && cmp -s "$src" "$dst"; then
        msg_info "${label} は既に最新の状態です。スキップします。"
        return 0
    fi

    # Interactive diff preview when destination exists and differs
    if [[ -f "$dst" || -L "$dst" ]]; then
        if ((DRY_RUN)); then
            # Dry-run: show what would happen, then return
            msg_dry_run "${label} を更新予定です。"
            return 0
        fi

        if ! ((FORCE)); then
            # Show compact diff preview
            printf '\n'
            msg_warn "${label} に差分があります:"
            diff -u "$dst" "$src" | head -40 || true
            printf '\n'

            # Ask user for confirmation
            local answer=""
            while true; do
                printf '上書きしますか？ %s [y/N/d] (y=はい, N=いいえ, d=全文表示): ' "$label"
                read -r answer </dev/tty
                case "$answer" in
                [yY])
                    break
                    ;;
                [dD])
                    # Show full diff
                    printf '\n'
                    diff -u "$dst" "$src" || true
                    printf '\n'
                    # Ask again after showing full diff
                    ;;
                *)
                    # Empty or 'n' or 'N' -- skip
                    msg_info "スキップしました: ${label}"
                    return 0
                    ;;
                esac
            done
        fi

        # Backup existing file or symlink
        run_cmd command mv "$dst" "${dst}${BACKUP_SUFFIX}" || {
            msg_error "${label} のバックアップに失敗しました。"
            exit 1
        }
        msg_info "既存の ${label} を ${dst}${BACKUP_SUFFIX} にバックアップしました。"
    fi

    # Deploy file
    run_cmd command cp -p "$src" "$dst" || {
        msg_error "${label} の配置に失敗しました。"
        if [[ -f "${dst}${BACKUP_SUFFIX}" ]]; then
            printf '  バックアップは %s に保存されています。\n' "${dst}${BACKUP_SUFFIX}" >&2
            printf '  手動で復元するには: mv '\''%s'\'' '\''%s'\''\n' "${dst}${BACKUP_SUFFIX}" "$dst" >&2
        fi
        exit 1
    }
    msg_info "${label} を配置しました。"
}

# Deploy config via source separation
# Instead of overwriting the user's dotfile, deploy the template to a
# subdirectory and insert a one-line `source` into the user's file.
# This preserves user customizations while keeping template updates clean.
# Args: $1=source path $2=user's dotfile $3=deploy directory
#       $4=deploy filename $5=display label
install_source_config() {
    local src="$1"
    local user_file="$2"
    local deploy_dir="$3"
    local deploy_name="$4"
    local label="$5"

    # Deploy the template to the separate directory
    if [[ ! -d "$deploy_dir" ]]; then
        run_cmd command mkdir -p -m 700 "$deploy_dir" || {
            msg_error "${deploy_dir} の作成に失敗しました。"
            return 1
        }
    fi
    install_config "$src" "${deploy_dir}/${deploy_name}" "$label"

    # Source line to insert into the user's dotfile
    local source_line="source \"${deploy_dir}/${deploy_name}\""

    # Check if source line already exists
    if [[ -f "$user_file" ]] && grep -qF "$source_line" "$user_file" 2>/dev/null; then
        msg_info "${label}: source 行は $(basename "$user_file") に設定済みです。"
        return 0
    fi

    if ((DRY_RUN)); then
        msg_dry_run "$(basename "$user_file") に source 行を追加予定です。"
        return 0
    fi

    # Append source line to user's dotfile (create if needed)
    {
        printf '\n'
        printf '# dev-templates managed - do not remove\n'
        printf '%s\n' "$source_line"
    } >>"$user_file"
    msg_success "$(basename "$user_file") に source 行を追加しました。"
}

# Verify Node.js and npm availability
# Args: $1=minimum major version (default: 18)
# Returns: 0=available, 1=unavailable
ensure_node() {
    local min_version="${1:-18}"

    if ! command -v node >/dev/null 2>&1; then
        msg_error "Node.js がインストールされていません。"
        printf '  nvm, fnm, volta 等で Node.js v%s 以上をインストールしてください。\n' "$min_version" >&2
        printf '  例: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash\n' >&2
        return 1
    fi

    local node_ver
    node_ver=$(node -v | sed 's/^v//' | cut -d. -f1)

    # Validate numeric values
    if [[ ! "$min_version" =~ ^[0-9]+$ ]]; then
        msg_error "ensure_node に不正な引数が渡されました: ${min_version}"
        return 1
    fi
    if [[ ! "$node_ver" =~ ^[0-9]+$ ]]; then
        msg_error "Node.js のバージョンを取得できませんでした。"
        return 1
    fi

    if ((node_ver < min_version)); then
        msg_error "Node.js v${min_version} 以上が必要です（現在: v${node_ver}）"
        printf '  Node.js をアップグレードしてください。\n' >&2
        return 1
    fi

    if ! command -v npm >/dev/null 2>&1; then
        msg_error "npm がインストールされていません。"
        printf '  Node.js に付属の npm が利用可能か確認してください。\n' >&2
        return 1
    fi

    return 0
}

# ==============================================
# Dynamic module loading
# ==============================================

# Load module files from modules/ directory,
# building the MODULES array and setup_*/uninstall_* functions dynamically
load_modules() {
    local modules_dir="$SCRIPT_DIR/modules"

    if [[ ! -d "$modules_dir" ]]; then
        msg_error "modules/ ディレクトリが見つかりません: ${modules_dir}"
        exit 1
    fi

    declare -a _unsorted=()
    local module_file

    # NOTE: Use glob + nullglob-style check instead of zsh (N) qualifier
    for module_file in "$modules_dir"/*.sh; do
        # Skip if glob did not match anything (no nullglob in bash)
        [[ -e "$module_file" ]] || continue

        # Reset metadata variables
        local MODULE_ID="" MODULE_NAME="" MODULE_DESC="" MODULE_DEFAULT=0 MODULE_ORDER=50 MODULE_DEPS=""

        # Source the module file
        # shellcheck disable=SC1090
        if ! source "$module_file"; then
            local basename_file
            basename_file="$(basename "$module_file")"
            msg_warn "${basename_file} の読み込みに失敗しました（構文エラーの可能性）。スキップします。"
            continue
        fi

        # Validation: check required metadata
        if [[ -z "$MODULE_ID" || -z "$MODULE_NAME" ]]; then
            local basename_file
            basename_file="$(basename "$module_file")"
            msg_warn "${basename_file} のメタデータが不正です。スキップします。"
            continue
        fi

        # Check that setup_<safe_id> function is defined
        local safe_id="${MODULE_ID//-/_}"

        if ! declare -f "setup_${safe_id}" >/dev/null 2>&1; then
            local basename_file
            basename_file="$(basename "$module_file")"
            msg_warn "${basename_file} に setup_${safe_id} が定義されていません。スキップします。"
            continue
        fi

        # Save dependency mapping
        MODULE_DEPS_MAP[$MODULE_ID]="$MODULE_DEPS"
        MODULE_ID_SET[$MODULE_ID]=1

        # Store with ORDER prefix for sorting later
        _unsorted+=("$(printf '%03d' "$MODULE_ORDER")|${MODULE_ID}|${MODULE_NAME}|${MODULE_DESC}|${MODULE_DEFAULT}")
    done

    if ((${#_unsorted[@]} == 0)); then
        msg_error "有効なモジュールが見つかりません。"
        exit 1
    fi

    # Sort by MODULE_ORDER and build MODULES array
    MODULES=()
    readarray -t _sorted < <(printf '%s\n' "${_unsorted[@]}" | sort)
    local entry
    for entry in "${_sorted[@]}"; do
        # Remove ORDER prefix ("NNN|")
        MODULES+=("${entry#*|}")
    done
}

# Load modules
load_modules

# ==============================================
# Status display (show installation status of all modules)
# ==============================================
if ((STATUS_FLAG)); then
    printf '\n'
    printf '  %-14s %-18s %s\n' "Module" "Status" "Version"
    printf '  %-14s %-18s %s\n' "──────────────" "──────────────────" "─────────────────────"

    # Build ID -> file mapping once (O(n) instead of O(n^2) grep per module)
    declare -A _status_file_map=()
    for mod_file in "${SCRIPT_DIR}"/modules/*.sh; do
        [[ -e "$mod_file" ]] || continue
        _mod_id="$(
            MODULE_ID=""
            # shellcheck disable=SC1090
            source "$mod_file"
            printf '%s' "${MODULE_ID:-}"
        )"
        [[ -n "$_mod_id" ]] || continue
        _status_file_map["$_mod_id"]="$mod_file"
    done

    for entry in "${MODULES[@]}"; do
        IFS='|' read -r mod_id _rest <<<"$entry"
        mod_file="${_status_file_map[$mod_id]-}"
        if [[ -z "$mod_file" ]]; then
            printf '  %-14s %-18s %s\n' "$mod_id" "? unknown" "-"
            continue
        fi
        (
            MODULE_ID="" MODULE_NAME="" MODULE_DESC="" MODULE_DEFAULT=0 MODULE_ORDER=50 MODULE_DEPS=""
            # shellcheck disable=SC1090
            source "$mod_file"
            if declare -f module_status >/dev/null 2>&1; then
                module_status
            else
                printf '  %-14s %-18s %s\n' "$mod_id" "? unknown" "-"
            fi
        )
    done

    printf '\n'
    exit 0
fi

# ==============================================
# Help display (dynamically generated after module loading)
# ==============================================
if ((HELP_FLAG)); then
    printf '使用法: bash %s [MODULE ...] [オプション]\n' "$0"
    printf '\n'
    printf 'オプション:\n'
    printf '  --dry-run          変更内容のプレビューのみ（実際には変更しない）\n'
    printf '  --force, -f        差分確認をスキップ（バックアップ＋上書き）\n'
    printf '  --upgrade          インストール済みツールを最新バージョンに更新\n'
    printf '  --uninstall        全モジュールをアンインストール（バックアップから復元）\n'
    printf '  --all              全モジュールを一括インストール\n'
    printf '  --select MODULE    特定モジュールを指定（複数指定可）\n'
    printf '  --status           各モジュールのインストール状態を表示\n'
    printf '  --help, -h         このヘルプを表示\n'
    printf '\n'
    printf '位置引数:\n'
    printf '  MODULE ...         インストールするモジュールを直接指定（--select の短縮形）\n'
    printf '\n'
    printf 'モジュール:\n'
    for entry in "${MODULES[@]}"; do
        IFS='|' read -r mod_id mod_name mod_desc _mod_default <<<"$entry"
        printf '  %-14s %s (%s)\n' "$mod_id" "$mod_name" "$mod_desc"
    done
    printf '\n'
    printf '例:\n'
    printf '  bash %s                              インタラクティブ選択\n' "$0"
    printf '  bash %s --all                        全モジュール一括\n' "$0"
    printf '  bash %s zsh claude-code                  位置引数で複数指定\n' "$0"
    printf '  bash %s --select zsh --select claude-code  --select で複数指定\n' "$0"
    printf '  bash %s --all --dry-run              全モジュールをプレビュー\n' "$0"
    exit 0
fi

# ==============================================
# --select validation (verified after module loading)
# ==============================================
for mod_id in "${SELECT_MODULES[@]}"; do
    local_found=0
    for entry in "${MODULES[@]}"; do
        IFS='|' read -r entry_id _rest <<<"$entry"
        if [[ "$entry_id" == "$mod_id" ]]; then
            local_found=1
            break
        fi
    done
    if ((!local_found)); then
        msg_error "不明なモジュール: ${mod_id}"
        printf '利用可能なモジュール:\n' >&2
        for entry in "${MODULES[@]}"; do
            IFS='|' read -r entry_id _rest <<<"$entry"
            printf '  %s\n' "$entry_id" >&2
        done
        exit 1
    fi
done

# ==============================================
# Module execution dispatch
# ==============================================

# Dynamically execute setup function for a module ID
run_module_setup() {
    local module_id="$1"
    local func_name="setup_${module_id//-/_}"
    if declare -f "$func_name" >/dev/null 2>&1; then
        "$func_name"
    else
        msg_error "不明なモジュール: ${module_id}"
        return 1
    fi
}

# Dynamically execute uninstall function for a module ID
# NOTE: Modules without uninstall_<safe_id> are silently skipped
run_module_uninstall() {
    local module_id="$1"
    local func_name="uninstall_${module_id//-/_}"
    if declare -f "$func_name" >/dev/null 2>&1; then
        "$func_name"
    else
        msg_info "${module_id} にはアンインストール処理が定義されていません。スキップします。"
        return 0
    fi
}

# Resolve module dependencies and auto-add missing dependency modules
# Modifies: selected_module_ids (adds missing dependencies)
resolve_module_deps() {
    local -a added_deps=()
    local changed=1

    # Iterate until no more transitive dependencies are found
    while ((changed)); do
        changed=0
        for mod_id in "${selected_module_ids[@]}"; do
            local deps="${MODULE_DEPS_MAP[$mod_id]:-}"
            [[ -z "$deps" ]] && continue

            # MODULE_DEPS is a space-separated list
            read -ra _deps <<<"$deps"
            local dep
            for dep in "${_deps[@]}"; do
                # Check if dep is already selected
                if ! array_contains "$dep" "${selected_module_ids[@]}"; then
                    # O(1) existence check
                    if [[ -n "${MODULE_ID_SET[$dep]:-}" ]]; then
                        selected_module_ids+=("$dep")
                        added_deps+=("$dep")
                        changed=1
                    else
                        msg_warn "モジュール '${mod_id}' の依存先 '${dep}' が見つかりません。"
                    fi
                fi
            done
        done
    done

    # Notify user of auto-added dependencies
    if ((${#added_deps[@]} > 0)); then
        printf '\n'
        color_print "$C_CYAN" "依存関係の自動解決:"
        for dep in "${added_deps[@]}"; do
            printf '  + %s (依存先として自動追加)\n' "$dep"
        done
        printf '\n'
    fi

    # Re-sort by MODULE_ORDER so dependencies are installed first
    if ((${#added_deps[@]} > 0)); then
        local -a sorted_ids=()
        local entry entry_id
        for entry in "${MODULES[@]}"; do
            entry_id="${entry%%|*}"
            if array_contains "$entry_id" "${selected_module_ids[@]}"; then
                sorted_ids+=("$entry_id")
            fi
        done
        selected_module_ids=("${sorted_ids[@]}")
    fi
}

# ==============================================
# Uninstall mode
# NOTE: --uninstall always targets all modules
# ==============================================
if ((UNINSTALL)); then
    printf '%s\n' "全モジュールのアンインストール（復元）を開始します..."
    printf '%s\n' "============================================="

    if ((DRY_RUN)); then
        color_print "${C_CYAN}" "[DRY-RUN モード] 実際には変更を行いません。"
        print_separator
    fi

    declare -i uninstall_errors=0

    # NOTE: Uninstall in reverse MODULE_ORDER (descending) order
    readarray -t _reversed < <(printf '%s\n' "${MODULES[@]}" | tac)
    for entry in "${_reversed[@]}"; do
        IFS='|' read -r mod_id mod_name _rest <<<"$entry"
        printf '\n'
        printf '%s%s[%s]%s\n' "${C_CYAN}" "${C_BOLD}" "$mod_name" "${C_RESET}"
        print_separator
        if ! run_module_uninstall "$mod_id"; then
            ((uninstall_errors++)) || true
        fi
    done

    printf '\n'
    printf '%s\n' "============================================="
    if ((uninstall_errors > 0)); then
        color_print "$C_YELLOW" "アンインストールが完了しましたが、${uninstall_errors} 件のモジュールでエラーが発生しました。"
        printf '%s\n' "============================================="
        exit 1
    else
        msg_success "アンインストールが完了しました。"
        printf '%s\n' "============================================="
        exit 0
    fi
fi

# ==============================================
# Normal setup mode
# ==============================================
printf '\n'
printf '%s%s 開発環境セットアップ%s\n' "${C_CYAN}" "${C_BOLD}" "${C_RESET}"
printf '%s\n' "============================================="

if ((DRY_RUN)); then
    color_print "${C_CYAN}" "[DRY-RUN モード] 実際には変更を行いません。"
    print_separator
fi

printf '情報: Bash で実行されています (バージョン: %s)\n' "$BASH_VERSION"
print_separator

# --- Module selection ---
declare -a selected_module_ids=()

if ((${#SELECT_MODULES[@]} > 0)); then
    # Explicit --select: reorder to MODULE_ORDER
    for entry in "${MODULES[@]}"; do
        IFS='|' read -r mod_id _rest <<<"$entry"
        if array_contains "$mod_id" "${SELECT_MODULES[@]}"; then
            selected_module_ids+=("$mod_id")
        fi
    done
    resolve_module_deps

elif ((ALL_FLAG)); then
    # --all: select all modules
    for entry in "${MODULES[@]}"; do
        IFS='|' read -r mod_id _rest <<<"$entry"
        selected_module_ids+=("$mod_id")
    done

elif [[ -t 0 ]]; then
    # TTY environment: interactive selection (checkbox UI)
    printf '\n'

    if ! command -v tput >/dev/null 2>&1; then
        # tput unavailable: install only default-selected modules
        msg_warn "tput が利用できないため、デフォルトのモジュールをインストールします。"
        for entry in "${MODULES[@]}"; do
            IFS='|' read -r mod_id _mod_name _mod_desc mod_default <<<"$entry"
            if ((mod_default == 1)); then
                selected_module_ids+=("$mod_id")
            fi
        done
    else
        # Build menu items for checkbox menu
        declare -a menu_items=()
        for entry in "${MODULES[@]}"; do
            IFS='|' read -r _mod_id mod_name mod_desc mod_default <<<"$entry"
            menu_items+=("${mod_name}|${mod_desc}|${mod_default}")
        done

        # Display checkbox menu (lib/tui.sh version)
        # NOTE: Use "|| true" to prevent set -e from exiting on cancel (return 1)
        checkbox_menu "インストールするモジュールを選択してください:" "${menu_items[@]}" || menu_status=$?
        menu_status="${menu_status:-0}"
        selection="$REPLY"

        if ((menu_status != 0)); then
            printf '\n'
            msg_warn "キャンセルされました。"
            exit 0
        fi

        if [[ -z "$selection" ]]; then
            printf '\n'
            msg_warn "モジュールが選択されませんでした。終了します。"
            exit 0
        fi

        # Convert 0-based selected indices to module IDs
        read -ra _selected_indices <<<"$selection"
        for idx in "${_selected_indices[@]}"; do
            IFS='|' read -r mod_id _rest <<<"${MODULES[$idx]}"
            selected_module_ids+=("$mod_id")
        done
    fi
    resolve_module_deps

    printf '\n'
else
    # Non-TTY environment (CI / pipe): equivalent to --all
    msg_info "非インタラクティブ環境を検出。全モジュールをインストールします。"
    for entry in "${MODULES[@]}"; do
        IFS='|' read -r mod_id _rest <<<"$entry"
        selected_module_ids+=("$mod_id")
    done
fi

# Display selected modules
printf '\n'
color_print "$C_CYAN" "選択されたモジュール:"
for mod_id in "${selected_module_ids[@]}"; do
    for entry in "${MODULES[@]}"; do
        IFS='|' read -r entry_id entry_name entry_desc _rest <<<"$entry"
        if [[ "$entry_id" == "$mod_id" ]]; then
            printf '  - %s (%s)\n' "$entry_name" "$entry_desc"
            break
        fi
    done
done
print_separator

# --- Execute selected module setups sequentially ---
declare -i setup_errors=0
for mod_id in "${selected_module_ids[@]}"; do
    if ! run_module_setup "$mod_id"; then
        ((setup_errors++)) || true
    fi
done

# --- Completion ---
printf '\n'
printf '%s\n' "============================================="
if ((DRY_RUN)); then
    color_print "${C_CYAN}" "[DRY-RUN] 上記が実行される変更内容です。実際に適用するには --dry-run を外して再実行してください。"
elif ((setup_errors > 0)); then
    color_print "$C_YELLOW" "セットアップが完了しましたが、${setup_errors} 件のモジュールでエラーが発生しました。"
else
    msg_success "セットアップが正常に完了しました。"

    # Show shell restart hint only if zsh module was selected
    for mod_id in "${selected_module_ids[@]}"; do
        if [[ "$mod_id" == "zsh" ]]; then
            printf '全ての変更を有効にするために、シェルを%s再起動%sするか '\''%sexec zsh%s'\'' を実行してください。\n' \
                "${C_BOLD}" "${C_BOLD_OFF}" "${C_BOLD}" "${C_BOLD_OFF}"
            printf '(source ~/.zshrc は環境が汚れる場合があるため、exec zsh を推奨します)\n'
            break
        fi
    done
fi
printf '%s\n' "============================================="

if ((setup_errors > 0)); then
    exit 1
fi
exit 0
