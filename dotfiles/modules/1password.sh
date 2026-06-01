# ---------------------------------------------
# モジュール: 1Password
# CLI + SSH エージェント + Git 署名設定
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="1password"
MODULE_NAME="1Password"
MODULE_DESC="CLI + SSH エージェント + Git 署名"
MODULE_DEFAULT=0
MODULE_ORDER=13

# NOTE: モジュール固有の変数には衝突回避のため OP_MOD_ プレフィックスを使用
OP_MOD_DEBSIG_KEY_ID="AC2D62742012EA22"
OP_MOD_TOKEN_DIR="${HOME}/.config/op"
OP_MOD_TOKEN_FILE="${OP_MOD_TOKEN_DIR}/.env"

# --- npiperelay (WSL SSH エージェントブリッジ用) ---
# WSL では Windows 側 1Password の SSH エージェント (名前付きパイプ
# //./pipe/openssh-ssh-agent) を npiperelay + socat で WSL の UNIX ソケットへ
# ブリッジする。これによりネイティブ WSL の ssh/git/scp/rsync が 1Password を使える。
# バージョンは固定し、ダウンロード成果物は SHA256 で検証する。
OP_MOD_NPIPERELAY_REPO="jstarks/npiperelay"
OP_MOD_NPIPERELAY_VERSION="v0.1.0"
OP_MOD_NPIPERELAY_BIN_DIR="${HOME}/.local/bin"
OP_MOD_NPIPERELAY_BIN_PATH="${OP_MOD_NPIPERELAY_BIN_DIR}/npiperelay.exe"
# v0.1.0 amd64 アセットの SHA256 (公式 checksums.txt より)
OP_MOD_NPIPERELAY_SHA256_AMD64="6b9ef61ffd17c03507a9a3d54d815dceb3dae669ac67fc3bf4225d1e764ce5f6"

# 管理対象ファイル（配布元パス, 配置先パス, 表示名, 未検出時メッセージ）
OP_MOD_MANAGED_FILES=(
    "$SCRIPT_DIR/.shell/1password.sh|$HOME/.shell/1password.sh|1password.sh|"
)

# --- ヘルパー: 環境判定 ---
# 戻り値: "wsl" / "linux" / "macos" / "unknown"
_1password_detect_env() {
    case "$OSTYPE" in
    darwin*)
        printf '%s' "macos"
        ;;
    linux*)
        if [[ -f /proc/version ]] && grep -qi 'microsoft' /proc/version 2>/dev/null; then
            printf '%s' "wsl"
        else
            printf '%s' "linux"
        fi
        ;;
    *)
        printf '%s' "unknown"
        ;;
    esac
}

