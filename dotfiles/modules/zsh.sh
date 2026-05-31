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

# Source separation: deploy templates to subdirectories, add source line to user dotfiles
# NOTE: Elements are "src|user_file|deploy_dir|deploy_name|label"
# NOTE: .zshrc は完全な設定本体のため直接配置する（下記 _zsh_direct_files）。
#       source 分離方式だとユーザーの既存 .zshrc と二重ロードになるため。
#       .bashrc は OS デフォルト (.bashrc) を尊重するため source 分離方式のまま。
ZSH_MOD_SOURCE_CONFIGS=(
    "$SCRIPT_DIR/.bashrc|$HOME/.bashrc|$HOME/.bashrc.d|dev-templates.bash|.bashrc"
)

# 管理対象ファイルのリスト（配布元パス, 配置先パス, 表示名, 未検出時メッセージ）
# NOTE: 配列の各要素は "src|dst|label|hint" の形式
ZSH_MOD_MANAGED_FILES=(
    "$SCRIPT_DIR/.zshrc|$ZSH_MOD_BASE_DIR/.zshrc|.zshrc|"
    "$HOME/.bashrc.d/dev-templates.bash|$HOME/.bashrc.d/dev-templates.bash|.bashrc (template)|"
    "$SCRIPT_DIR/.zsh/.p10k.zsh|$ZSH_MOD_CONFIG_DIR/.p10k.zsh|.p10k.zsh|Powerlevel10k のデフォルト設定が使用されます。"
    "$SCRIPT_DIR/.zsh/plugins.zsh|$ZSH_MOD_CONFIG_DIR/plugins.zsh|plugins.zsh|プラグインは手動で設定してください。"
    "$SCRIPT_DIR/.shell/aliases.sh|$HOME/.shell/aliases.sh|aliases.sh|エイリアスは手動で設定してください。"
)

# --- ヘルパー: OS 判定 ---
# Returns: "macos" / "linux" / "unknown"
_zsh_detect_os() {
    case "$OSTYPE" in
    darwin*) printf '%s' "macos" ;;
    linux*) printf '%s' "linux" ;;
    *) printf '%s' "unknown" ;;
    esac
}

# --- ヘルパー: zsh のインストール確認・実行 ---
# Returns: 0=available, 1=failed
_zsh_ensure_installed() {
    if command -v zsh >/dev/null 2>&1; then
        msg_info "zsh は既にインストールされています ($(zsh --version 2>/dev/null | head -1))。"
        return 0
    fi

    local os
    os=$(_zsh_detect_os)

    case "$os" in
    macos)
        msg_error "zsh が見つかりません。macOS では通常プリインストールされています。"
        msg_step "Homebrew でインストールしてください: brew install zsh" >&2
        return 1
        ;;
    linux)
        if ! command -v apt-get >/dev/null 2>&1; then
            msg_error "apt-get が見つかりません。zsh を手動でインストールしてください。"
            return 1
        fi
        msg_info "zsh をインストールします..."
        run_cmd sudo apt-get update -qq || {
            msg_warn "apt-get update に失敗しました。古いパッケージインデックスのまま zsh のインストールを試行します。"
        }
        run_cmd sudo apt-get install -y zsh || {
            msg_error "zsh のインストールに失敗しました。"
            return 1
        }
        if ((!DRY_RUN)); then
            msg_success "$(zsh --version 2>/dev/null | head -1) をインストールしました。"
        fi
        ;;
    *)
        msg_error "未対応の OS です (OSTYPE=${OSTYPE})。zsh を手動でインストールしてください。"
        return 1
        ;;
    esac
}

# --- ヘルパー: デフォルトシェルを zsh に変更 ---
_zsh_set_default_shell() {
    local zsh_path
    zsh_path=$(command -v zsh)

    local real_user
    real_user="${SUDO_USER:-$(id -un)}"

    local current_shell
    if command -v getent >/dev/null 2>&1; then
        current_shell=$(getent passwd "$real_user" | cut -d: -f7)
    elif command -v dscl >/dev/null 2>&1; then
        current_shell=$(dscl . -read "/Users/$real_user" UserShell | awk '{print $2}')
    else
        msg_warn "現在のデフォルトシェルを確認できません。"
        current_shell=""
    fi

    if [[ "$current_shell" == "$zsh_path" ]]; then
        msg_info "デフォルトシェルは既に zsh ($zsh_path) です。"
        return 0
    fi

    msg_info "デフォルトシェルを zsh ($zsh_path) に変更します..."
    run_cmd sudo chsh -s "$zsh_path" "$real_user" || {
        msg_error "デフォルトシェルの変更に失敗しました。"
        msg_step "手動で実行してください: chsh -s $zsh_path" >&2
        return 1
    }

    if ((!DRY_RUN)); then
        msg_success "デフォルトシェルを $zsh_path に変更しました。"
    fi
}

