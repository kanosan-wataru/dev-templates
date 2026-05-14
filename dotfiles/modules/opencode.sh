# ---------------------------------------------
# モジュール: opencode
# SST opencode (AI coding agent) を GitHub Releases から単一バイナリで導入
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="opencode"
MODULE_NAME="opencode"
MODULE_DESC="SST opencode (AI coding agent, 単一バイナリ)"
MODULE_DEFAULT=0
MODULE_ORDER=33
MODULE_DEPS=""

# NOTE: モジュール固有の変数には衝突回避のため OPENCODE_MOD_ プレフィックスを使用
OPENCODE_MOD_BIN_DIR="$HOME/.local/bin"
OPENCODE_MOD_BIN_PATH="$OPENCODE_MOD_BIN_DIR/opencode"
OPENCODE_MOD_REPO="sst/opencode"

# OPENCODE_VERSION 環境変数で固定可能 (例: v1.14.49)。空なら最新リリース
OPENCODE_MOD_VERSION="${OPENCODE_VERSION:-}"
OPENCODE_MOD_VERSION="${OPENCODE_MOD_VERSION#"${OPENCODE_MOD_VERSION%%[![:space:]]*}"}"
OPENCODE_MOD_VERSION="${OPENCODE_MOD_VERSION%"${OPENCODE_MOD_VERSION##*[![:space:]]}"}"

# 値検証: パストラバーサル / コマンドインジェクション防止
# pre-release タグ (v1.0.0-rc.1, v1.0.0-beta.2) も許容しつつ ".." 含む値は明示的に弾く
if [[ -n "$OPENCODE_MOD_VERSION" ]]; then
    if [[ "$OPENCODE_MOD_VERSION" == *..* ]] || [[ ! "$OPENCODE_MOD_VERSION" =~ ^v?[0-9]+(\.[0-9]+)*(-[0-9A-Za-z.]+)?$ ]]; then
        printf 'ERROR: OPENCODE_VERSION の形式が不正です: %q (例: v1.14.49, v1.0.0-rc.1)\n' "$OPENCODE_MOD_VERSION" >&2
        return 1 2>/dev/null || exit 1
    fi
fi

# --- ヘルパー: OS 判定 ---
_opencode_detect_os() {
    case "$OSTYPE" in
    darwin*) printf '%s' "macos" ;;
    linux*) printf '%s' "linux" ;;
    *) printf '%s' "unknown" ;;
    esac
}

# --- ヘルパー: アセット名判定 ---
# NOTE: opencode の Linux/macOS 用アセット命名規則
#   linux  x86_64  -> opencode-linux-x64.tar.gz
#   linux  aarch64 -> opencode-linux-arm64.tar.gz
#   darwin x86_64  -> opencode-darwin-x64.zip
#   darwin arm64   -> opencode-darwin-arm64.zip
_opencode_asset_name() {
    local os="$1"
    local arch
    arch="$(uname -m)"
    case "$os" in
    linux)
        case "$arch" in
        x86_64) printf '%s' "opencode-linux-x64.tar.gz" ;;
        aarch64 | arm64) printf '%s' "opencode-linux-arm64.tar.gz" ;;
        *) printf '%s' "" ;;
        esac
        ;;
    macos)
        case "$arch" in
        x86_64) printf '%s' "opencode-darwin-x64.zip" ;;
        aarch64 | arm64) printf '%s' "opencode-darwin-arm64.zip" ;;
        *) printf '%s' "" ;;
        esac
        ;;
    *) printf '%s' "" ;;
    esac
}

# --- ヘルパー: ダウンロード URL 生成 ---
_opencode_download_url() {
    local asset="$1"
    if [[ -n "$OPENCODE_MOD_VERSION" ]]; then
        printf '%s' "https://github.com/${OPENCODE_MOD_REPO}/releases/download/${OPENCODE_MOD_VERSION}/${asset}"
    else
        printf '%s' "https://github.com/${OPENCODE_MOD_REPO}/releases/latest/download/${asset}"
    fi
}