# --- ヘルパー: op CLI のインストール (Ubuntu/Debian) ---
_1password_install_op_apt() {
    msg_step "1Password CLI の apt リポジトリを設定します..."

    # 前提コマンドの確認
    local -a required_cmds=(curl gpg)
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            msg_error "${cmd} がインストールされていません。"
            return 1
        fi
    done

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

        if ! curl -sS -o "$tmp_key" https://downloads.1password.com/linux/keys/1password.asc; then
            msg_error "1Password の GPG キー取得に失敗しました。"
            rm -f "$tmp_key"
            return 1
        fi

        # 既存キーファイルがあれば事前に削除（再実行時のべき等性）
        [[ -f /etc/apt/keyrings/1password-archive-keyring.gpg ]] && sudo rm -f /etc/apt/keyrings/1password-archive-keyring.gpg

        sudo gpg --dearmor --output /etc/apt/keyrings/1password-archive-keyring.gpg "$tmp_key" 2>/dev/null || {
            msg_error "GPG キー変換に失敗しました。"
            rm -f "$tmp_key"
            return 1
        }

        # apt ソースの追加
        printf '%s\n' "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" |
            sudo tee /etc/apt/sources.list.d/1password.list >/dev/null || {
            msg_error "1Password の apt ソース追加に失敗しました。"
            rm -f "$tmp_key"
            return 1
        }

        # debsig ポリシーの設定
        run_cmd sudo mkdir -p "/etc/debsig/policies/${OP_MOD_DEBSIG_KEY_ID}/"
        if ! curl -sS -o "$tmp_key" https://downloads.1password.com/linux/debian/debsig/1password.pol; then
            msg_warn "debsig ポリシーのダウンロードに失敗しました（インストールは継続します）。"
        else
            # shellcheck disable=SC2024
            sudo tee /etc/debsig/policies/${OP_MOD_DEBSIG_KEY_ID}/1password.pol <"$tmp_key" >/dev/null || {
                msg_warn "debsig ポリシーの設定に失敗しました（インストールは継続します）。"
            }
        fi

        run_cmd sudo mkdir -p "/usr/share/debsig/keyrings/${OP_MOD_DEBSIG_KEY_ID}"
        [[ -f /usr/share/debsig/keyrings/${OP_MOD_DEBSIG_KEY_ID}/debsig.gpg ]] && sudo rm -f /usr/share/debsig/keyrings/${OP_MOD_DEBSIG_KEY_ID}/debsig.gpg
        if ! curl -sS -o "$tmp_key" https://downloads.1password.com/linux/keys/1password.asc; then
            msg_warn "debsig キーリング用キーの取得に失敗しました（インストールは継続します）。"
        else
            sudo gpg --dearmor --output /usr/share/debsig/keyrings/${OP_MOD_DEBSIG_KEY_ID}/debsig.gpg "$tmp_key" 2>/dev/null || {
                msg_warn "debsig キーリングの設定に失敗しました（インストールは継続します）。"
            }
        fi

        rm -f "$tmp_key"
    else
        msg_dry_run "curl ... | sudo gpg --dearmor -o /etc/apt/keyrings/1password-archive-keyring.gpg"
        msg_dry_run "echo 'deb ...' | sudo tee /etc/apt/sources.list.d/1password.list"
        msg_dry_run "debsig ポリシー設定"
    fi

    run_cmd sudo apt-get update -qq || {
        msg_warn "apt update に失敗しました。"
    }
    run_cmd sudo apt-get install -y 1password-cli || {
        msg_error "1Password CLI のインストールに失敗しました。"
        return 1
    }
}

# --- ヘルパー: op CLI のインストール (macOS) ---
_1password_install_op_brew() {
    if ((UPGRADE)); then
        run_cmd brew upgrade --cask 1password-cli || {
            msg_warn "1Password CLI のアップグレードに失敗しました（既に最新の可能性があります）。"
        }
    else
        run_cmd brew install --cask 1password-cli || {
            msg_error "1Password CLI のインストールに失敗しました。"
            return 1
        }
    fi
}

# --- ヘルパー: npiperelay アセット名判定 (WSL は基本 amd64) ---
_1password_npiperelay_asset() {
    case "$(uname -m)" in
    x86_64 | amd64) printf '%s' "npiperelay_windows_amd64.zip" ;;
    *) printf '%s' "" ;;
    esac
}

# --- ヘルパー: npiperelay アセットの期待 SHA256 ---
_1password_npiperelay_sha256() {
    case "$(uname -m)" in
    x86_64 | amd64) printf '%s' "$OP_MOD_NPIPERELAY_SHA256_AMD64" ;;
    *) printf '%s' "" ;;
    esac
}

# --- ヘルパー: npiperelay ダウンロード URL 生成 (バージョン固定) ---
_1password_npiperelay_url() {
    local asset="$1"
    printf '%s' "https://github.com/${OP_MOD_NPIPERELAY_REPO}/releases/download/${OP_MOD_NPIPERELAY_VERSION}/${asset}"
}

