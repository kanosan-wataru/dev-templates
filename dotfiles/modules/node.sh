# ---------------------------------------------
# モジュール: Node.js 開発環境
# fnm (Fast Node Manager) + Node.js LTS
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="node"
MODULE_NAME="Node.js 開発環境"
MODULE_DESC="fnm + Node.js LTS (バージョン管理)"
MODULE_DEFAULT=0
MODULE_ORDER=18

# NOTE: モジュール固有の変数には衝突回避のため NODE_MOD_ プレフィックスを使用

NODE_MOD_FNM_BIN_DIR="$HOME/.local/bin"
# NOTE: バージョンを固定して予期せぬ変更を防止。更新時はこの値を変更する
NODE_MOD_FNM_VERSION="v1.38.1"
NODE_MOD_FNM_REPO="https://github.com/Schniz/fnm/releases/download/${NODE_MOD_FNM_VERSION}"

# 管理対象ファイル（配布元パス, 配置先パス, 表示名, 未検出時メッセージ）
NODE_MOD_MANAGED_FILES=(
    "$SCRIPT_DIR/.shell/node.sh|${HOME}/.shell/node.sh|node.sh|"
)

# --- ヘルパー: OS 判定 ---
_node_detect_os() {
    case "$OSTYPE" in
    darwin*) printf '%s' "macos" ;;
    linux*) printf '%s' "linux" ;;
    *) printf '%s' "unknown" ;;
    esac
}

# --- ヘルパー: アーキテクチャ判定 ---
_node_detect_arch() {
    case "$(uname -m)" in
    x86_64) printf '%s' "x64" ;;
    aarch64) printf '%s' "arm64" ;;
    arm64) printf '%s' "arm64" ;;
    *) printf '%s' "unknown" ;;
    esac
}

# --- セットアップ ---
setup_node() {
    msg_header "Node.js 開発環境"
    print_separator

    # べき等性チェック
    local fnm_exists=0
    if command -v fnm >/dev/null 2>&1; then
        local current_ver
        current_ver=$(fnm --version 2>/dev/null || printf '%s' "unknown")
        msg_info "fnm は既にインストールされています (${current_ver})。スキップします。"
        fnm_exists=1
    fi

    if ((!fnm_exists)); then
        local os
        os=$(_node_detect_os)

        case "$os" in
        macos)
            _node_setup_macos || return 1
            ;;
        linux)
            _node_setup_linux || return 1
            ;;
        *)
            msg_error "未対応の OS です (OSTYPE=${OSTYPE})。"
            return 1
            ;;
        esac
    fi

    # 一時的に fnm を PATH に通す（同セッション内の後続モジュール用）
    if ((!DRY_RUN)); then
        [[ -d "$NODE_MOD_FNM_BIN_DIR" ]] && export PATH="$NODE_MOD_FNM_BIN_DIR:$PATH"
        if command -v fnm >/dev/null 2>&1; then
            eval "$(fnm env)"
        fi
    fi

    # Node.js LTS のインストール（失敗しても fnm 自体は利用可能なので警告に留める）
    _node_install_lts || {
        msg_warn "Node.js LTS のインストールに失敗しましたが、fnm は利用可能です。"
        msg_step "手動でインストールしてください: fnm install --lts"
    }

    # 設定ファイルの配置
    _node_install_config

    # コマンドハッシュをクリア（後続モジュールの ensure_node 用）
    ((!DRY_RUN)) && hash -r

    if ((DRY_RUN)); then
        msg_info "Node.js 開発環境をセットアップ予定です（dry-run）。"
    else
        msg_success "Node.js 開発環境のセットアップが完了しました。"
        if command -v node >/dev/null 2>&1; then
            msg_step "Node.js: $(node -v 2>/dev/null || printf '%s' 'N/A')"
            msg_step "npm: $(npm -v 2>/dev/null || printf '%s' 'N/A')"
        fi
        printf '\n'
        printf '%s\n' "使い方:"
        msg_step "fnm install 22            # 特定バージョンをインストール"
        msg_step "fnm use 22                # バージョンを切り替え"
        msg_step "fnm default 22            # デフォルトバージョンを設定"
    fi
}

# --- macOS セットアップ ---
_node_setup_macos() {
    if ! command -v brew >/dev/null 2>&1; then
        msg_error "Homebrew がインストールされていません。"
        msg_step "インストール: https://brew.sh/" >&2
        return 1
    fi

    msg_info "fnm を Homebrew でインストールします..."
    run_cmd brew install fnm || {
        msg_error "fnm のインストールに失敗しました。"
        return 1
    }
}