# --- ヘルパー: ダウンロード〜配置 (サブシェルでスコープを閉じる) ---
# サブシェル `( ... )` でラップすることで EXIT trap が親シェルに漏れない
_opencode_fetch_and_install() (
    local download_url="$1"
    local asset="$2"

    local tmp_dir
    tmp_dir=$(mktemp -d /tmp/opencode-XXXXXXXXXX) || {
        msg_error "一時ディレクトリの作成に失敗しました。"
        return 1
    }
    # サブシェル内なので EXIT trap でこのサブシェル終了時のみ発火する
    # shellcheck disable=SC2064 # 即時展開で tmp_dir を埋め込む
    trap "rm -rf '$tmp_dir'" EXIT

    local archive_path="${tmp_dir}/${asset}"
    local curl_err="${tmp_dir}/curl.err"

    if ! curl -fsSL "$download_url" -o "$archive_path" 2>"$curl_err"; then
        msg_error "opencode のダウンロードに失敗しました。"
        printf '  URL: %s\n' "$download_url" >&2
        if [[ -s "$curl_err" ]]; then
            printf '  curl stderr: ' >&2
            cat "$curl_err" >&2
        fi
        return 1
    fi

    # 展開前にアーカイブエントリを検証 (絶対パス / 親ディレクトリ参照を含むものを拒否)
    # NOTE: GitHub Releases は信頼境界だが、リリース侵害時の zip-slip / tar-slip 攻撃を緩和する
    if [[ "$asset" == *.tar.gz ]]; then
        if tar -tzf "$archive_path" 2>/dev/null | grep -qE '^/|(^|/)\.\.(/|$)'; then
            msg_error "アーカイブに不正なパス (絶対パスまたは ..) が含まれています。中断します。"
            return 1
        fi
        tar -xzf "$archive_path" -C "$tmp_dir" --no-same-owner --no-same-permissions || {
            msg_error "opencode の展開に失敗しました (tar)。"
            return 1
        }
    else
        if unzip -Z1 "$archive_path" 2>/dev/null | grep -qE '^/|(^|/)\.\.(/|$)'; then
            msg_error "アーカイブに不正なパス (絶対パスまたは ..) が含まれています。中断します。"
            return 1
        fi
        unzip -oq "$archive_path" -d "$tmp_dir" || {
            msg_error "opencode の展開に失敗しました (unzip)。"
            return 1
        }
    fi

    # 展開済みバイナリを検索 (アーカイブ構造の差異を吸収)
    local extracted
    extracted=$(find "$tmp_dir" -type f -name opencode -perm -u+x 2>/dev/null | head -1)
    if [[ -z "$extracted" ]]; then
        # 実行権限が落ちている場合のフォールバック
        extracted=$(find "$tmp_dir" -type f -name opencode 2>/dev/null | head -1)
    fi
    if [[ -z "$extracted" ]]; then
        msg_error "展開したアーカイブに opencode バイナリが見つかりません。"
        return 1
    fi

    install -m 0755 "$extracted" "$OPENCODE_MOD_BIN_PATH" || {
        msg_error "opencode の配置に失敗しました。"
        return 1
    }
)