# --- ヘルパー: WSL ブリッジ用の依存 (curl/unzip/socat) を確保 ---
_1password_ensure_wsl_deps() {
    local -a missing=()
    local cmd
    for cmd in curl unzip socat; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    ((${#missing[@]} == 0)) && return 0

    msg_step "WSL ブリッジ用の依存 (${missing[*]}) をインストールします..."
    if ! command -v apt-get >/dev/null 2>&1; then
        msg_error "apt-get が見つかりません。${missing[*]} を手動でインストールしてください。"
        return 1
    fi
    run_cmd sudo apt-get update -qq || msg_warn "apt update に失敗しました。"
    run_cmd sudo apt-get install -y "${missing[@]}" || {
        msg_error "${missing[*]} のインストールに失敗しました。"
        return 1
    }
}

# --- ヘルパー: npiperelay.exe のダウンロード〜配置 (サブシェルでスコープを閉じる) ---
# pi.sh と同じ防御方針: 一時 dir + EXIT trap、SHA256 検証、対象ファイルのみ展開。
_1password_fetch_npiperelay() (
    local url="$1" asset="$2" expected_sha="$3"

    mkdir -p "$OP_MOD_NPIPERELAY_BIN_DIR" || {
        msg_error "${OP_MOD_NPIPERELAY_BIN_DIR} の作成に失敗しました。"
        return 1
    }

    local tmp_dir
    tmp_dir=$(mktemp -d "${OP_MOD_NPIPERELAY_BIN_DIR}/.npiperelay-staging.XXXXXXXXXX") || {
        msg_error "ステージングディレクトリの作成に失敗しました。"
        return 1
    }
    # shellcheck disable=SC2064 # 即時展開で tmp_dir を埋め込む
    trap "rm -rf -- ${tmp_dir@Q}" EXIT

    local archive_path="${tmp_dir}/${asset}"
    local curl_err="${tmp_dir}/curl.err"

    if ! curl -fsSL "$url" -o "$archive_path" 2>"$curl_err"; then
        msg_error "npiperelay のダウンロードに失敗しました。"
        printf '  URL: %s\n' "$url" >&2
        if [[ -s "$curl_err" ]]; then
            printf '  curl stderr: ' >&2
            cat "$curl_err" >&2
        fi
        return 1
    fi

    # SHA256 検証 (リリース侵害 / 改竄の緩和)
    if [[ -n "$expected_sha" ]]; then
        local actual_sha
        actual_sha=$(sha256sum "$archive_path" 2>/dev/null | awk '{print $1}')
        if [[ "$actual_sha" != "$expected_sha" ]]; then
            msg_error "npiperelay のチェックサムが一致しません。中断します。"
            printf '  expected: %s\n  actual:   %s\n' "$expected_sha" "$actual_sha" >&2
            return 1
        fi
    else
        msg_warn "このアーキテクチャ用のチェックサムが未登録です。検証なしで続行します。"
    fi

    # アーカイブに npiperelay.exe が含まれるか確認 (不一致なら unzip は非0)
    if ! unzip -l "$archive_path" 'npiperelay.exe' >/dev/null 2>&1; then
        msg_error "アーカイブに npiperelay.exe が含まれていません。中断します。"
        return 1
    fi

    # アーカイブには LICENSE/README.md 等も含まれるが、対象名 npiperelay.exe の
    # エントリのみ -j (内部パス除去) で展開し path traversal を回避する。
    # zip 全体は SHA256 検証済みのため想定外エントリは混入しない。
    if ! unzip -o -j "$archive_path" 'npiperelay.exe' -d "$tmp_dir" >/dev/null 2>&1; then
        msg_error "npiperelay の展開に失敗しました。"
        return 1
    fi

    local extracted="${tmp_dir}/npiperelay.exe"
    if [[ ! -f "$extracted" ]]; then
        msg_error "展開後に npiperelay.exe が見つかりません。"
        return 1
    fi

    chmod 0755 "$extracted" || {
        msg_error "npiperelay.exe の権限設定に失敗しました。"
        return 1
    }

    # 同一 FS 内の mv で atomic に配置
    if ! mv -f "$extracted" "$OP_MOD_NPIPERELAY_BIN_PATH"; then
        msg_error "${OP_MOD_NPIPERELAY_BIN_PATH} への配置に失敗しました。"
        return 1
    fi
)

# --- ヘルパー: WSL の SSH エージェントブリッジ (npiperelay + socat) をセットアップ ---
_1password_setup_npiperelay_wsl() {
    printf '\n'
    printf '%s\n' "WSL SSH エージェントブリッジ (npiperelay + socat):"

    local asset
    asset=$(_1password_npiperelay_asset)
    if [[ -z "$asset" ]]; then
        msg_warn "未対応のアーキテクチャ ($(uname -m)) のため npiperelay 導入をスキップします。"
        msg_step "ssh.exe エイリアスのフォールバックで動作します。"
        return 0
    fi

    # 依存 (curl / unzip / socat) を確保
    _1password_ensure_wsl_deps || return 1

    # べき等性: 既に配置済みかつ非 UPGRADE ならスキップ
    if [[ -f "$OP_MOD_NPIPERELAY_BIN_PATH" ]] && ! ((UPGRADE)); then
        msg_step "npiperelay は既に配置済みです (${OP_MOD_NPIPERELAY_BIN_PATH})。スキップします。"
        return 0
    fi

    local url sha
    url=$(_1password_npiperelay_url "$asset")
    sha=$(_1password_npiperelay_sha256)

    msg_step "npiperelay ${OP_MOD_NPIPERELAY_VERSION} を取得します (${asset})..."
    if ((DRY_RUN)); then
        msg_dry_run "curl -fsSL ${url} -o <tmp>/${asset}"
        msg_dry_run "sha256 検証 (${sha:0:12}...)"
        msg_dry_run "unzip npiperelay.exe -> ${OP_MOD_NPIPERELAY_BIN_PATH}"
        return 0
    fi

    if ! _1password_fetch_npiperelay "$url" "$asset" "$sha"; then
        return 1
    fi
    msg_step "$(printf '%s%s%s' "${C_GREEN}" "npiperelay を配置しました: ${OP_MOD_NPIPERELAY_BIN_PATH}" "${C_RESET}")"
    msg_step "次回シェル起動時に ~/.shell/1password.sh がブリッジを自動起動します。"
}

# --- ヘルパー: SSH エージェント設定の案内 ---
_1password_setup_ssh_agent() {
    local env="$1"

    printf '\n'
    printf '%s\n' "SSH エージェント設定:"

    case "$env" in
    wsl)
        msg_step "WSL 環境を検出しました。"
        msg_step "Windows 側の 1Password デスクトップアプリで SSH エージェントを有効にしてください。"
        msg_step "  設定 → 開発者 → SSH エージェント → 有効にする"
        msg_step "npiperelay + socat により Windows のエージェントが WSL の ~/.1password/agent.sock へ"
        msg_step "ブリッジされ、ネイティブ WSL の ssh / git / scp / rsync すべてが 1Password 経由になります。"
        msg_step "(npiperelay/socat が無い場合は ssh.exe / ssh-add.exe エイリアスにフォールバックします)"
        printf '\n'
        msg_step "NOTE: 1Password に鍵が多いと SSH 接続時に MaxAuthTries を超過し"
        msg_step "      'Too many authentication failures' になることがあります。その場合は"
        msg_step "      ~/.ssh/config でホストごとに鍵を限定してください:"
        msg_step "        Host myhost"
        msg_step "            IdentitiesOnly yes"
        msg_step "            IdentityFile ~/.ssh/<対象鍵>.pub"
        printf '\n'
        msg_step "有効化:"
        msg_step "  export ENABLE_SSH_1PASSWORD=1  # ~/.zshenv 等に追加"
        ;;
    linux)
        local sock_path="$HOME/.1password/agent.sock"
        msg_step "ネイティブ Linux 環境を検出しました。"
        if [[ -S "$sock_path" ]]; then
            msg_step "$(printf '%s%s%s' "${C_GREEN}" "SSH エージェントソケットが見つかりました。" "${C_RESET}")"
        else
            msg_step "$(printf '%s%s%s' "${C_YELLOW}" "SSH エージェントソケットが見つかりません。" "${C_RESET}")"
            msg_step "1Password デスクトップアプリで SSH エージェントを有効にしてください。"
            msg_step "  設定 → 開発者 → SSH エージェント → 有効にする"
        fi
        printf '\n'
        msg_step "有効化:"
        msg_step "  export ENABLE_SSH_1PASSWORD=1  # ~/.zshenv 等に追加"
        ;;
    macos)
        local sock_path="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        msg_step "macOS 環境を検出しました。"
        if [[ -S "$sock_path" ]]; then
            msg_step "$(printf '%s%s%s' "${C_GREEN}" "SSH エージェントソケットが見つかりました。" "${C_RESET}")"
        else
            msg_step "$(printf '%s%s%s' "${C_YELLOW}" "SSH エージェントソケットが見つかりません。" "${C_RESET}")"
            msg_step "1Password デスクトップアプリで SSH エージェントを有効にしてください。"
            msg_step "  設定 → 開発者 → SSH エージェント → 有効にする"
        fi
        printf '\n'
        msg_step "有効化:"
        msg_step "  export ENABLE_SSH_1PASSWORD=1  # ~/.zshenv 等に追加"
        ;;
    esac
}

