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

    if (( ! DRY_RUN )); then
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
        printf '%s\n' "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
            | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null || {
            msg_error "1Password の apt ソース追加に失敗しました。"
            rm -f "$tmp_key"
            return 1
        }

        # debsig ポリシーの設定
        run_cmd sudo mkdir -p "/etc/debsig/policies/${OP_MOD_DEBSIG_KEY_ID}/"
        if ! curl -sS -o "$tmp_key" https://downloads.1password.com/linux/debian/debsig/1password.pol; then
            msg_warn "debsig ポリシーのダウンロードに失敗しました（インストールは継続します）。"
        else
            sudo tee /etc/debsig/policies/${OP_MOD_DEBSIG_KEY_ID}/1password.pol < "$tmp_key" >/dev/null || {
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
    run_cmd brew install --cask 1password-cli || {
        msg_error "1Password CLI のインストールに失敗しました。"
        return 1
    }
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
            msg_step "1password.zsh により ssh/ssh-add が Windows 側にリダイレクトされます。"
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
    if (( DRY_RUN )); then
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
        printf '  上書きしますか？ [y/N]: '
        local overwrite
        read -r overwrite
        if [[ "$overwrite" != [yY] ]]; then
            msg_step "スキップしました。"
            return 0
        fi
    else
        printf '  サービスアカウントトークンを設定しますか？ [y/N]: '
        local configure
        read -r configure
        if [[ "$configure" != [yY] ]]; then
            msg_step "スキップしました。"
            return 0
        fi
    fi

    # Prompt for token value (silent input)
    printf '  トークンを入力してください: '
    local token
    read -r -s token
    printf '\n'  # Newline after silent input

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
    if (( ${#token} < 10 )); then
        msg_warn "トークンが短すぎます。正しい値か確認してください。"
    fi

    # Create directory with restricted permissions
    if [[ ! -d "$OP_MOD_TOKEN_DIR" ]]; then
        if (( DRY_RUN )); then
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
    if (( DRY_RUN )); then
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

        printf "export OP_SERVICE_ACCOUNT_TOKEN='%s'\n" "$token" > "$tmp_file" || {
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
        wsl)    msg_info "環境を検出しました — WSL" ;;
        linux)  msg_info "環境を検出しました — ネイティブ Linux" ;;
        macos)  msg_info "環境を検出しました — macOS" ;;
        *)
            msg_error "未対応の OS です (OSTYPE=${OSTYPE})。"
            return 1
            ;;
    esac

    # --- 1. op CLI のインストール ---
    if command -v op >/dev/null 2>&1; then
        msg_info "op CLI は既にインストールされています ($(op --version 2>/dev/null || echo '不明'))。スキップします。"
    else
        msg_info "1Password CLI (op) をインストールします..."
        case "$env" in
            wsl|linux)
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

        if (( ! DRY_RUN )); then
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
    for entry in "${OP_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r src dst label hint <<< "$entry"
        install_config "$src" "$dst" "$label" "$hint"
    done

    # --- 3. SSH エージェント設定の案内 ---
    _1password_setup_ssh_agent "$env"

    # --- 4. Git コミット署名設定 ---
    _1password_setup_git_signing "$env"

    # --- 5. サービスアカウントトークン設定 ---
    _1password_setup_service_account_token

    # --- 完了メッセージ ---
    printf '\n'
    if (( DRY_RUN )); then
        msg_info "1Password セットアップ予定です（dry-run）。"
    else
        msg_success "1Password のセットアップが完了しました。"
    fi

    printf '\n'
    printf '%s\n' "NOTE: 1Password デスクトップアプリが必要です。CLI 単体では認証できません。"
    msg_step "初回は 'op signin' でサインインしてください。"
}

# --- アンインストール ---
uninstall_1password() {
    local restored=0

    # Git 署名設定の解除
    if command -v git >/dev/null 2>&1; then
        local current_format
        current_format=$(git config --global gpg.format 2>/dev/null || true)
        if [[ "$current_format" == "ssh" ]]; then
            if (( DRY_RUN )); then
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
        printf 'サービスアカウントトークンを削除しますか？ (%s) [y/N]: ' "$OP_MOD_TOKEN_FILE"
        local remove_token
        read -r remove_token
        if [[ "$remove_token" == [yY] ]]; then
            if (( DRY_RUN )); then
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
        IFS='|' read -r _src dst label _hint <<< "$entry"

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

    if (( restored )); then
        msg_success "1Password のアンインストールが完了しました。"
    else
        msg_info "1Password の復元・削除対象はありませんでした。"
    fi

    printf '\n'
    printf '%s\n' "NOTE: 1Password CLI 本体は削除されていません。不要な場合は手動で削除してください:"

    local env
    env=$(_1password_detect_env)
    case "$env" in
        wsl|linux)
            msg_step "sudo apt-get remove 1password-cli"
            msg_step "sudo rm -f /etc/apt/sources.list.d/1password.list"
            msg_step "sudo rm -f /etc/apt/keyrings/1password-archive-keyring.gpg"
            ;;
        macos)
            msg_step "brew uninstall --cask 1password-cli"
            ;;
        *)
            msg_step "OS に応じたパッケージマネージャーで削除してください。"
            ;;
    esac
}
