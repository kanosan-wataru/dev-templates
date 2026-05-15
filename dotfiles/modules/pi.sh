# ---------------------------------------------
# モジュール: pi
# earendil-works/pi (AI coding agent) を GitHub Releases から単一バイナリで導入
#
# 配置方針:
#   pi の Bun コンパイル済みバイナリは package.json / WASM / theme / assets と同居する
#   必要があるため、libdir (~/.local/share/pi) にアーカイブ全体を展開し、
#   bin (~/.local/bin/pi) からシンボリックリンクを張る。
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="pi"
MODULE_NAME="pi"
MODULE_DESC="earendil-works/pi (AI coding agent, Bun 単一バイナリ)"
MODULE_DEFAULT=0
MODULE_ORDER=34
MODULE_DEPS=""

# NOTE: モジュール固有の変数には衝突回避のため PI_MOD_ プレフィックスを使用
PI_MOD_BIN_DIR="$HOME/.local/bin"
PI_MOD_BIN_PATH="$PI_MOD_BIN_DIR/pi"
PI_MOD_LIB_DIR="$HOME/.local/share/pi"
PI_MOD_LIB_BIN="$PI_MOD_LIB_DIR/pi"
PI_MOD_REPO="earendil-works/pi"

# PI_VERSION 環境変数で固定可能 (例: v0.74.0)。空なら最新リリース
PI_MOD_VERSION="${PI_VERSION:-}"
PI_MOD_VERSION="${PI_MOD_VERSION#"${PI_MOD_VERSION%%[![:space:]]*}"}"
PI_MOD_VERSION="${PI_MOD_VERSION%"${PI_MOD_VERSION##*[![:space:]]}"}"

# 値検証: パストラバーサル / コマンドインジェクション防止
# pre-release タグ (v0.74.0-rc.1, v0.74.0-beta.2) も許容しつつ ".." 含む値は明示的に弾く
if [[ -n "$PI_MOD_VERSION" ]]; then
    if [[ "$PI_MOD_VERSION" == *..* ]] || [[ ! "$PI_MOD_VERSION" =~ ^v?[0-9]+(\.[0-9]+)*(-[0-9A-Za-z.]+)?$ ]]; then
        printf 'ERROR: PI_VERSION の形式が不正です: %q (例: v0.74.0, v0.74.0-rc.1)\n' "$PI_MOD_VERSION" >&2
        return 1 2>/dev/null || exit 1
    fi
fi

# --- ヘルパー: OS 判定 ---
_pi_detect_os() {
    case "$OSTYPE" in
    darwin*) printf '%s' "darwin" ;;
    linux*) printf '%s' "linux" ;;
    *) printf '%s' "unknown" ;;
    esac
}

# --- ヘルパー: アセット名判定 ---
# NOTE: pi の Linux/macOS 用アセット命名規則 (すべて tar.gz)
#   linux  x86_64  -> pi-linux-x64.tar.gz
#   linux  aarch64 -> pi-linux-arm64.tar.gz
#   darwin x86_64  -> pi-darwin-x64.tar.gz
#   darwin arm64   -> pi-darwin-arm64.tar.gz
_pi_asset_name() {
    local os="$1"
    local arch
    arch="$(uname -m)"
    case "$os" in
    linux | darwin)
        case "$arch" in
        x86_64) printf '%s' "pi-${os}-x64.tar.gz" ;;
        aarch64 | arm64) printf '%s' "pi-${os}-arm64.tar.gz" ;;
        *) printf '%s' "" ;;
        esac
        ;;
    *) printf '%s' "" ;;
    esac
}

# --- ヘルパー: ダウンロード URL 生成 ---
_pi_download_url() {
    local asset="$1"
    if [[ -n "$PI_MOD_VERSION" ]]; then
        printf '%s' "https://github.com/${PI_MOD_REPO}/releases/download/${PI_MOD_VERSION}/${asset}"
    else
        printf '%s' "https://github.com/${PI_MOD_REPO}/releases/latest/download/${asset}"
    fi
}

