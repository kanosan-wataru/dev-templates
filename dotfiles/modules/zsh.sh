# ---------------------------------------------
# モジュール: Zsh 設定一式
# Zinit + プラグイン + Powerlevel10k テーマ + エイリアス
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="zsh"
MODULE_NAME="Zsh 設定一式"
MODULE_DESC="Zinit + プラグイン + テーマ + エイリアス"
MODULE_DEFAULT=1
MODULE_ORDER=10

# --- Zsh 固有変数 ---
# NOTE: モジュール固有の変数には衝突回避のため ZSH_MOD_ プレフィックスを使用
ZSH_MOD_BASE_DIR="${ZDOTDIR:-$HOME}"
ZSH_MOD_CONFIG_DIR="$ZSH_MOD_BASE_DIR/.zsh"
ZSH_MOD_ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
ZSH_MOD_ZINIT_VERSION="v3.14.0"

# 管理対象ファイルのリスト（配布元パス, 配置先パス, 表示名, 未検出時メッセージ）
# NOTE: 配列の各要素は "src|dst|label|hint" の形式
ZSH_MOD_MANAGED_FILES=(
    "$SCRIPT_DIR/.zshrc|$ZSH_MOD_BASE_DIR/.zshrc|.zshrc|"
    "$SCRIPT_DIR/.zsh/.p10k.zsh|$ZSH_MOD_CONFIG_DIR/.p10k.zsh|.p10k.zsh|Powerlevel10k のデフォルト設定が使用されます。"
    "$SCRIPT_DIR/.zsh/plugins.zsh|$ZSH_MOD_CONFIG_DIR/plugins.zsh|plugins.zsh|プラグインは手動で設定してください。"
    "$SCRIPT_DIR/.zsh/aliases.zsh|$ZSH_MOD_CONFIG_DIR/aliases.zsh|aliases.zsh|エイリアスは手動で設定してください。"
)

# --- セットアップ ---
setup_zsh() {
    msg_header "Zsh 設定一式"
    print_separator

    # 依存コマンドの確認
    if ! command -v git >/dev/null 2>&1; then
        msg_error "git コマンドが見つかりません。インストールしてください。"
        return 1
    fi
    msg_info "git が利用可能です ($(command git --version))"

    # Zinit のインストール
    msg_info "Zinit の状態を確認・インストールします..."
    if [[ ! -f "$ZSH_MOD_ZINIT_HOME/zinit.zsh" ]]; then
        color_print "${C_YELLOW}" "Zinit (zdharma-continuum/zinit) をインストール中..."
        run_cmd command mkdir -p -m 700 "$(dirname "$ZSH_MOD_ZINIT_HOME")" || {
            msg_error "Zinit 用ディレクトリの作成に失敗しました。"
            return 1
        }
        run_cmd command git clone --branch "$ZSH_MOD_ZINIT_VERSION" --depth 1 https://github.com/zdharma-continuum/zinit "$ZSH_MOD_ZINIT_HOME" || {
            msg_error "Zinit の git clone に失敗しました。"
            return 1
        }
        if (( DRY_RUN )); then
            msg_info "Zinit ${ZSH_MOD_ZINIT_VERSION} をインストール予定です（dry-run）。"
        else
            msg_success "Zinit ${ZSH_MOD_ZINIT_VERSION} のインストールに成功しました。"
        fi
    else
        msg_info "Zinit は既にインストールされています。"
    fi

    # 設定ディレクトリの作成
    if [[ ! -d "$ZSH_MOD_CONFIG_DIR" ]]; then
        run_cmd command mkdir -p -m 700 "$ZSH_MOD_CONFIG_DIR" || {
            msg_error "$ZSH_MOD_CONFIG_DIR の作成に失敗しました。"
            return 1
        }
        if (( DRY_RUN )); then
            msg_info "$ZSH_MOD_CONFIG_DIR を作成予定です（dry-run）。"
        else
            msg_info "$ZSH_MOD_CONFIG_DIR を作成しました。"
        fi
    else
        msg_info "$ZSH_MOD_CONFIG_DIR は既に存在します。"
    fi

    # 設定ファイルの配置
    msg_info "設定ファイルを配置します..."
    for entry in "${ZSH_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r src dst label hint <<< "$entry"
        install_config "$src" "$dst" "$label" "$hint"
    done

    msg_success "Zsh 設定一式のセットアップが完了しました。"
}

# --- アンインストール ---
uninstall_zsh() {
    local restored=0

    for entry in "${ZSH_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r _src dst label _hint <<< "$entry"

        # find_newest_backup で最新のバックアップを検索
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
            printf '%s\n' "削除: ${label} を削除します（セットアップ前の状態に復元）。"
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
        msg_success "Zsh 設定のアンインストールが完了しました。"
    else
        msg_info "Zsh 設定の復元・削除対象はありませんでした。"
    fi
    printf '%s\n' "NOTE: Zinit 本体は削除されていません。不要な場合は以下を手動で削除してください:"
    msg_step "rm -rf $(dirname "$ZSH_MOD_ZINIT_HOME")"
}
