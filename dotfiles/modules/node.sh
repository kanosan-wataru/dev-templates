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
    "$SCRIPT_DIR/.zsh/node.zsh|${ZDOTDIR:-$HOME}/.zsh/node.zsh|node.zsh|"
)

# --- ヘルパー: OS 判定 ---
_node_detect_os() {
    case "$OSTYPE" in
        darwin*) print "macos" ;;
        linux*)  print "linux" ;;
        *)       print "unknown" ;;
    esac
}

# --- ヘルパー: アーキテクチャ判定 ---
_node_detect_arch() {
    case "$(uname -m)" in
        x86_64)  print "x64" ;;
        aarch64) print "arm64" ;;
        arm64)   print "arm64" ;;
        *)       print "unknown" ;;
    esac
}

# --- セットアップ ---
module_setup() {
    print -P ""
    print -P "%F{36}%B[Node.js 開発環境]%b%f"
    print -P "---------------------------------------------"

    # べき等性チェック
    local fnm_exists=0
    if command -v fnm >/dev/null 2>&1; then
        local current_ver
        current_ver=$(fnm --version 2>/dev/null || print "unknown")
        print -P "情報: fnm は既にインストールされています (${current_ver})。スキップします。"
        fnm_exists=1
    fi

    if (( ! fnm_exists )); then
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
                print -P "%F{160}エラー: 未対応の OS です (OSTYPE=${OSTYPE})。%f" >&2
                return 1
                ;;
        esac
    fi

    # 一時的に fnm を PATH に通す（同セッション内の後続モジュール用）
    if (( ! DRY_RUN )); then
        [[ -d "$NODE_MOD_FNM_BIN_DIR" ]] && export PATH="$NODE_MOD_FNM_BIN_DIR:$PATH"
        if command -v fnm >/dev/null 2>&1; then
            eval "$(fnm env)"
        fi
    fi

    # Node.js LTS のインストール（失敗しても fnm 自体は利用可能なので警告に留める）
    _node_install_lts || {
        print -P "%F{220}警告: Node.js LTS のインストールに失敗しましたが、fnm は利用可能です。%f"
        print -P "  手動でインストールしてください: fnm install --lts"
    }

    # 設定ファイルの配置
    _node_install_config

    # コマンドハッシュをクリア（後続モジュールの ensure_node 用）
    (( ! DRY_RUN )) && hash -r

    if (( DRY_RUN )); then
        print -P "情報: Node.js 開発環境をセットアップ予定です（dry-run）。"
    else
        print -P "%F{34}Node.js 開発環境のセットアップが完了しました。%f"
        if command -v node >/dev/null 2>&1; then
            print -P "  Node.js: $(node -v 2>/dev/null || print 'N/A')"
            print -P "  npm: $(npm -v 2>/dev/null || print 'N/A')"
        fi
        print -P ""
        print -P "使い方:"
        print -P "  fnm install 22            # 特定バージョンをインストール"
        print -P "  fnm use 22                # バージョンを切り替え"
        print -P "  fnm default 22            # デフォルトバージョンを設定"
    fi
}