# --- ヘルパー: ダウンロード〜配置 (サブシェルでスコープを閉じる) ---
# サブシェル `( ... )` でラップすることで EXIT trap が親シェルに漏れない
#
# 設計:
#   - 一時ディレクトリは libdir と同一 FS (=$HOME 配下) に作成し cross-FS mv を回避
#   - 旧 libdir は退避 → 新版 mv → 退避削除 という atomic swap で
#     mv 失敗時に旧版を復旧できるようにする (アップグレード時のロバスト性)
_pi_fetch_and_install() (
    local download_url="$1"
    local asset="$2"

    # libdir 親ディレクトリを作成 (一時ディレクトリと最終配置先を同一 FS にするため)
    local lib_parent
    lib_parent="$(dirname "$PI_MOD_LIB_DIR")"
    mkdir -p "$lib_parent" || {
        msg_error "${lib_parent} の作成に失敗しました。"
        return 1
    }

    # 一時ディレクトリは libdir と同じ FS に作成 (Linux tmpfs / Docker overlayfs 等での EXDEV を回避)
    local tmp_dir
    tmp_dir=$(mktemp -d "${lib_parent}/.pi-staging.XXXXXXXXXX") || {
        msg_error "ステージングディレクトリの作成に失敗しました (${lib_parent})。"
        return 1
    }
    # サブシェル内なので EXIT trap でこのサブシェル終了時のみ発火する
    # NOTE: ${var@Q} で安全クォート (Bash 4.4+)。スペース・特殊文字を含むパスでも壊れない
    # shellcheck disable=SC2064 # 即時展開で tmp_dir を埋め込む
    trap "rm -rf -- ${tmp_dir@Q}" EXIT

    local archive_path="${tmp_dir}/${asset}"
    local curl_err="${tmp_dir}/curl.err"

    if ! curl -fsSL "$download_url" -o "$archive_path" 2>"$curl_err"; then
        msg_error "pi のダウンロードに失敗しました。"
        printf '  URL: %s\n' "$download_url" >&2
        if [[ -s "$curl_err" ]]; then
            printf '  curl stderr: ' >&2
            cat "$curl_err" >&2
        fi
        return 1
    fi

    # 展開前にアーカイブエントリを検証 (絶対パス / 親ディレクトリ参照を含むものを拒否)
    # NOTE: GitHub Releases は信頼境界だが、リリース侵害時の tar-slip 攻撃を緩和する
    if tar -tzf "$archive_path" 2>/dev/null | grep -qE '^/|(^|/)\.\.(/|$)'; then
        msg_error "アーカイブに不正なパス (絶対パスまたは ..) が含まれています。中断します。"
        return 1
    fi
    tar -xzf "$archive_path" -C "$tmp_dir" --no-same-owner --no-same-permissions || {
        msg_error "pi の展開に失敗しました (tar)。"
        return 1
    }

    # 展開後の pi バイナリを検出 (-mindepth 2 で tmp_dir 直下を除外)
    # 期待構造: ${tmp_dir}/pi/pi (バイナリ) + ${tmp_dir}/pi/package.json + ...
    local extracted_bin
    extracted_bin=$(find "$tmp_dir" -mindepth 2 -maxdepth 3 -type f -name pi -perm -u+x 2>/dev/null | head -1)
    if [[ -z "$extracted_bin" ]]; then
        extracted_bin=$(find "$tmp_dir" -mindepth 2 -maxdepth 3 -type f -name pi 2>/dev/null | head -1)
    fi
    if [[ -z "$extracted_bin" ]]; then
        msg_error "展開したアーカイブに pi バイナリが見つかりません。"
        return 1
    fi

    local extracted_dir
    extracted_dir=$(dirname "$extracted_bin")

    # 境界チェック: extracted_dir が tmp_dir の真の子孫であることを確認
    # NOTE: tar-slip の regex チェックを補完するもの (シンボリックリンクで tmp 外に逃げる攻撃の検出)
    case "$extracted_dir" in
    "$tmp_dir"/*) ;;
    *)
        msg_error "アーカイブ展開後のパスが一時ディレクトリ外を指しています。中断します。"
        return 1
        ;;
    esac

    # package.json (pi バイナリが必要とする) の存在確認
    if [[ ! -f "${extracted_dir}/package.json" ]]; then
        msg_error "アーカイブ構造が想定外です (package.json が pi バイナリと同居していません)。"
        return 1
    fi

    # 実行権限を mv 前に確保 (TOCTOU 回避: mv 後の chmod 失敗で symlink が壊れた状態になるのを防ぐ)
    chmod 0755 "${extracted_dir}/pi" || {
        msg_error "pi バイナリの実行権限設定に失敗しました。"
        return 1
    }

    # atomic swap で旧版を保護しつつ libdir を入れ替える
    # 手順: 旧版を backup_dir に退避 → 新版を mv → 成功なら backup を削除、失敗なら復旧
    local backup_dir="${PI_MOD_LIB_DIR}.old.$$"
    local has_backup=0
    if [[ -e "$PI_MOD_LIB_DIR" ]]; then
        if ! mv "$PI_MOD_LIB_DIR" "$backup_dir"; then
            msg_error "旧 libdir の退避に失敗しました (${PI_MOD_LIB_DIR} -> ${backup_dir})。"
            return 1
        fi
        has_backup=1
    fi

    if ! mv "$extracted_dir" "$PI_MOD_LIB_DIR"; then
        msg_error "pi の libdir 配置に失敗しました (${PI_MOD_LIB_DIR})。"
        # 旧版を復旧
        if ((has_backup)); then
            if ! mv "$backup_dir" "$PI_MOD_LIB_DIR"; then
                msg_warn "旧 libdir の復旧にも失敗しました。${backup_dir} に旧版が残存しています。手動で復元してください。"
            else
                msg_info "旧 libdir を復旧しました。"
            fi
        fi
        return 1
    fi

    # 旧版バックアップを削除 (ここまで来れば新版が稼働可能)
    if ((has_backup)); then
        rm -rf "$backup_dir" || msg_warn "旧 libdir バックアップ ${backup_dir} の削除に失敗しました (手動削除してください)。"
    fi

    # 配置後にバイナリの存在を再確認してから symlink を張り直す
    if [[ ! -x "$PI_MOD_LIB_BIN" ]]; then
        msg_error "配置後に ${PI_MOD_LIB_BIN} が実行可能ファイルとして見つかりません。"
        return 1
    fi

    # bin に symlink (古いリンク / ファイルがあれば削除してから張り直す)
    rm -f "$PI_MOD_BIN_PATH"
    if ! ln -s "$PI_MOD_LIB_BIN" "$PI_MOD_BIN_PATH"; then
        msg_error "${PI_MOD_BIN_PATH} のシンボリックリンク作成に失敗しました。"
        return 1
    fi
)

# --- セットアップ ---
setup_pi() {
    msg_header "pi"
    print_separator

    # べき等性チェック (libdir のバイナリで判定)
    # NOTE: `pi` は短い汎用名のため command -v ではなく実体パスで判定する
    if [[ -x "$PI_MOD_LIB_BIN" ]] && ! ((UPGRADE)); then
        local current_ver
        current_ver=$("$PI_MOD_LIB_BIN" --version 2>/dev/null | head -1 || printf '%s' "unknown")
        msg_info "pi は既にインストールされています (${current_ver})。スキップします。"
        return 0
    fi

    if [[ -x "$PI_MOD_LIB_BIN" ]] && ((UPGRADE)); then
        msg_info "pi のアップグレードを実行します... (現在: $("$PI_MOD_LIB_BIN" --version 2>/dev/null | head -1 || echo 'unknown'))"
    fi

    local os
    os=$(_pi_detect_os)
    if [[ "$os" == "unknown" ]]; then
        msg_error "未対応の OS です (OSTYPE=${OSTYPE})。"
        return 1
    fi

    local asset
    asset=$(_pi_asset_name "$os")
    if [[ -z "$asset" ]]; then
        msg_error "未対応のアーキテクチャです (os=${os}, arch=$(uname -m))。"
        return 1
    fi

    local download_url
    download_url=$(_pi_download_url "$asset")

    # 依存コマンド確認 (Linux/macOS の pi はすべて tar.gz)
    local -a missing_cmds=()
    for cmd in curl tar; do
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

    # 配置先ディレクトリ作成
    if [[ ! -d "$PI_MOD_BIN_DIR" ]]; then
        run_cmd command mkdir -p "$PI_MOD_BIN_DIR" || {
            msg_error "${PI_MOD_BIN_DIR} の作成に失敗しました。"
            return 1
        }
    fi

    msg_info "pi を GitHub Releases からダウンロードします (${asset})..."

    if ((DRY_RUN)); then
        msg_dry_run "curl -fsSL ${download_url} -o /tmp/${asset}"
        msg_dry_run "tar -xzf /tmp/${asset} -C <tmpdir>"
        msg_dry_run "mv <tmpdir>/pi ${PI_MOD_LIB_DIR}  # libdir 一括配置"
        msg_dry_run "ln -s ${PI_MOD_LIB_BIN} ${PI_MOD_BIN_PATH}"
    else
        if ! _pi_fetch_and_install "$download_url" "$asset"; then
            return 1
        fi
    fi

    # PATH 通過確認 (zsh モジュールが ~/.local/bin を追加しているはず)
    if ! ((DRY_RUN)); then
        hash -r
        if ! command -v pi >/dev/null 2>&1; then
            msg_warn "pi を配置しましたが PATH に \$HOME/.local/bin が含まれていません。"
            msg_step "次回シェル起動時に有効化されます (zsh モジュール経由)。" >&2
        fi
    fi

    if ((DRY_RUN)); then
        msg_info "pi をインストール予定です（dry-run）。"
    else
        msg_success "pi のインストールが完了しました。"
        if [[ -x "$PI_MOD_LIB_BIN" ]]; then
            msg_step "$("$PI_MOD_LIB_BIN" --version 2>/dev/null | head -1 || printf '%s' 'バージョン不明')"
        fi
        printf '\n'
        printf '%s\n' "初回セットアップ:"
        msg_step "pi                    # 対話的に使用開始 (起動時にプロバイダ設定)"
        msg_step "pi --list-models      # 利用可能モデル一覧"
        msg_step "拡張: ~/.pi/agent/extensions/*.ts を配置すると自動読み込み"
        msg_step "詳細: https://pi.dev/"
    fi
}

# --- ステータス表示 ---
module_status() {
    # NOTE: command -v pi は別物 (python pip 等) を拾う可能性があるため、
    # libdir の実体パスを優先確認する
    if [[ -x "$PI_MOD_LIB_BIN" ]]; then
        local version
        version=$("$PI_MOD_LIB_BIN" --version 2>/dev/null | head -1 || printf '%s' "installed")
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "$version"
    else
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
    fi
}

# --- アンインストール ---
uninstall_pi() {
    if [[ ! -e "$PI_MOD_LIB_DIR" ]] && [[ ! -L "$PI_MOD_BIN_PATH" ]] && [[ ! -e "$PI_MOD_BIN_PATH" ]]; then
        msg_info "pi はインストールされていません。スキップします。"
        return 0
    fi

    # bin の symlink / ファイルを削除
    if [[ -L "$PI_MOD_BIN_PATH" ]] || [[ -e "$PI_MOD_BIN_PATH" ]]; then
        msg_info "pi の bin シンボリックリンクを削除します..."
        run_cmd command rm -f "$PI_MOD_BIN_PATH" || {
            msg_warn "${PI_MOD_BIN_PATH} の削除に失敗しました。"
        }
    fi

    # libdir を削除
    if [[ -e "$PI_MOD_LIB_DIR" ]]; then
        # 防御: $HOME 配下でない場合はスキップ
        if [[ "$PI_MOD_LIB_DIR" != "$HOME"/* ]]; then
            msg_warn "${PI_MOD_LIB_DIR} は \$HOME 配下ではないため削除をスキップします。"
        else
            msg_info "pi の libdir (${PI_MOD_LIB_DIR}) を削除します..."
            run_cmd command rm -rf "$PI_MOD_LIB_DIR" || {
                msg_error "${PI_MOD_LIB_DIR} の削除に失敗しました。"
                return 1
            }
        fi
    fi
    msg_success "pi をアンインストールしました。"

    # ユーザーデータも完全削除する (認証トークン / セッション / 拡張 / キャッシュ)
    # NOTE: pi の configDir は ".pi" (固定)。XDG ベースではない点に注意
    local -a pi_data_dirs=(
        "$HOME/.pi"
    )
    local data_dir
    for data_dir in "${pi_data_dirs[@]}"; do
        [[ -e "$data_dir" ]] || continue
        # 防御: $HOME 配下でない場合はスキップ
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
