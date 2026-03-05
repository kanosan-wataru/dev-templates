# ---------------------------------------------
# モジュール: モダン CLI ツール
# eza / bat / fd / ripgrep (Rust 製 CLI)
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="modern-cli"
MODULE_NAME="モダン CLI ツール"
MODULE_DESC="eza / bat / fd / ripgrep"
MODULE_DEFAULT=0
MODULE_ORDER=15

# NOTE: モジュール固有の変数には衝突回避のため MCLI_MOD_ プレフィックスを使用

# ツール定義: "コマンド名|パッケージ名(brew)|パッケージ名(apt)|説明"
# NOTE: apt パッケージ名が空の場合はそのツール固有のインストール処理を使用する
MCLI_MOD_TOOLS=(
    "eza|eza||カラー表示・Git 連携付きファイル一覧"
    "bat|bat|bat|シンタックスハイライト付きファイル表示"
    "fd|fd|fd-find|高速・直感的なファイル検索"
    "rg|ripgrep|ripgrep|超高速テキスト検索"
)

# --- ヘルパー: OS 判定 ---
# 戻り値: "macos" / "linux" / "unknown"
_mcli_detect_os() {
    case "$OSTYPE" in
        darwin*) print "macos" ;;
        linux*)  print "linux" ;;
        *)       print "unknown" ;;
    esac
}

# --- ヘルパー: eza の Linux (Debian/Ubuntu) インストール ---
_mcli_install_eza_apt() {
    # 公式手順: https://github.com/eza-community/eza/blob/main/INSTALL.md
    print -P "  eza の apt リポジトリを設定します..."

    run_cmd sudo mkdir -p /etc/apt/keyrings || {
        print -P "%F{160}エラー: /etc/apt/keyrings の作成に失敗しました。%f" >&2
        return 1
    }

    if (( ! DRY_RUN )); then
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
            | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || {
            print -P "%F{160}エラー: eza の GPG キー取得に失敗しました。%f" >&2
            return 1
        }
        sudo chmod 644 /etc/apt/keyrings/gierens.gpg

        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
            | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null || {
            print -P "%F{160}エラー: eza の apt ソース追加に失敗しました。%f" >&2
            return 1
        }
        sudo chmod 644 /etc/apt/sources.list.d/gierens.list
    else
        print -P "%F{242}  [DRY-RUN] wget ... | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg%f"
        print -P "%F{242}  [DRY-RUN] echo 'deb ...' | sudo tee /etc/apt/sources.list.d/gierens.list%f"
    fi

    run_cmd sudo apt update -qq || {
        print -P "%F{220}警告: apt update に失敗しました。eza のインストールを続行します。%f"
    }
    run_cmd sudo apt install -y eza || {
        print -P "%F{160}エラー: eza のインストールに失敗しました。%f" >&2
        return 1
    }
    return 0
}

# --- セットアップ ---
module_setup() {
    print -P ""
    print -P "%F{36}%B[モダン CLI ツール]%b%f"
    print -P "---------------------------------------------"

    local os
    os=$(_mcli_detect_os)

    # パッケージマネージャーの確認
    case "$os" in
        macos)
            if ! command -v brew >/dev/null 2>&1; then
                print -P "%F{160}エラー: Homebrew がインストールされていません。%f" >&2
                print -P "  インストール: https://brew.sh/" >&2
                return 1
            fi
            ;;
        linux)
            if ! command -v apt >/dev/null 2>&1; then
                print -P "%F{160}エラー: apt が見つかりません。Debian/Ubuntu 系のみ対応しています。%f" >&2
                return 1
            fi
            ;;
        *)
            print -P "%F{160}エラー: 未対応の OS です (OSTYPE=${OSTYPE})。%f" >&2
            return 1
            ;;
    esac

    typeset -i installed=0 skipped=0 failed=0

    for tool_entry in "${MCLI_MOD_TOOLS[@]}"; do
        local cmd_name="${tool_entry[(ws:|:)1]}"
        local brew_pkg="${tool_entry[(ws:|:)2]}"
        local apt_pkg="${tool_entry[(ws:|:)3]}"
        local desc="${tool_entry[(ws:|:)4]}"

        # Ubuntu の別名バイナリも確認（batcat, fdfind）
        local alt_cmd=""
        [[ "$cmd_name" == "bat" ]] && alt_cmd="batcat"
        [[ "$cmd_name" == "fd" ]] && alt_cmd="fdfind"

        # べき等性チェック
        if command -v "$cmd_name" >/dev/null 2>&1; then
            print -P "情報: ${cmd_name} は既にインストールされています。スキップします。"
            (( skipped++ ))
            continue
        fi
        if [[ -n "$alt_cmd" ]] && command -v "$alt_cmd" >/dev/null 2>&1; then
            print -P "情報: ${alt_cmd} (${cmd_name}) は既にインストールされています。スキップします。"
            (( skipped++ ))
            continue
        fi

        print -P "${cmd_name} をインストールします... (${desc})"

        case "$os" in
            macos)
                run_cmd brew install "$brew_pkg" || {
                    print -P "%F{160}エラー: ${cmd_name} のインストールに失敗しました。%f" >&2
                    (( failed++ ))
                    continue
                }
                ;;
            linux)
                if [[ "$cmd_name" == "eza" ]]; then
                    # eza は公式 apt リポジトリの追加が必要
                    _mcli_install_eza_apt || {
                        (( failed++ ))
                        continue
                    }
                else
                    run_cmd sudo apt install -y "$apt_pkg" || {
                        print -P "%F{160}エラー: ${cmd_name} (${apt_pkg}) のインストールに失敗しました。%f" >&2
                        (( failed++ ))
                        continue
                    }
                fi
                ;;
        esac

        (( installed++ ))
    done

    # サマリー表示
    print -P ""
    if (( failed > 0 )); then
        print -P "%F{220}モダン CLI ツール: ${installed} 件インストール, ${skipped} 件スキップ, %F{160}${failed} 件失敗%f"
        return 1
    elif (( DRY_RUN )); then
        print -P "情報: モダン CLI ツールをインストール予定です（dry-run）。"
    else
        print -P "%F{34}モダン CLI ツール: ${installed} 件インストール, ${skipped} 件スキップ%f"
        if (( installed > 0 )); then
            print -P ""
            print -P "エイリアス設定は aliases.zsh に含まれています。"
            print -P "シェルを再起動すると自動的に有効になります。"
        fi
    fi
}

# --- アンインストール ---
module_uninstall() {
    print -P "モダン CLI ツールのアンインストール手順:"
    print -P ""

    local os
    os=$(_mcli_detect_os)

    case "$os" in
        macos)
            print -P "  brew uninstall eza bat fd ripgrep"
            ;;
        linux)
            print -P "  sudo apt remove eza bat fd-find ripgrep"
            print -P "  # eza の apt ソースも削除する場合:"
            print -P "  sudo rm -f /etc/apt/sources.list.d/gierens.list"
            print -P "  sudo rm -f /etc/apt/keyrings/gierens.gpg"
            ;;
        *)
            print -P "  OS に応じたパッケージマネージャーで削除してください。"
            ;;
    esac
}