# --- Linux セットアップ ---
_node_setup_linux() {
    # 依存コマンドの確認（未導入コマンドをまとめて1回でインストール）
    local -a missing_cmds=()
    for cmd in curl unzip; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_cmds+=("$cmd")
        fi
    done

    if ((${#missing_cmds[@]} > 0)); then
        printf '%s\n' "${missing_cmds[*]} をインストールします..."
        if command -v apt-get >/dev/null 2>&1; then
            run_cmd sudo apt-get update -qq || {
                msg_warn "apt update に失敗しました。後続のインストールに失敗する可能性があります。"
            }
            run_cmd sudo apt-get install -y "${missing_cmds[@]}" || {
                msg_error "${missing_cmds[*]} のインストールに失敗しました。"
                return 1
            }
        else
            msg_error "${missing_cmds[*]} がインストールされていません。手動でインストールしてください。"
            return 1
        fi
    fi

    # アーキテクチャ判定
    local arch
    arch=$(_node_detect_arch)
    if [[ "$arch" == "unknown" ]]; then
        msg_error "未対応のアーキテクチャです ($(uname -m))。"
        return 1
    fi

    local zip_name="fnm-linux-${arch}.zip"
    local download_url="${NODE_MOD_FNM_REPO}/${zip_name}"

    # バイナリ配置先の作成
    if [[ ! -d "$NODE_MOD_FNM_BIN_DIR" ]]; then
        run_cmd command mkdir -p "$NODE_MOD_FNM_BIN_DIR" || {
            msg_error "$NODE_MOD_FNM_BIN_DIR の作成に失敗しました。"
            return 1
        }
    fi

    # 不完全なインストールの検出
    if [[ -f "$NODE_MOD_FNM_BIN_DIR/fnm" && ! -x "$NODE_MOD_FNM_BIN_DIR/fnm" ]]; then
        msg_warn "fnm バイナリは存在しますが実行権限がありません。再インストールします。"
        run_cmd command rm -f "$NODE_MOD_FNM_BIN_DIR/fnm" || {
            msg_error "既存の fnm バイナリの削除に失敗しました。"
            msg_step "手動で削除してください: rm -f $NODE_MOD_FNM_BIN_DIR/fnm" >&2
            return 1
        }
    fi

    msg_info "fnm を GitHub Releases からダウンロードします (${arch})..."

    if ((DRY_RUN)); then
        msg_dry_run "curl -fsSL ${download_url} -o /tmp/${zip_name}"
        msg_dry_run "unzip -o /tmp/${zip_name} -d ${NODE_MOD_FNM_BIN_DIR}"
        msg_dry_run "chmod +x ${NODE_MOD_FNM_BIN_DIR}/fnm"
    else
        # 安全な一時ファイルの作成（予測可能なパスを避ける）
        local tmp_zip
        tmp_zip=$(mktemp /tmp/fnm-XXXXXXXXXX.zip) || {
            msg_error "一時ファイルの作成に失敗しました。"
            return 1
        }

        # ダウンロード
        curl -fsSL "$download_url" -o "$tmp_zip" || {
            msg_error "fnm のダウンロードに失敗しました。"
            printf '%s\n' "  URL: ${download_url}" >&2
            rm -f "$tmp_zip"
            return 1
        }

        # 解凍
        unzip -o "$tmp_zip" -d "$NODE_MOD_FNM_BIN_DIR" || {
            msg_error "fnm の解凍に失敗しました。"
            rm -f "$tmp_zip"
            return 1
        }
        rm -f "$tmp_zip"

        # 実行権限の付与
        chmod +x "$NODE_MOD_FNM_BIN_DIR/fnm" || {
            msg_error "fnm の実行権限の付与に失敗しました。"
            return 1
        }
    fi
}

# --- Node.js LTS インストール ---
_node_install_lts() {
    if ((DRY_RUN)); then
        msg_dry_run "fnm install --lts"
        msg_dry_run "fnm default lts-latest"
        return 0
    fi

    if ! command -v fnm >/dev/null 2>&1; then
        msg_warn "fnm が PATH に見つかりません。Node.js LTS のインストールをスキップします。"
        return 0
    fi

    # 既に Node.js がインストール済みか確認（バージョンも検証）
    if command -v node >/dev/null 2>&1; then
        local node_ver node_major
        node_ver="$(node -v 2>/dev/null || true)"

        if [[ -n "$node_ver" ]]; then
            node_major="${node_ver#v}"
            node_major="${node_major%%.*}"
        fi

        if [[ "$node_major" =~ ^[0-9]+$ ]] && ((node_major >= 18)); then
            msg_info "Node.js は既にインストールされています (${node_ver})。スキップします。"
            return 0
        elif [[ "$node_major" =~ ^[0-9]+$ ]] && ((node_major < 18)); then
            msg_warn "既存の Node.js (${node_ver}) は推奨バージョン (v18 以上) 未満です。fnm で LTS をインストールします。"
        else
            msg_warn "Node.js のバージョンを特定できません (${node_ver:-unknown})。fnm で LTS をインストールします。"
        fi
    fi

    msg_info "Node.js LTS をインストールします..."
    fnm install --lts || {
        msg_error "Node.js LTS のインストールに失敗しました。"
        msg_step "手動でインストールしてください: fnm install --lts" >&2
        return 1
    }

    # デフォルトバージョンに設定
    fnm default lts-latest 2>/dev/null || {
        msg_warn "デフォルトバージョンの設定に失敗しました。"
    }

    # fnm env を再評価して node を PATH に通す
    eval "$(fnm env)"
}

# --- 設定ファイル配置ヘルパー ---
_node_install_config() {
    msg_info "設定ファイルを配置します..."
    run_cmd mkdir -p "$HOME/.shell"
    for entry in "${NODE_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r src dst label hint <<<"$entry"
        install_config "$src" "$dst" "$label" "$hint"
    done
}

# --- アンインストール ---
uninstall_node() {
    local restored=0

    for entry in "${NODE_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r _src dst label _hint <<<"$entry"

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

    if ((restored)); then
        msg_success "Node.js 開発環境の設定を削除しました。"
    else
        msg_info "Node.js 開発環境の復元・削除対象はありませんでした。"
    fi

    printf '\n'
    printf '%s\n' "NOTE: fnm 本体と Node.js バージョンは削除されていません。不要な場合は以下を手動で削除してください:"
    local os
    os=$(_node_detect_os)
    case "$os" in
    macos)
        msg_step "brew uninstall fnm"
        ;;
    *)
        msg_step "rm -f ${NODE_MOD_FNM_BIN_DIR}/fnm"
        ;;
    esac
    msg_step "rm -rf ${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
}