# --- ヘルパー: Git コミット署名設定 ---
_1password_setup_git_signing() {
    local env="$1"

    printf '\n'
    printf '%s\n' "Git コミット署名設定:"

    if ! command -v git >/dev/null 2>&1; then
        msg_step "$(printf '%s%s%s' "${C_YELLOW}" "警告: git が見つかりません。Git 署名設定をスキップします。" "${C_RESET}")"
        return 0
    fi

    # 既に gpg.format = ssh が設定されているか確認
    local current_format
    current_format=$(git config --global gpg.format 2>/dev/null || true)
    if [[ "$current_format" == "ssh" ]]; then
        msg_step "情報: gpg.format は既に ssh に設定されています。"
        local current_program
        current_program=$(git config --global gpg.ssh.program 2>/dev/null || true)
        local current_key
        current_key=$(git config --global user.signingkey 2>/dev/null || true)
        local current_sign
        current_sign=$(git config --global commit.gpgsign 2>/dev/null || true)
        [[ -n "$current_program" ]] && msg_step "gpg.ssh.program: ${current_program}"
        [[ -n "$current_key" ]] && msg_step "user.signingkey:  ${current_key}"
        [[ -n "$current_sign" ]] && msg_step "commit.gpgsign:   ${current_sign}"
        return 0
    fi

    # op-ssh-sign のパスを環境に応じて決定
    local sign_program=""
    case "$env" in
    wsl)
        # WSL: Windows ユーザー名を自動検出して op-ssh-sign.exe のパスを決定
        local win_user
        win_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
        if [[ -z "$win_user" ]]; then
            msg_step "$(printf '%s%s%s' "${C_YELLOW}" "警告: Windows ユーザー名を検出できませんでした。" "${C_RESET}")"
            msg_step "手動で設定してください:"
            msg_step "  git config --global gpg.ssh.program '/mnt/c/Users/<ユーザー名>/AppData/Local/1Password/app/8/op-ssh-sign.exe'"
            return 0
        fi
        sign_program="/mnt/c/Users/${win_user}/AppData/Local/1Password/app/8/op-ssh-sign.exe"
        ;;
    linux)
        sign_program="/opt/1Password/op-ssh-sign"
        ;;
    macos)
        sign_program="/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
        ;;
    esac

    # gpg.format と commit.gpgsign を設定
    if ((DRY_RUN)); then
        msg_dry_run "git config --global gpg.format ssh"
        msg_dry_run "git config --global gpg.ssh.program ${sign_program}"
        msg_dry_run "git config --global commit.gpgsign true"
    else
        git config --global gpg.format ssh || {
            msg_error "gpg.format の設定に失敗しました。"
            return 1
        }
        git config --global gpg.ssh.program "$sign_program" || {
            msg_error "gpg.ssh.program の設定に失敗しました。"
            return 1
        }
        git config --global commit.gpgsign true || {
            msg_error "commit.gpgsign の設定に失敗しました。"
            return 1
        }
        msg_step "$(printf '%s%s%s' "${C_GREEN}" "Git 署名設定を適用しました。" "${C_RESET}")"
        msg_step "gpg.format:       ssh"
        msg_step "gpg.ssh.program:  ${sign_program}"
        msg_step "commit.gpgsign:   true"
    fi

    # user.signingkey の案内
    local current_key
    current_key=$(git config --global user.signingkey 2>/dev/null || true)
    if [[ -z "$current_key" ]]; then
        printf '\n'
        msg_step "$(printf '%s%s%s' "${C_YELLOW}" "NOTE: user.signingkey が未設定です。以下を実行してください:" "${C_RESET}")"
        msg_step "  git config --global user.signingkey \"ssh-ed25519 AAAA...\""
        msg_step "1Password → SSH キーの詳細 → 公開鍵をコピーして指定してください。"
    fi
}

