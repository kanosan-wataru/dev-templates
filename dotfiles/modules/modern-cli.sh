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
    darwin*) printf '%s' "macos" ;;
    linux*) printf '%s' "linux" ;;
    *) printf '%s' "unknown" ;;
    esac
}

# --- ヘルパー: eza の Linux (Debian/Ubuntu) インストール ---
# NOTE: DRY_RUN 時はパイプライン処理をスキップし、プレビュー表示のみ行う
_mcli_install_eza_apt() {
    # 公式手順: https://github.com/eza-community/eza/blob/main/INSTALL.md
    msg_step "eza の apt リポジトリを設定します..."

    # 前提コマンドの確認
    if ! command -v wget >/dev/null 2>&1; then
        msg_error "wget がインストールされていません。"
        msg_step "sudo apt-get install wget で先にインストールしてください。" >&2
        return 1
    fi
    if ! command -v gpg >/dev/null 2>&1; then
        msg_error "gpg がインストールされていません。"
        msg_step "sudo apt-get install gnupg で先にインストールしてください。" >&2
        return 1
    fi

    run_cmd sudo mkdir -p /etc/apt/keyrings || {
        msg_error "/etc/apt/keyrings の作成に失敗しました。"
        return 1
    }

    if ((!DRY_RUN)); then
        # GPG キーのダウンロードと変換を分離して個別にエラーチェック
        local tmp_key
        tmp_key=$(mktemp) || {
            msg_error "一時ファイルの作成に失敗しました。"
            return 1
        }

        if ! wget -qO "$tmp_key" https://raw.githubusercontent.com/eza-community/eza/main/deb.asc; then
            msg_error "eza の GPG キーのダウンロードに失敗しました。"
            msg_step "ネットワーク接続と URL の有効性を確認してください。" >&2
            rm -f "$tmp_key"
            return 1
        fi

        # 既存キーファイルがあれば事前に削除（再実行時のべき等性）
        [[ -f /etc/apt/keyrings/eza.gpg ]] && sudo rm -f /etc/apt/keyrings/eza.gpg

        local gpg_err
        gpg_err=$(sudo gpg --dearmor -o /etc/apt/keyrings/eza.gpg "$tmp_key" 2>&1) || {
            msg_error "eza の GPG キー変換に失敗しました。"
            [[ -n "$gpg_err" ]] && msg_step "詳細: ${gpg_err}" >&2
            rm -f "$tmp_key"
            return 1
        }
        rm -f "$tmp_key"

        run_cmd sudo chmod 644 /etc/apt/keyrings/eza.gpg || {
            msg_error "GPG キーファイルの権限設定に失敗しました。"
            return 1
        }

        # apt ソースの追加
        # NOTE: 公式リポジトリが HTTPS 未提供のため http を使用（GPG 署名で検証済み）
        printf '%s\n' "deb [signed-by=/etc/apt/keyrings/eza.gpg] http://deb.gierens.de stable main" |
            sudo tee /etc/apt/sources.list.d/eza.list >/dev/null || {
            msg_error "eza の apt ソース追加に失敗しました。"
            return 1
        }
        run_cmd sudo chmod 644 /etc/apt/sources.list.d/eza.list || {
            msg_error "apt ソースファイルの権限設定に失敗しました。"
            return 1
        }
    else
        msg_dry_run "wget -qO /tmp/... https://...eza.../deb.asc"
        msg_dry_run "sudo gpg --dearmor -o /etc/apt/keyrings/eza.gpg /tmp/..."
        msg_dry_run "sudo chmod 644 /etc/apt/keyrings/eza.gpg"
        msg_dry_run "echo 'deb ...' | sudo tee /etc/apt/sources.list.d/eza.list"
        msg_dry_run "sudo chmod 644 /etc/apt/sources.list.d/eza.list"
    fi

    run_cmd sudo apt-get update -qq || {
        msg_warn "apt update に失敗しました。"
        msg_step "新しい apt リポジトリの情報を取得できなかったため、eza のインストールに失敗する可能性があります。"
    }
    run_cmd sudo apt-get install -y eza || {
        msg_error "eza のインストールに失敗しました。"
        return 1
    }
}