# --- セットアップ ---
setup_opencode() {
    msg_header "opencode"
    print_separator

    # べき等性チェック
    if command -v opencode >/dev/null 2>&1 && ! ((UPGRADE)); then
        local current_ver
        current_ver=$(opencode --version 2>/dev/null | head -1 || printf '%s' "unknown")
        msg_info "opencode は既にインストールされています (${current_ver})。スキップします。"
        return 0
    fi

    if command -v opencode >/dev/null 2>&1 && ((UPGRADE)); then
        msg_info "opencode のアップグレードを実行します... (現在: $(opencode --version 2>/dev/null | head -1 || echo 'unknown'))"
    fi

    local os
    os=$(_opencode_detect_os)
    if [[ "$os" == "unknown" ]]; then
        msg_error "未対応の OS です (OSTYPE=${OSTYPE})。"
        return 1
    fi

    local asset
    asset=$(_opencode_asset_name "$os")
    if [[ -z "$asset" ]]; then
        msg_error "未対応のアーキテクチャです (os=${os}, arch=$(uname -m))。"
        return 1
    fi

    local download_url
    download_url=$(_opencode_download_url "$asset")

    # 依存コマンド確認
    local -a missing_cmds=()
    for cmd in curl tar unzip; do
        # tar は Linux アセット, unzip は macOS アセットでのみ必要
        case "$asset" in
        *.tar.gz)
            [[ "$cmd" == "unzip" ]] && continue
            ;;
        *.zip)
            [[ "$cmd" == "tar" ]] && continue
            ;;
        esac
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_cmds+=("$cmd")
        fi
    done
    if ((${#missing_cmds[@]} > 0)); then
        msg_info "${missing_cmds[*]} をインストールします..."
        if command -v apt-get >/dev/null 2>&1; then
            run_cmd sudo apt-get update -qq || msg_warn "apt update に失敗しました。"
            run_cmd sudo apt-get install -y "${missing_cmds[@]}" || {
                msg_error "${missing_cmds[*]} のインストールに失敗しました。"
                return 1
            }
        else
            msg_error "${missing_cmds[*]} がインストールされていません。手動でインストールしてください。"
            return 1
        fi
    fi

    # バイナリ配置先ディレクトリ作成
    if [[ ! -d "$OPENCODE_MOD_BIN_DIR" ]]; then
        run_cmd command mkdir -p "$OPENCODE_MOD_BIN_DIR" || {
            msg_error "${OPENCODE_MOD_BIN_DIR} の作成に失敗しました。"
            return 1
        }
    fi

    msg_info "opencode を GitHub Releases からダウンロードします (${asset})..."

    if ((DRY_RUN)); then
        msg_dry_run "curl -fsSL ${download_url} -o /tmp/${asset}"
        if [[ "$asset" == *.tar.gz ]]; then
            msg_dry_run "tar -xzf /tmp/${asset} -C <tmpdir>"
        else
            msg_dry_run "unzip -o /tmp/${asset} -d <tmpdir>"
        fi
        msg_dry_run "install -m 0755 <tmpdir>/opencode ${OPENCODE_MOD_BIN_PATH}"
    else
        # DL〜配置をサブシェルに閉じ込めて trap EXIT をローカルにスコープする
        # (親シェルの RETURN trap を汚染しないため Copilot の指摘 #1 対策)
        if ! _opencode_fetch_and_install "$download_url" "$asset"; then
            return 1
        fi
    fi

    # PATH 通過確認 (zsh モジュールが ~/.local/bin を追加しているはず)
    if ! ((DRY_RUN)); then
        hash -r
        if ! command -v opencode >/dev/null 2>&1; then
            msg_warn "opencode を配置しましたが PATH に \$HOME/.local/bin が含まれていません。"
            msg_step "次回シェル起動時に有効化されます (zsh モジュール経由)。" >&2
        fi
    fi

    if ((DRY_RUN)); then
        msg_info "opencode をインストール予定です（dry-run）。"
    else
        msg_success "opencode のインストールが完了しました。"
        if command -v opencode >/dev/null 2>&1; then
            msg_step "$(opencode --version 2>/dev/null | head -1 || printf '%s' 'バージョン不明')"
        fi
        printf '\n'
        printf '%s\n' "初回セットアップ:"
        msg_step "opencode auth login   # プロバイダ (Anthropic, OpenAI, ...) を設定"
        msg_step "opencode              # 対話的に使用開始"
        msg_step "詳細: https://opencode.ai/"
    fi
}

# --- ステータス表示 ---
module_status() {
    if command -v opencode >/dev/null 2>&1; then
        local version
        version=$(opencode --version 2>/dev/null | head -1 || printf '%s' "installed")
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "$version"
    else
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
    fi
}

# --- アンインストール ---
uninstall_opencode() {
    if [[ ! -e "$OPENCODE_MOD_BIN_PATH" ]] && ! command -v opencode >/dev/null 2>&1; then
        msg_info "opencode はインストールされていません。スキップします。"
        return 0
    fi

    if [[ -e "$OPENCODE_MOD_BIN_PATH" ]]; then
        msg_info "opencode バイナリを削除します..."
        run_cmd command rm -f "$OPENCODE_MOD_BIN_PATH" || {
            msg_error "opencode の削除に失敗しました。"
            return 1
        }
        msg_success "opencode をアンインストールしました。"
    else
        msg_warn "opencode コマンドは見つかりますが ${OPENCODE_MOD_BIN_PATH} には存在しません。手動で削除してください。"
    fi

    # ユーザーデータも完全削除する (認証トークン / 履歴 DB / プラグイン / キャッシュ)
    # 安全のため $HOME 配下のパスのみ対象 (環境変数の差し替えによる事故防止)
    local -a opencode_data_dirs=(
        "${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
        "${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
        "${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
    )
    local data_dir
    for data_dir in "${opencode_data_dirs[@]}"; do
        [[ -e "$data_dir" ]] || continue
        # 防御: $HOME 配下でない場合はスキップ (XDG_* が異常な値だった場合の事故防止)
        if [[ "$data_dir" != "$HOME"/* ]]; then
            msg_warn "${data_dir} は \$HOME 配下ではないため削除をスキップします。"
            continue
        fi
        msg_info "${data_dir} を削除します..."
        run_cmd command rm -rf "$data_dir" || {
            msg_warn "${data_dir} の削除に失敗しました。"
        }
    done
}
