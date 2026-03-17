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
module_setup() {
    print -P ""
    print -P "%F{36}%B[Git グローバル設定]%b%f"
    print -P "---------------------------------------------"

    # git コマンドの存在確認
    if ! command -v git >/dev/null 2>&1; then
        print -P "%F{160}エラー: git コマンドが見つかりません。インストールしてください。%f" >&2
        return 1
    fi
    print -P "情報: git が利用可能です ($(command git --version))"

    # 設定ファイルの配置
    print -P "設定ファイルを配置します..."
    for entry in "${GIT_MOD_MANAGED_FILES[@]}"; do
        local src="${entry[(ws:|:)1]}"
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"
        local hint="${entry[(ws:|:)4]}"
        install_config "$src" "$dst" "$label" "$hint"
    done

    # include.path で共有設定をリンク
    _git_setup_include_path || return 1

    # core.excludesFile でグローバル gitignore を紐付け
    _git_setup_excludes_file || return 1

    if (( DRY_RUN )); then
        print -P "情報: Git グローバル設定をセットアップ予定です（dry-run）。"
    else
        print -P "%F{34}Git グローバル設定のセットアップが完了しました。%f"
    fi

    # user.name / user.email の設定ガイド
    _git_show_user_guide
}

# --- include.path の設定 ---
_git_setup_include_path() {
    local shared_path="$GIT_MOD_BASE_DIR/.gitconfig.shared"

    # 既に設定済みか確認
    if git config --global --get-all include.path 2>/dev/null | grep -qF "$shared_path"; then
        print -P "情報: include.path は既に設定されています。スキップします。"
        return 0
    fi

    if (( DRY_RUN )); then
        print -P "%F{242}  [DRY-RUN] git config --global --add include.path ${shared_path}%f"
    else
        git config --global --add include.path "$shared_path" || {
            print -P "%F{160}エラー: include.path の設定に失敗しました。%f" >&2
            return 1
        }
        print -P "情報: include.path に ${shared_path} を追加しました。"
    fi
}

# --- core.excludesFile の設定 ---
_git_setup_excludes_file() {
    local excludes_path="$GIT_MOD_BASE_DIR/.gitignore_global"

    # 既に設定済みか確認
    local current_excludes
    current_excludes=$(git config --global core.excludesFile 2>/dev/null || true)
    if [[ "$current_excludes" == "$excludes_path" ]]; then
        print -P "情報: core.excludesFile は既に設定されています。スキップします。"
        return 0
    fi

    if (( DRY_RUN )); then
        if [[ -n "$current_excludes" && "$current_excludes" != "$excludes_path" ]]; then
            print -P "%F{220}警告: core.excludesFile が ${current_excludes} から ${excludes_path} に変更されます。%f"
        fi
        print -P "%F{242}  [DRY-RUN] git config --global core.excludesFile ${excludes_path}%f"
    else
        git config --global core.excludesFile "$excludes_path" || {
            print -P "%F{160}エラー: core.excludesFile の設定に失敗しました。%f" >&2
            return 1
        }
        if [[ -n "$current_excludes" && "$current_excludes" != "$excludes_path" ]]; then
            print -P "%F{220}警告: core.excludesFile を ${current_excludes} から ${excludes_path} に変更しました。%f"
        else
            print -P "情報: core.excludesFile に ${excludes_path} を設定しました。"
        fi
    fi
}

# --- user.name / user.email のガイド表示 ---
_git_show_user_guide() {
    local user_name user_email
    user_name=$(git config --global user.name 2>/dev/null || true)
    user_email=$(git config --global user.email 2>/dev/null || true)

    if [[ -n "$user_name" && -n "$user_email" ]]; then
        print -P ""
        print -P "情報: Git ユーザー設定は既に構成されています。"
        print -P "  user.name:  ${user_name}"
        print -P "  user.email: ${user_email}"
    else
        print -P ""
        print -P "%F{220}NOTE: Git のユーザー情報が未設定です。以下を実行してください:%f"
        if [[ -z "$user_name" ]]; then
            print -P "  git config --global user.name \"Your Name\""
        fi
        if [[ -z "$user_email" ]]; then
            print -P "  git config --global user.email \"your@email.com\""
        fi
    fi
}

# --- アンインストール ---
module_uninstall() {
    local restored=0

    # git config の解除（git が利用可能な場合のみ）
    if command -v git >/dev/null 2>&1; then
        # include.path のリンク解除
        local shared_path="$GIT_MOD_BASE_DIR/.gitconfig.shared"
        if git config --global --get-all include.path 2>/dev/null | grep -qF "$shared_path"; then
            if (( DRY_RUN )); then
                print -P "%F{242}  [DRY-RUN] git config --global --fixed-value --unset-all include.path ${shared_path}%f"
            else
                if git config --global --fixed-value --unset-all include.path "$shared_path" 2>/dev/null; then
                    print -P "情報: include.path から ${shared_path} を削除しました。"
                else
                    print -P "%F{220}警告: include.path の解除に失敗しました。手動で確認してください:%f"
                    print -P "  git config --global --edit"
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
                print -P "%F{242}  [DRY-RUN] git config --global --unset core.excludesFile%f"
            else
                if git config --global --unset core.excludesFile 2>/dev/null; then
                    print -P "情報: core.excludesFile の設定を解除しました。"
                else
                    print -P "%F{220}警告: core.excludesFile の解除に失敗しました。手動で確認してください:%f"
                    print -P "  git config --global --edit"
                fi
            fi
            restored=1
        fi
    else
        print -P "%F{220}警告: git が見つかりません。git config の解除をスキップします。%f"
    fi

    # 管理対象ファイルのバックアップ復元 / 削除
    for entry in "${GIT_MOD_MANAGED_FILES[@]}"; do
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"

        local -a latest_backup
        latest_backup=( "${dst}.backup."*(N^/Om[1]) )

        if (( ${#latest_backup[@]} > 0 )); then
            print -P "復元: ${label} をバックアップ (${latest_backup[1]:t}) から戻します。"
            run_cmd command mv "${latest_backup[1]}" "$dst" || {
                print -P "%F{160}エラー: ${label} の復元に失敗しました。%f" >&2
                return 1
            }
            restored=1
        elif [[ -f "$dst" || -h "$dst" ]]; then
            print -P "削除: ${label} を削除します。"
            run_cmd command rm -f "$dst" || {
                print -P "%F{160}エラー: ${label} の削除に失敗しました。%f" >&2
                return 1
            }
            restored=1
        else
            print -P "情報: ${label} は配置されていません。スキップします。"
        fi
    done

    if (( restored )); then
        print -P "%F{34}Git グローバル設定のアンインストールが完了しました。%f"
    else
        print -P "情報: Git グローバル設定の復元・削除対象はありませんでした。"
    fi
}