# --- Helper: Service account token storage ---
_1password_setup_service_account_token() {
    printf '\n'
    printf '%s\n' "サービスアカウントトークン設定:"

    # Check if token file already exists
    if [[ -f "$OP_MOD_TOKEN_FILE" ]]; then
        msg_step "情報: トークンファイルが既に存在します (${OP_MOD_TOKEN_FILE})。"
        local overwrite
        if ((FORCE)); then
            overwrite="n"
            msg_info "--force: 既存トークンファイルを維持します。"
        else
            printf '  上書きしますか？ [y/N]: '
            read -r overwrite
        fi
        if [[ "$overwrite" != [yY] ]]; then
            msg_step "スキップしました。"
            return 0
        fi
    else
        local configure
        if ((FORCE)); then
            configure="n"
            msg_info "--force: トークン設定をスキップします。"
        else
            printf '  サービスアカウントトークンを設定しますか？ [y/N]: '
            read -r configure
        fi
        if [[ "$configure" != [yY] ]]; then
            msg_step "スキップしました。"
            return 0
        fi
    fi

    # Prompt for token value (silent input)
    printf '  トークンを入力してください: '
    local token
    read -r -s token
    printf '\n' # Newline after silent input

    if [[ -z "$token" ]]; then
        msg_step "$(printf '%s%s%s' "${C_YELLOW}" "警告: トークンが空です。スキップします。" "${C_RESET}")"
        return 0
    fi

    # Validate token characters (allow only safe characters to prevent injection)
    if [[ ! "$token" =~ ^[A-Za-z0-9_+/=.-]+$ ]]; then
        msg_error "トークンに不正な文字が含まれています。"
        return 1
    fi

    # Warn if token seems too short
    if ((${#token} < 10)); then
        msg_warn "トークンが短すぎます。正しい値か確認してください。"
    fi

    # Create directory with restricted permissions
    if [[ ! -d "$OP_MOD_TOKEN_DIR" ]]; then
        if ((DRY_RUN)); then
            msg_dry_run "mkdir -p ${OP_MOD_TOKEN_DIR} && chmod 700 ${OP_MOD_TOKEN_DIR}"
        else
            mkdir -p "$OP_MOD_TOKEN_DIR" || {
                msg_error "${OP_MOD_TOKEN_DIR} の作成に失敗しました。"
                return 1
            }
            chmod 700 "$OP_MOD_TOKEN_DIR" || {
                msg_error "${OP_MOD_TOKEN_DIR} のパーミッション設定に失敗しました。"
                return 1
            }
        fi
    fi

    # Write token file with restricted permissions
    if ((DRY_RUN)); then
        msg_dry_run "トークンを ${OP_MOD_TOKEN_FILE} に保存 (chmod 600)"
    else
        # Write the token file atomically via a temp file
        # Set restrictive umask so mktemp creates files with safe permissions
        local old_umask
        old_umask=$(umask)
        umask 077

        local tmp_file
        tmp_file=$(mktemp "${OP_MOD_TOKEN_DIR}/.token.XXXXXX") || {
            msg_error "一時ファイルの作成に失敗しました。"
            umask "$old_umask"
            return 1
        }

        chmod 600 "$tmp_file" || {
            msg_error "一時ファイルのパーミッション設定に失敗しました。"
            rm -f "$tmp_file"
            umask "$old_umask"
            return 1
        }

        printf "export OP_SERVICE_ACCOUNT_TOKEN='%s'\n" "$token" >"$tmp_file" || {
            msg_error "トークンの書き込みに失敗しました。"
            rm -f "$tmp_file"
            umask "$old_umask"
            return 1
        }

        mv "$tmp_file" "$OP_MOD_TOKEN_FILE" || {
            msg_error "トークンファイルの配置に失敗しました。"
            rm -f "$tmp_file"
            umask "$old_umask"
            return 1
        }

        umask "$old_umask"

        msg_step "$(printf '%s%s%s' "${C_GREEN}" "トークンを保存しました: ${OP_MOD_TOKEN_FILE}" "${C_RESET}")"
    fi
}

# --- セットアップ ---
setup_1password() {
    msg_header "1Password"
    print_separator

    local env
    env=$(_1password_detect_env)

    case "$env" in
    wsl) msg_info "環境を検出しました — WSL" ;;
    linux) msg_info "環境を検出しました — ネイティブ Linux" ;;
    macos) msg_info "環境を検出しました — macOS" ;;
    *)
        msg_error "未対応の OS です (OSTYPE=${OSTYPE})。"
        return 1
        ;;
    esac

    # --- 1. op CLI のインストール ---
    if command -v op >/dev/null 2>&1 && ! ((UPGRADE)); then
        msg_info "op CLI は既にインストールされています ($(op --version 2>/dev/null || echo '不明'))。スキップします。"
    else
        if command -v op >/dev/null 2>&1 && ((UPGRADE)); then
            msg_info "1password-cli のアップグレードを実行します... (現在: $(op --version 2>/dev/null || echo 'unknown'))"
        fi
        msg_info "1Password CLI (op) をインストールします..."
        case "$env" in
        wsl | linux)
            if ! command -v apt-get >/dev/null 2>&1; then
                msg_error "apt-get が見つかりません。Debian/Ubuntu 系のみ対応しています。"
                return 1
            fi
            _1password_install_op_apt || return 1
            ;;
        macos)
            if ! command -v brew >/dev/null 2>&1; then
                msg_error "Homebrew がインストールされていません。"
                msg_step "インストール: https://brew.sh/" >&2
                return 1
            fi
            _1password_install_op_brew || return 1
            ;;
        esac

        if ((!DRY_RUN)); then
            if command -v op >/dev/null 2>&1; then
                msg_step "$(printf '%s%s%s' "${C_GREEN}" "op CLI のインストールが完了しました ($(op --version 2>/dev/null))。" "${C_RESET}")"
            else
                msg_error "op CLI のインストール後にコマンドが見つかりません。"
                return 1
            fi
        fi
    fi

    # --- 2. 設定ファイルの配置 ---
    printf '\n'
    msg_info "設定ファイルを配置します..."
    run_cmd mkdir -p "$HOME/.shell"
    for entry in "${OP_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r src dst label hint <<<"$entry"
        install_config "$src" "$dst" "$label" "$hint"
    done

    # --- 2.5. WSL: SSH エージェントブリッジ (npiperelay + socat) を導入 ---
    if [[ "$env" == "wsl" ]]; then
        _1password_setup_npiperelay_wsl ||
            msg_warn "WSL ブリッジのセットアップに失敗しました（ssh.exe フォールバックで継続します）。"
    fi

    # --- 3. SSH エージェント設定の案内 ---
    _1password_setup_ssh_agent "$env"

    # --- 4. Git コミット署名設定 ---
    _1password_setup_git_signing "$env"

    # --- 5. サービスアカウントトークン設定 ---
    _1password_setup_service_account_token

    # --- 完了メッセージ ---
    printf '\n'
    if ((DRY_RUN)); then
        msg_info "1Password セットアップ予定です（dry-run）。"
    else
        msg_success "1Password のセットアップが完了しました。"
    fi

    printf '\n'
    printf '%s\n' "NOTE: 1Password デスクトップアプリが必要です。CLI 単体では認証できません。"
    msg_step "初回は 'op signin' でサインインしてください。"
}