# --- macOS セットアップ ---
_node_setup_macos() {
    if ! command -v brew >/dev/null 2>&1; then
        print -P "%F{160}エラー: Homebrew がインストールされていません。%f" >&2
        print -P "  インストール: https://brew.sh/" >&2
        return 1
    fi

    print -P "fnm を Homebrew でインストールします..."
    run_cmd brew install fnm || {
        print -P "%F{160}エラー: fnm のインストールに失敗しました。%f" >&2
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

    if (( ${#missing_cmds[@]} > 0 )); then
        print -P "${missing_cmds[*]} をインストールします..."
        if command -v apt-get >/dev/null 2>&1; then
            run_cmd sudo apt-get update -qq || {
                print -P "%F{220}警告: apt update に失敗しました。後続のインストールに失敗する可能性があります。%f"
            }
            run_cmd sudo apt-get install -y "${missing_cmds[@]}" || {
                print -P "%F{160}エラー: ${missing_cmds[*]} のインストールに失敗しました。%f" >&2
                return 1
            }
        else
            print -P "%F{160}エラー: ${missing_cmds[*]} がインストールされていません。手動でインストールしてください。%f" >&2
            return 1
        fi
    fi

    # アーキテクチャ判定
    local arch
    arch=$(_node_detect_arch)
    if [[ "$arch" == "unknown" ]]; then
        print -P "%F{160}エラー: 未対応のアーキテクチャです ($(uname -m))。%f" >&2
        return 1
    fi

    local zip_name="fnm-linux-${arch}.zip"
    local download_url="${NODE_MOD_FNM_REPO}/${zip_name}"

    # バイナリ配置先の作成
    if [[ ! -d "$NODE_MOD_FNM_BIN_DIR" ]]; then
        run_cmd command mkdir -p "$NODE_MOD_FNM_BIN_DIR" || {
            print -P "%F{160}エラー: $NODE_MOD_FNM_BIN_DIR の作成に失敗しました。%f" >&2
            return 1
        }
    fi

    # 不完全なインストールの検出
    if [[ -f "$NODE_MOD_FNM_BIN_DIR/fnm" && ! -x "$NODE_MOD_FNM_BIN_DIR/fnm" ]]; then
        print -P "%F{220}警告: fnm バイナリは存在しますが実行権限がありません。再インストールします。%f"
        run_cmd command rm -f "$NODE_MOD_FNM_BIN_DIR/fnm" || {
            print -P "%F{160}エラー: 既存の fnm バイナリの削除に失敗しました。%f" >&2
            print -P "  手動で削除してください: rm -f $NODE_MOD_FNM_BIN_DIR/fnm" >&2
            return 1
        }
    fi

    print -P "fnm を GitHub Releases からダウンロードします (${arch})..."

    if (( DRY_RUN )); then
        print -P "%F{242}  [DRY-RUN] curl -fsSL ${download_url} -o /tmp/${zip_name}%f"
        print -P "%F{242}  [DRY-RUN] unzip -o /tmp/${zip_name} -d ${NODE_MOD_FNM_BIN_DIR}%f"
        print -P "%F{242}  [DRY-RUN] chmod +x ${NODE_MOD_FNM_BIN_DIR}/fnm%f"
    else
        # 安全な一時ファイルの作成（予測可能なパスを避ける）
        local tmp_zip
        tmp_zip=$(mktemp /tmp/fnm-XXXXXXXXXX.zip) || {
            print -P "%F{160}エラー: 一時ファイルの作成に失敗しました。%f" >&2
            return 1
        }

        # ダウンロード
        curl -fsSL "$download_url" -o "$tmp_zip" || {
            print -P "%F{160}エラー: fnm のダウンロードに失敗しました。%f" >&2
            print -P "  URL: ${download_url}" >&2
            rm -f "$tmp_zip"
            return 1
        }

        # 解凍
        unzip -o "$tmp_zip" -d "$NODE_MOD_FNM_BIN_DIR" || {
            print -P "%F{160}エラー: fnm の解凍に失敗しました。%f" >&2
            rm -f "$tmp_zip"
            return 1
        }
        rm -f "$tmp_zip"

        # 実行権限の付与
        chmod +x "$NODE_MOD_FNM_BIN_DIR/fnm" || {
            print -P "%F{160}エラー: fnm の実行権限の付与に失敗しました。%f" >&2
            return 1
        }
    fi
}

# --- Node.js LTS インストール ---
_node_install_lts() {
    if (( DRY_RUN )); then
        print -P "%F{242}  [DRY-RUN] fnm install --lts%f"
        print -P "%F{242}  [DRY-RUN] fnm default lts-latest%f"
        return 0
    fi

    if ! command -v fnm >/dev/null 2>&1; then
        print -P "%F{220}警告: fnm が PATH に見つかりません。Node.js LTS のインストールをスキップします。%f"
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

        if [[ "$node_major" == <-> ]] && (( node_major >= 18 )); then
            print -P "情報: Node.js は既にインストールされています (${node_ver})。スキップします。"
            return 0
        elif [[ "$node_major" == <-> ]] && (( node_major < 18 )); then
            print -P "%F{220}警告: 既存の Node.js (${node_ver}) は推奨バージョン (v18 以上) 未満です。fnm で LTS をインストールします。%f"
        else
            print -P "%F{220}警告: Node.js のバージョンを特定できません (${node_ver:-unknown})。fnm で LTS をインストールします。%f"
        fi
    fi

    print -P "Node.js LTS をインストールします..."
    fnm install --lts || {
        print -P "%F{160}エラー: Node.js LTS のインストールに失敗しました。%f" >&2
        print -P "  手動でインストールしてください: fnm install --lts" >&2
        return 1
    }

    # デフォルトバージョンに設定
    fnm default lts-latest 2>/dev/null || {
        print -P "%F{220}警告: デフォルトバージョンの設定に失敗しました。%f"
    }

    # fnm env を再評価して node を PATH に通す
    eval "$(fnm env)"
}

# --- 設定ファイル配置ヘルパー ---
_node_install_config() {
    print -P "設定ファイルを配置します..."
    for entry in "${NODE_MOD_MANAGED_FILES[@]}"; do
        local src="${entry[(ws:|:)1]}"
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"
        local hint="${entry[(ws:|:)4]}"
        install_config "$src" "$dst" "$label" "$hint"
    done
}

# --- アンインストール ---
module_uninstall() {
    local restored=0

    for entry in "${NODE_MOD_MANAGED_FILES[@]}"; do
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"

        local -a latest_backup
        latest_backup=( "${dst}.backup."*(N^/om[1]) )

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
        print -P "%F{34}Node.js 開発環境の設定を削除しました。%f"
    else
        print -P "情報: Node.js 開発環境の復元・削除対象はありませんでした。"
    fi

    print -P ""
    print -P "NOTE: fnm 本体と Node.js バージョンは削除されていません。不要な場合は以下を手動で削除してください:"
    local os
    os=$(_node_detect_os)
    case "$os" in
        macos)
            print -P "  brew uninstall fnm"
            ;;
        *)
            print -P "  rm -f ${NODE_MOD_FNM_BIN_DIR}/fnm"
            ;;
    esac
    print -P "  rm -rf ${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
}
