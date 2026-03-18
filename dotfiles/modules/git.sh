# ---------------------------------------------
# モジュール: Git グローバル設定
# .gitconfig.shared + .gitignore_global
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="git"
MODULE_NAME="Git グローバル設定"
MODULE_DESC=".gitconfig.shared + .gitignore_global"
MODULE_DEFAULT=0
MODULE_ORDER=12

# NOTE: モジュール固有の変数には衝突回避のため GIT_MOD_ プレフィックスを使用

GIT_MOD_BASE_DIR="$HOME"

# 管理対象ファイル（配布元パス, 配置先パス, 表示名, 未検出時メッセージ）
# NOTE: .gitconfig.shared は include.path 経由で読み込まれる（既存 .gitconfig を上書きしない）
GIT_MOD_MANAGED_FILES=(
    "$SCRIPT_DIR/.gitconfig.shared|$GIT_MOD_BASE_DIR/.gitconfig.shared|.gitconfig.shared|"
    "$SCRIPT_DIR/.gitignore_global|$GIT_MOD_BASE_DIR/.gitignore_global|.gitignore_global|"
)

# --- セットアップ ---
setup_git() {
    msg_header "Git グローバル設定"
    print_separator

    # git コマンドの存在確認
    if ! command -v git >/dev/null 2>&1; then
        msg_error "git コマンドが見つかりません。インストールしてください。"
        return 1
    fi
    msg_info "git が利用可能です ($(command git --version))"

    # 設定ファイルの配置
    msg_info "設定ファイルを配置します..."
    for entry in "${GIT_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r src dst label hint <<< "$entry"
        install_config "$src" "$dst" "$label" "$hint"
    done

    # include.path で共有設定をリンク
    _git_setup_include_path || return 1

    # core.excludesFile でグローバル gitignore を紐付け
    _git_setup_excludes_file || return 1

    if (( DRY_RUN )); then
        msg_info "Git グローバル設定をセットアップ予定です（dry-run）。"
    else
        msg_success "Git グローバル設定のセットアップが完了しました。"
    fi

    # user.name / user.email の設定ガイド
    _git_show_user_guide
}

# --- include.path の設定 ---
_git_setup_include_path() {
    local shared_path="$GIT_MOD_BASE_DIR/.gitconfig.shared"

    # 既に設定済みか確認
    if git config --global --get-all include.path 2>/dev/null | grep -qF "$shared_path"; then
        msg_info "include.path は既に設定されています。スキップします。"
        return 0
    fi

    if (( DRY_RUN )); then
        msg_dry_run "git config --global --add include.path ${shared_path}"
    else
        git config --global --add include.path "$shared_path" || {
            msg_error "include.path の設定に失敗しました。"
            return 1
        }
        msg_info "include.path に ${shared_path} を追加しました。"
    fi
}

# --- core.excludesFile の設定 ---
_git_setup_excludes_file() {
    local excludes_path="$GIT_MOD_BASE_DIR/.gitignore_global"

    # 既に設定済みか確認
    local current_excludes
    current_excludes=$(git config --global core.excludesFile 2>/dev/null || true)
    if [[ "$current_excludes" == "$excludes_path" ]]; then
        msg_info "core.excludesFile は既に設定されています。スキップします。"
        return 0
    fi

    if (( DRY_RUN )); then
        if [[ -n "$current_excludes" && "$current_excludes" != "$excludes_path" ]]; then
            msg_warn "core.excludesFile が ${current_excludes} から ${excludes_path} に変更されます。"
        fi
        msg_dry_run "git config --global core.excludesFile ${excludes_path}"
    else
        git config --global core.excludesFile "$excludes_path" || {
            msg_error "core.excludesFile の設定に失敗しました。"
            return 1
        }
        if [[ -n "$current_excludes" && "$current_excludes" != "$excludes_path" ]]; then
            msg_warn "core.excludesFile を ${current_excludes} から ${excludes_path} に変更しました。"
        else
            msg_info "core.excludesFile に ${excludes_path} を設定しました。"
        fi
    fi
}

# --- user.name / user.email のガイド表示 ---
_git_show_user_guide() {
    local user_name user_email
    user_name=$(git config --global user.name 2>/dev/null || true)
    user_email=$(git config --global user.email 2>/dev/null || true)

    if [[ -n "$user_name" && -n "$user_email" ]]; then
        printf '\n'
        msg_info "Git ユーザー設定は既に構成されています。"
        msg_step "user.name:  ${user_name}"
        msg_step "user.email: ${user_email}"
    else
        printf '\n'
        msg_warn "NOTE: Git のユーザー情報が未設定です。以下を実行してください:"
        if [[ -z "$user_name" ]]; then
            msg_step "git config --global user.name \"Your Name\""
        fi
        if [[ -z "$user_email" ]]; then
            msg_step "git config --global user.email \"your@email.com\""
        fi
    fi
}

# --- アンインストール ---
uninstall_git() {
    local restored=0

    # git config の解除（git が利用可能な場合のみ）
    if command -v git >/dev/null 2>&1; then
        # include.path のリンク解除
        local shared_path="$GIT_MOD_BASE_DIR/.gitconfig.shared"
        if git config --global --get-all include.path 2>/dev/null | grep -qF "$shared_path"; then
            if (( DRY_RUN )); then
                msg_dry_run "git config --global --fixed-value --unset-all include.path ${shared_path}"
            else
                if git config --global --fixed-value --unset-all include.path "$shared_path" 2>/dev/null; then
                    msg_info "include.path から ${shared_path} を削除しました。"
                else
                    msg_warn "include.path の解除に失敗しました。手動で確認してください:"
                    msg_step "git config --global --edit"
                fi
            fi
            restored=1
        fi

        # core.excludesFile のリンク解除
        local excludes_path="$GIT_MOD_BASE_DIR/.gitignore_global"
        local current_excludes
        current_excludes=$(git config --global core.excludesFile 2>/dev/null || true)
        if [[ "$current_excludes" == "$excludes_path" ]]; then
            if (( DRY_RUN )); then
                msg_dry_run "git config --global --unset core.excludesFile"
            else
                if git config --global --unset core.excludesFile 2>/dev/null; then
                    msg_info "core.excludesFile の設定を解除しました。"
                else
                    msg_warn "core.excludesFile の解除に失敗しました。手動で確認してください:"
                    msg_step "git config --global --edit"
                fi
            fi
            restored=1
        fi
    else
        msg_warn "git が見つかりません。git config の解除をスキップします。"
    fi

    # 管理対象ファイルのバックアップ復元 / 削除
    for entry in "${GIT_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r _src dst label _hint <<< "$entry"

        local newest
        newest=$(find_newest_backup "${dst}.backup."'*') || true

        if [[ -n "$newest" ]]; then
            printf '%s\n' "復元: ${label} をバックアップ ($(basename "$newest")) から戻します。"
            run_cmd command mv "$newest" "$dst" || {
                msg_error "${label} の復元に失敗しました。"
                return 1
            }
            restored=1
        elif [[ -f "$dst" || -h "$dst" ]]; then
            printf '%s\n' "削除: ${label} を削除します。"
            run_cmd command rm -f "$dst" || {
                msg_error "${label} の削除に失敗しました。"
                return 1
            }
            restored=1
        else
            msg_info "${label} は配置されていません。スキップします。"
        fi
    done

    if (( restored )); then
        msg_success "Git グローバル設定のアンインストールが完了しました。"
    else
        msg_info "Git グローバル設定の復元・削除対象はありませんでした。"
    fi
}