# --- ヘルパー: 旧 source 分離方式 (.zshrc) の名残をクリーンアップ ---
# 以前は完全な .zshrc を .zshrc.d/dev-templates.zsh として配置し、.zshrc に source
# 行を追記していた。.zshrc を直接配置する方式へ移行したため、孤立した旧ファイルを退避する。
# NOTE: .zshrc 本体の source 行除去は install_config による上書き配置が担う。本関数は
#       .zshrc が dev-templates.zsh をまだ source していないことを確認してから退避するため、
#       直接配置がスキップされた場合は何もせず環境を壊さない。
#       必ず .zshrc の直接配置 (install_config) より後に呼ぶこと。
_zsh_cleanup_legacy_dev_templates() {
    local zshrc="$ZSH_MOD_BASE_DIR/.zshrc"
    local legacy="$ZSH_MOD_BASE_DIR/.zshrc.d/dev-templates.zsh"

    # 孤立した旧ファイル（通常ファイル）が無ければ何もしない。
    # シンボリックリンクは意図的な配置の可能性があるため触らない。
    [[ -f "$legacy" && ! -L "$legacy" ]] || return 0

    # .zshrc がまだ dev-templates.zsh を source している場合、.zshrc は旧テンプレートに
    # 依存している（直接配置がスキップされた等）。退避すると .zshrc が壊れるため触らない。
    # source / . (ドットコマンド) の両形式を検出する。パス区切り (/) を要求して
    # my-dev-templates.zsh のような別名ファイルへの source を誤検出しないようにする。
    if [[ -f "$zshrc" ]] && command grep -qE '^[[:space:]]*(source|\.)[[:space:]].*/dev-templates\.zsh' "$zshrc" 2>/dev/null; then
        msg_warn ".zshrc がまだ dev-templates.zsh を source しています。直接配置の適用後に旧ファイルが整理されます。"
        return 0
    fi

    # 孤立した旧 dev-templates.zsh を退避する（mv の成否を検知）。
    # 退避先は uninstall_zsh の復元対象外のため、不要なら手動削除でよい。
    # BACKUP_SUFFIX 未定義（スタンドアロン source 等）だと dest==legacy となり mv が
    # "same file" で失敗するため、防御的にスキップする。
    if [[ -z "${BACKUP_SUFFIX:-}" ]]; then
        msg_warn "BACKUP_SUFFIX が未定義のため ${legacy} の退避をスキップします。"
        return 0
    fi
    local dest="${legacy}${BACKUP_SUFFIX}"
    if ((DRY_RUN)); then
        msg_dry_run "孤立した ${legacy} を ${dest} へ退避予定です。"
    elif command mv "$legacy" "$dest"; then
        msg_info "孤立した旧 dev-templates.zsh を ${dest} へ退避しました（不要なら手動削除してください）。"
    else
        msg_warn "${legacy} の退避に失敗しました。手動で削除してください。"
    fi
}

