#!/usr/bin/env bash
# Shared test helper functions extracted from setup.sh
#
# NOTE: We cannot source setup.sh directly because it runs load_modules
# and other side effects. Instead, the key functions are defined here
# as simplified versions for testing.
#
# NOTE: install_config below is a simplified version of setup.sh (lines ~117-213)
# for testing. The interactive diff prompt ([y/N/d]) and cp failure recovery
# hints are omitted.
# If the production install_config changes, review and update this test version
# accordingly.

# Source this file in BATS setup() after sourcing lib/*.sh and setting flags.
# Required variables: DOTFILES_DIR, DRY_RUN, FORCE, BACKUP_SUFFIX

# run_cmd: dry-run aware command wrapper
run_cmd() {
    if ((DRY_RUN)); then
        msg_dry_run "$(printf '%q ' "$@")"
    else
        "$@"
    fi
}

# install_config: config file backup and deployment helper
# $5=quiet (0|1, default 0) — install_tree 経由のときだけ per-file info を抑制
install_config() {
    local src="$1" dst="$2" label="$3" missing_hint="${4:-}" quiet="${5:-0}"

    if [[ ! -f "$src" ]]; then
        if [[ -n "$missing_hint" ]]; then
            msg_warn "${label} が見つかりません。${missing_hint}"
        else
            msg_error "配布元の ${label} が見つかりません: ${src}"
            exit 1
        fi
        return 0
    fi

    if [[ -f "$dst" && ! -L "$dst" ]] && cmp -s "$src" "$dst"; then
        ((quiet)) || msg_info "${label} は既に最新の状態です。スキップします。"
        return 0
    fi

    if [[ -f "$dst" || -L "$dst" ]]; then
        if ((DRY_RUN)); then
            ((quiet)) || msg_dry_run "${label} を更新予定です。"
            return 0
        fi

        if ! ((FORCE)); then
            # In test context, interactive prompt is not reachable.
            # Tests that hit this path would hang, so we only test
            # FORCE mode and DRY_RUN mode for the "differs" scenario.
            ((quiet)) || msg_info "スキップしました: ${label}"
            return 0
        fi

        run_cmd command mv "$dst" "${dst}${BACKUP_SUFFIX}" || {
            msg_error "${label} のバックアップに失敗しました。"
            exit 1
        }
        ((quiet)) || msg_info "既存の ${label} を ${dst}${BACKUP_SUFFIX} にバックアップしました。"
    fi

    run_cmd command cp -p "$src" "$dst" || {
        msg_error "${label} の配置に失敗しました。"
        exit 1
    }
    ((quiet)) || msg_info "${label} を配置しました。"
}

# install_source_config: deploy config via source separation
install_source_config() {
    local src="$1"
    local user_file="$2"
    local deploy_dir="$3"
    local deploy_name="$4"
    local label="$5"

    if [[ ! -d "$deploy_dir" ]]; then
        run_cmd command mkdir -p -m 700 "$deploy_dir" || {
            msg_error "${deploy_dir} の作成に失敗しました。"
            return 1
        }
    fi
    install_config "$src" "${deploy_dir}/${deploy_name}" "$label"

    local source_line="source \"${deploy_dir}/${deploy_name}\""

    if [[ -f "$user_file" ]] && grep -qF "$source_line" "$user_file" 2>/dev/null; then
        msg_info "${label}: source 行は $(basename "$user_file") に設定済みです。"
        return 0
    fi

    if ((DRY_RUN)); then
        msg_dry_run "$(basename "$user_file") に source 行を追加予定です。"
        return 0
    fi

    {
        printf '\n'
        printf '# dev-templates managed - do not remove\n'
        printf '%s\n' "$source_line"
    } >>"$user_file"
    msg_success "$(basename "$user_file") に source 行を追加しました。"
}