# --- ステータス表示 ---
module_status() {
    local status version
    if command -v op &>/dev/null; then
        version=$(op --version 2>/dev/null | head -1)
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "op $version"
    else
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
    fi
}

# --- アンインストール ---
uninstall_1password() {
    local restored=0

    # WSL ブリッジ用 npiperelay.exe の削除 ($HOME 配下のみ)
    if [[ -f "$OP_MOD_NPIPERELAY_BIN_PATH" ]]; then
        if [[ "$OP_MOD_NPIPERELAY_BIN_PATH" == "$HOME"/* ]]; then
            msg_info "npiperelay.exe を削除します (${OP_MOD_NPIPERELAY_BIN_PATH})..."
            run_cmd command rm -f "$OP_MOD_NPIPERELAY_BIN_PATH" ||
                msg_warn "${OP_MOD_NPIPERELAY_BIN_PATH} の削除に失敗しました。"
            restored=1
        else
            msg_warn "${OP_MOD_NPIPERELAY_BIN_PATH} は \$HOME 配下ではないため削除をスキップします。"
        fi
    fi

    # Git 署名設定の解除
    if command -v git >/dev/null 2>&1; then
        local current_format
        current_format=$(git config --global gpg.format 2>/dev/null || true)
        if [[ "$current_format" == "ssh" ]]; then
            if ((DRY_RUN)); then
                msg_dry_run "git config --global --unset gpg.format"
                msg_dry_run "git config --global --unset gpg.ssh.program"
                msg_dry_run "git config --global --unset commit.gpgsign"
            else
                git config --global --unset gpg.format 2>/dev/null
                git config --global --unset gpg.ssh.program 2>/dev/null
                git config --global --unset commit.gpgsign 2>/dev/null
                msg_info "Git 署名設定を解除しました。"
                local remaining_key
                remaining_key=$(git config --global user.signingkey 2>/dev/null || true)
                if [[ -n "$remaining_key" ]]; then
                    msg_step "NOTE: user.signingkey ('${remaining_key}') は残っています。"
                    msg_step "不要な場合は: git config --global --unset user.signingkey"
                fi
            fi
            restored=1
        fi
    fi

    # サービスアカウントトークンの削除
    if [[ -f "$OP_MOD_TOKEN_FILE" ]]; then
        # NOTE: --force auto-accepts token deletion on uninstall (intentional per user request)
        local remove_token
        if ((FORCE)); then
            remove_token="y"
            msg_info "--force: トークンファイルを削除します。"
        else
            printf 'サービスアカウントトークンを削除しますか？ (%s) [y/N]: ' "$OP_MOD_TOKEN_FILE"
            read -r remove_token
        fi
        if [[ "$remove_token" == [yY] ]]; then
            if ((DRY_RUN)); then
                msg_dry_run "rm -f ${OP_MOD_TOKEN_FILE}"
            else
                # Use shred for secure deletion if available
                if command -v shred >/dev/null 2>&1; then
                    shred -u "$OP_MOD_TOKEN_FILE" || {
                        msg_error "トークンファイルの安全な削除に失敗しました。"
                        return 1
                    }
                else
                    rm -f "$OP_MOD_TOKEN_FILE" || {
                        msg_error "トークンファイルの削除に失敗しました。"
                        return 1
                    }
                fi
                msg_info "サービスアカウントトークンを削除しました。"
            fi
            restored=1
        else
            msg_info "トークンファイルは残しました。手動で削除する場合: rm ${OP_MOD_TOKEN_FILE}"
        fi
    fi

    # 管理対象ファイルのバックアップ復元 / 削除
    for entry in "${OP_MOD_MANAGED_FILES[@]}"; do
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
        msg_success "1Password のアンインストールが完了しました。"
    else
        msg_info "1Password の復元・削除対象はありませんでした。"
    fi

    printf '\n'
    printf '%s\n' "NOTE: 1Password CLI 本体は削除されていません。不要な場合は手動で削除してください:"

    local env
    env=$(_1password_detect_env)
    case "$env" in
    wsl | linux)
        msg_step "sudo apt-get remove 1password-cli"
        msg_step "sudo rm -f /etc/apt/sources.list.d/1password.list"
        msg_step "sudo rm -f /etc/apt/keyrings/1password-archive-keyring.gpg"
        if [[ "$env" == "wsl" ]]; then
            msg_step "socat は共有依存のため残しています (不要なら: sudo apt-get remove socat)。"
        fi
        ;;
    macos)
        msg_step "brew uninstall --cask 1password-cli"
        ;;
    *)
        msg_step "OS に応じたパッケージマネージャーで削除してください。"
        ;;
    esac
}