# --- セットアップ ---
setup_zsh() {
    msg_header "Zsh 設定一式"
    print_separator

    # zsh のインストール確認・実行
    _zsh_ensure_installed || return 1

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
        if ((DRY_RUN)); then
            msg_info "Zinit ${ZSH_MOD_ZINIT_VERSION} をインストール予定です（dry-run）。"
        else
            msg_success "Zinit ${ZSH_MOD_ZINIT_VERSION} のインストールに成功しました。"
        fi
    elif ((UPGRADE)); then
        # Upgrade Zinit in a way that works with detached HEAD / shallow clones
        msg_info "Zinit のアップグレードを実行します..."
        run_cmd command git -C "$ZSH_MOD_ZINIT_HOME" fetch --tags --force --depth 1 origin "$ZSH_MOD_ZINIT_VERSION" || {
            msg_error "Zinit のアップグレードに失敗しました（fetch に失敗しました）。"
            return 1
        }
        run_cmd command git -C "$ZSH_MOD_ZINIT_HOME" checkout --force FETCH_HEAD || {
            msg_error "Zinit のアップグレードに失敗しました（checkout に失敗しました）。"
            return 1
        }
        if ((DRY_RUN)); then
            msg_info "Zinit をアップグレード予定です（dry-run）。"
        else
            msg_success "Zinit のアップグレードが完了しました。"
        fi
    else
        msg_info "Zinit は既にインストールされています。"
    fi

    # 設定ディレクトリの作成
    local _zsh_mod_dir
    for _zsh_mod_dir in "$ZSH_MOD_CONFIG_DIR" "$HOME/.shell"; do
        if [[ ! -d "$_zsh_mod_dir" ]]; then
            run_cmd command mkdir -p -m 700 "$_zsh_mod_dir" || {
                msg_error "$_zsh_mod_dir の作成に失敗しました。"
                return 1
            }
            if ((DRY_RUN)); then
                msg_info "$_zsh_mod_dir を作成予定です（dry-run）。"
            else
                msg_info "$_zsh_mod_dir を作成しました。"
            fi
        else
            msg_info "$_zsh_mod_dir は既に存在します。"
        fi
    done

    # 設定ファイルの配置
    msg_info "設定ファイルを配置します..."

    # Source separation: .bashrc deploys to a subdirectory (OS デフォルトを尊重)
    for entry in "${ZSH_MOD_SOURCE_CONFIGS[@]}"; do
        IFS='|' read -r src user_file deploy_dir deploy_name label <<<"$entry"
        install_source_config "$src" "$user_file" "$deploy_dir" "$deploy_name" "$label"
    done

    # Direct deployment: .zshrc 本体 + その他の設定ファイル
    # NOTE: .zshrc は完全な設定本体のため直接配置する（source 分離は二重ロードの原因）。
    #       ユーザーカスタマイズは ~/.zsh/*.zsh と ~/.shell/*.sh で受けられる。
    local _zsh_direct_files=(
        "$SCRIPT_DIR/.zshrc|$ZSH_MOD_BASE_DIR/.zshrc|.zshrc|"
        "$SCRIPT_DIR/.zsh/.p10k.zsh|$ZSH_MOD_CONFIG_DIR/.p10k.zsh|.p10k.zsh|Powerlevel10k のデフォルト設定が使用されます。"
        "$SCRIPT_DIR/.zsh/plugins.zsh|$ZSH_MOD_CONFIG_DIR/plugins.zsh|plugins.zsh|プラグインは手動で設定してください。"
        "$SCRIPT_DIR/.shell/aliases.sh|$HOME/.shell/aliases.sh|aliases.sh|エイリアスは手動で設定してください。"
    )
    for entry in "${_zsh_direct_files[@]}"; do
        IFS='|' read -r src dst label hint <<<"$entry"
        install_config "$src" "$dst" "$label" "$hint"
    done

    # 旧 source 分離方式の名残（孤立した dev-templates.zsh）を整理する。
    # NOTE: .zshrc の直接配置が済んだ後に呼ぶ（順序が重要）。
    _zsh_cleanup_legacy_dev_templates

    # デフォルトシェルを zsh に変更
    if ! _zsh_set_default_shell; then
        msg_warn "デフォルトシェルの変更に失敗しましたが、zsh 設定のセットアップは続行します。"
    fi

    msg_success "Zsh 設定一式のセットアップが完了しました。"
}

# --- ステータス表示 ---
module_status() {
    local status version
    if command -v zsh &>/dev/null; then
        version=$(zsh --version 2>/dev/null | head -1)
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "$version"
    else
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
    fi
}

# --- アンインストール ---
uninstall_zsh() {
    local restored=0

    for entry in "${ZSH_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r _src dst label _hint <<<"$entry"

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
        elif [[ -f "$dst" || -L "$dst" ]]; then
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

    if ((restored)); then
        msg_success "Zsh 設定のアンインストールが完了しました。"
    else
        msg_info "Zsh 設定の復元・削除対象はありませんでした。"
    fi
    printf '%s\n' "NOTE: Zinit 本体は削除されていません。不要な場合は以下を手動で削除してください:"
    msg_step "rm -rf $(dirname "$ZSH_MOD_ZINIT_HOME")"
}