# --- セットアップ ---
setup_modern_cli() {
    msg_header "モダン CLI ツール"
    print_separator

    local os
    os=$(_mcli_detect_os)

    # パッケージマネージャーの確認
    case "$os" in
    macos)
        if ! command -v brew >/dev/null 2>&1; then
            msg_error "Homebrew がインストールされていません。"
            msg_step "インストール: https://brew.sh/" >&2
            return 1
        fi
        ;;
    linux)
        if ! command -v apt-get >/dev/null 2>&1; then
            msg_error "apt-get が見つかりません。Debian/Ubuntu 系のみ対応しています。"
            return 1
        fi
        ;;
    *)
        msg_error "未対応の OS です (OSTYPE=${OSTYPE})。"
        return 1
        ;;
    esac

    declare -i installed=0 skipped=0 failed=0

    for tool_entry in "${MCLI_MOD_TOOLS[@]}"; do
        IFS='|' read -r cmd_name brew_pkg apt_pkg desc <<<"$tool_entry"

        # Ubuntu の別名バイナリも確認（batcat, fdfind）
        local alt_cmd=""
        [[ "$cmd_name" == "bat" ]] && alt_cmd="batcat"
        [[ "$cmd_name" == "fd" ]] && alt_cmd="fdfind"

        # べき等性チェック
        if command -v "$cmd_name" >/dev/null 2>&1; then
            msg_info "${cmd_name} は既にインストールされています。スキップします。"
            ((skipped++))
            continue
        fi
        if [[ -n "$alt_cmd" ]] && command -v "$alt_cmd" >/dev/null 2>&1; then
            msg_info "${alt_cmd} (${cmd_name}) は既にインストールされています。スキップします。"
            ((skipped++))
            continue
        fi

        printf '%s\n' "${cmd_name} をインストールします... (${desc})"

        case "$os" in
        macos)
            run_cmd brew install "$brew_pkg" || {
                msg_error "${cmd_name} のインストールに失敗しました。"
                ((failed++))
                continue
            }
            ;;
        linux)
            if [[ "$cmd_name" == "eza" ]]; then
                # eza は公式 apt リポジトリの追加が必要
                _mcli_install_eza_apt || {
                    ((failed++))
                    continue
                }
            else
                run_cmd sudo apt-get install -y "$apt_pkg" || {
                    msg_error "${cmd_name} (${apt_pkg}) のインストールに失敗しました。"
                    ((failed++))
                    continue
                }
            fi
            ;;
        esac

        ((installed++))
    done

    # サマリー表示
    printf '\n'
    if ((failed > 0)); then
        msg_warn "モダン CLI ツール: ${installed} 件インストール, ${skipped} 件スキップ, ${failed} 件失敗"
        return 1
    elif ((DRY_RUN)); then
        msg_info "モダン CLI ツールをインストール予定です（dry-run）。"
    else
        msg_success "モダン CLI ツール: ${installed} 件インストール, ${skipped} 件スキップ"
        if ((installed > 0)); then
            printf '\n'
            printf '%s\n' "エイリアス設定は aliases.zsh に含まれています。"
            printf '%s\n' "シェルを再起動すると自動的に有効になります。"
        fi
    fi
}

# --- アンインストール ---
# NOTE: システムパッケージの自動削除は意図しない依存破壊のリスクがあるため、手順の表示のみとする
uninstall_modern_cli() {
    printf '%s\n' "モダン CLI ツールのアンインストール手順:"
    printf '\n'

    local os
    os=$(_mcli_detect_os)

    case "$os" in
    macos)
        msg_step "brew uninstall eza bat fd ripgrep"
        ;;
    linux)
        msg_step "sudo apt-get remove eza bat fd-find ripgrep"
        msg_step "# eza の apt ソースも削除する場合:"
        msg_step "sudo rm -f /etc/apt/sources.list.d/eza.list"
        msg_step "sudo rm -f /etc/apt/keyrings/eza.gpg"
        ;;
    *)
        msg_step "OS に応じたパッケージマネージャーで削除してください。"
        ;;
    esac
}
