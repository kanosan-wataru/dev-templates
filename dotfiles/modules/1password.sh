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
    "$SCRIPT_DIR/.zsh/1password.zsh|$HOME/.zsh/1password.zsh|1password.zsh|"
)

# --- ヘルパー: 環境判定 ---
# 戻り値: "wsl" / "linux" / "macos" / "unknown"
_1password_detect_env() {
    case "$OSTYPE" in
        darwin*)
            print "macos"
            ;;
        linux*)
            if [[ -f /proc/version ]] && grep -qi 'microsoft' /proc/version 2>/dev/null; then
                print "wsl"
            else
                print "linux"
            fi
            ;;
        *)
            print "unknown"
            ;;
    esac
}

# --- ヘルパー: op CLI のインストール (Ubuntu/Debian) ---
_1password_install_op_apt() {
    print -P "  1Password CLI の apt リポジトリを設定します..."

    # 前提コマンドの確認
    local -a required_cmds=(curl gpg)
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print -P "%F{160}エラー: ${cmd} がインストールされていません。%f" >&2
            return 1
        fi
    done

    run_cmd sudo mkdir -p /etc/apt/keyrings || {
        print -P "%F{160}エラー: /etc/apt/keyrings の作成に失敗しました。%f" >&2
        return 1
    }

    if (( ! DRY_RUN )); then
        # GPG キーのダウンロードと変換を分離して個別にエラーチェック
        local tmp_key
        tmp_key=$(mktemp) || {
            print -P "%F{160}エラー: 一時ファイルの作成に失敗しました。%f" >&2
            return 1
        }

        if ! curl -sS -o "$tmp_key" https://downloads.1password.com/linux/keys/1password.asc; then
            print -P "%F{160}エラー: 1Password の GPG キー取得に失敗しました。%f" >&2
            rm -f "$tmp_key"
            return 1
        fi

        # 既存キーファイルがあれば事前に削除（再実行時のべき等性）
        [[ -f /etc/apt/keyrings/1password-archive-keyring.gpg ]] && sudo rm -f /etc/apt/keyrings/1password-archive-keyring.gpg

        sudo gpg --dearmor --output /etc/apt/keyrings/1password-archive-keyring.gpg "$tmp_key" 2>/dev/null || {
            print -P "%F{160}エラー: GPG キー変換に失敗しました。%f" >&2
            rm -f "$tmp_key"
            return 1
        }

        # apt ソースの追加
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
            | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null || {
            print -P "%F{160}エラー: 1Password の apt ソース追加に失敗しました。%f" >&2
            rm -f "$tmp_key"
            return 1
        }

        # debsig ポリシーの設定
        run_cmd sudo mkdir -p "/etc/debsig/policies/${OP_MOD_DEBSIG_KEY_ID}/"
        if ! curl -sS -o "$tmp_key" https://downloads.1password.com/linux/debian/debsig/1password.pol; then
            print -P "%F{220}警告: debsig ポリシーのダウンロードに失敗しました（インストールは継続します）。%f"
        else
            sudo tee /etc/debsig/policies/${OP_MOD_DEBSIG_KEY_ID}/1password.pol < "$tmp_key" >/dev/null || {
                print -P "%F{220}警告: debsig ポリシーの設定に失敗しました（インストールは継続します）。%f"
            }
        fi

        run_cmd sudo mkdir -p "/usr/share/debsig/keyrings/${OP_MOD_DEBSIG_KEY_ID}"
        [[ -f /usr/share/debsig/keyrings/${OP_MOD_DEBSIG_KEY_ID}/debsig.gpg ]] && sudo rm -f /usr/share/debsig/keyrings/${OP_MOD_DEBSIG_KEY_ID}/debsig.gpg
        if ! curl -sS -o "$tmp_key" https://downloads.1password.com/linux/keys/1password.asc; then
            print -P "%F{220}警告: debsig キーリング用キーの取得に失敗しました（インストールは継続します）。%f"
        else
            sudo gpg --dearmor --output /usr/share/debsig/keyrings/${OP_MOD_DEBSIG_KEY_ID}/debsig.gpg "$tmp_key" 2>/dev/null || {
                print -P "%F{220}警告: debsig キーリングの設定に失敗しました（インストールは継続します）。%f"
            }
        fi

        rm -f "$tmp_key"
    else
        print -P "%F{242}  [DRY-RUN] curl ... | sudo gpg --dearmor -o /etc/apt/keyrings/1password-archive-keyring.gpg%f"
        print -P "%F{242}  [DRY-RUN] echo 'deb ...' | sudo tee /etc/apt/sources.list.d/1password.list%f"
        print -P "%F{242}  [DRY-RUN] debsig ポリシー設定%f"
    fi

    run_cmd sudo apt-get update -qq || {
        print -P "%F{220}警告: apt update に失敗しました。%f"
    }
    run_cmd sudo apt-get install -y 1password-cli || {
        print -P "%F{160}エラー: 1Password CLI のインストールに失敗しました。%f" >&2
        return 1
    }
}

# --- ヘルパー: op CLI のインストール (macOS) ---
_1password_install_op_brew() {
    run_cmd brew install --cask 1password-cli || {
        print -P "%F{160}エラー: 1Password CLI のインストールに失敗しました。%f" >&2
        return 1
    }
}

# --- ヘルパー: SSH エージェント設定の案内 ---
_1password_setup_ssh_agent() {
    local env="$1"

    print -P ""
    print -P "SSH エージェント設定:"

    case "$env" in
        wsl)
            print -P "  WSL 環境を検出しました。"
            print -P "  Windows 側の 1Password デスクトップアプリで SSH エージェントを有効にしてください。"
            print -P "  1password.zsh により ssh/ssh-add が Windows 側にリダイレクトされます。"
            print -P ""
            print -P "  有効化:"
            print -P "    export ENABLE_SSH_1PASSWORD=1  # ~/.zshenv 等に追加"
            ;;
        linux)
            local sock_path="$HOME/.1password/agent.sock"
            print -P "  ネイティブ Linux 環境を検出しました。"
            if [[ -S "$sock_path" ]]; then
                print -P "  %F{34}SSH エージェントソケットが見つかりました。%f"
            else
                print -P "  %F{220}SSH エージェントソケットが見つかりません。%f"
                print -P "  1Password デスクトップアプリで SSH エージェントを有効にしてください。"
                print -P "    設定 → 開発者 → SSH エージェント → 有効にする"
            fi
            print -P ""
            print -P "  有効化:"
            print -P "    export ENABLE_SSH_1PASSWORD=1  # ~/.zshenv 等に追加"
            ;;
        macos)
            local sock_path="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
            print -P "  macOS 環境を検出しました。"
            if [[ -S "$sock_path" ]]; then
                print -P "  %F{34}SSH エージェントソケットが見つかりました。%f"
            else
                print -P "  %F{220}SSH エージェントソケットが見つかりません。%f"
                print -P "  1Password デスクトップアプリで SSH エージェントを有効にしてください。"
                print -P "    設定 → 開発者 → SSH エージェント → 有効にする"
            fi
            print -P ""
            print -P "  有効化:"
            print -P "    export ENABLE_SSH_1PASSWORD=1  # ~/.zshenv 等に追加"
            ;;
    esac
}

# --- ヘルパー: Git コミット署名設定 ---
_1password_setup_git_signing() {
    local env="$1"

    print -P ""
    print -P "Git コミット署名設定:"

    if ! command -v git >/dev/null 2>&1; then
        print -P "  %F{220}警告: git が見つかりません。Git 署名設定をスキップします。%f"
        return 0
    fi

    # 既に gpg.format = ssh が設定されているか確認
    local current_format
    current_format=$(git config --global gpg.format 2>/dev/null || true)
    if [[ "$current_format" == "ssh" ]]; then
        print -P "  情報: gpg.format は既に ssh に設定されています。"
        local current_program
        current_program=$(git config --global gpg.ssh.program 2>/dev/null || true)
        local current_key
        current_key=$(git config --global user.signingkey 2>/dev/null || true)
        local current_sign
        current_sign=$(git config --global commit.gpgsign 2>/dev/null || true)
        [[ -n "$current_program" ]] && print -P "  gpg.ssh.program: ${current_program}"
        [[ -n "$current_key" ]] && print -P "  user.signingkey:  ${current_key}"
        [[ -n "$current_sign" ]] && print -P "  commit.gpgsign:   ${current_sign}"
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
                print -P "  %F{220}警告: Windows ユーザー名を検出できませんでした。%f"
                print -P "  手動で設定してください:"
                print -P "    git config --global gpg.ssh.program '/mnt/c/Users/<ユーザー名>/AppData/Local/1Password/app/8/op-ssh-sign.exe'"
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
        print -P "%F{242}  [DRY-RUN] git config --global gpg.format ssh%f"
        print -P "%F{242}  [DRY-RUN] git config --global gpg.ssh.program ${sign_program}%f"
        print -P "%F{242}  [DRY-RUN] git config --global commit.gpgsign true%f"
    else
        git config --global gpg.format ssh || {
            print -P "%F{160}エラー: gpg.format の設定に失敗しました。%f" >&2
            return 1
        }
        git config --global gpg.ssh.program "$sign_program" || {
            print -P "%F{160}エラー: gpg.ssh.program の設定に失敗しました。%f" >&2
            return 1
        }
        git config --global commit.gpgsign true || {
            print -P "%F{160}エラー: commit.gpgsign の設定に失敗しました。%f" >&2
            return 1
        }
        print -P "  %F{34}Git 署名設定を適用しました。%f"
        print -P "  gpg.format:       ssh"
        print -P "  gpg.ssh.program:  ${sign_program}"
        print -P "  commit.gpgsign:   true"
    fi

    # user.signingkey の案内
    local current_key
    current_key=$(git config --global user.signingkey 2>/dev/null || true)
    if [[ -z "$current_key" ]]; then
        print -P ""
        print -P "  %F{220}NOTE: user.signingkey が未設定です。以下を実行してください:%f"
        print -P "    git config --global user.signingkey \"ssh-ed25519 AAAA...\""
        print -P "  1Password → SSH キーの詳細 → 公開鍵をコピーして指定してください。"
    fi
}

# --- Helper: Service account token storage ---
_1password_setup_service_account_token() {
    print -P ""
    print -P "サービスアカウントトークン設定:"

    # Check if token file already exists
    if [[ -f "$OP_MOD_TOKEN_FILE" ]]; then
        print -P "  情報: トークンファイルが既に存在します (${OP_MOD_TOKEN_FILE})。"
        print -P -n "  上書きしますか？ [y/N]: "
        local overwrite
        read -r overwrite
        if [[ "$overwrite" != [yY] ]]; then
            print -P "  スキップしました。"
            return 0
        fi
    else
        print -P -n "  サービスアカウントトークンを設定しますか？ [y/N]: "
        local configure
        read -r configure
        if [[ "$configure" != [yY] ]]; then
            print -P "  スキップしました。"
            return 0
        fi
    fi

    # Prompt for token value (silent input)
    print -P -n "  トークンを入力してください: "
    local token
    read -r -s token
    print ""  # Newline after silent input

    if [[ -z "$token" ]]; then
        print -P "  %F{220}警告: トークンが空です。スキップします。%f"
        return 0
    fi

    # Validate token characters (allow only safe characters to prevent injection)
    if [[ ! "$token" =~ ^[A-Za-z0-9_+/=.-]+$ ]]; then
        print -P "%F{196}エラー: トークンに不正な文字が含まれています。%f"
        return 1
    fi

    # Warn if token seems too short
    if (( ${#token} < 10 )); then
        print -P "%F{220}警告: トークンが短すぎます。正しい値か確認してください。%f"
    fi

    # Create directory with restricted permissions
    if [[ ! -d "$OP_MOD_TOKEN_DIR" ]]; then
        if (( DRY_RUN )); then
            print -P "%F{242}  [DRY-RUN] mkdir -p ${OP_MOD_TOKEN_DIR} && chmod 700 ${OP_MOD_TOKEN_DIR}%f"
        else
            mkdir -p "$OP_MOD_TOKEN_DIR" || {
                print -P "%F{160}エラー: ${OP_MOD_TOKEN_DIR} の作成に失敗しました。%f" >&2
                return 1
            }
            chmod 700 "$OP_MOD_TOKEN_DIR" || {
                print -P "%F{160}エラー: ${OP_MOD_TOKEN_DIR} のパーミッション設定に失敗しました。%f" >&2
                return 1
            }
        fi
    fi

    # Write token file with restricted permissions
    if (( DRY_RUN )); then
        print -P "%F{242}  [DRY-RUN] トークンを ${OP_MOD_TOKEN_FILE} に保存 (chmod 600)%f"
    else
        # Write the token file atomically via a temp file
        # Set restrictive umask so mktemp creates files with safe permissions
        local old_umask
        old_umask=$(umask)
        umask 077

        local tmp_file
        tmp_file=$(mktemp "${OP_MOD_TOKEN_DIR}/.token.XXXXXX") || {
            print -P "%F{160}エラー: 一時ファイルの作成に失敗しました。%f" >&2
            umask "$old_umask"
            return 1
        }

        chmod 600 "$tmp_file" || {
            print -P "%F{160}エラー: 一時ファイルのパーミッション設定に失敗しました。%f" >&2
            rm -f "$tmp_file"
            umask "$old_umask"
            return 1
        }

        printf "export OP_SERVICE_ACCOUNT_TOKEN='%s'\n" "$token" > "$tmp_file" || {
            print -P "%F{160}エラー: トークンの書き込みに失敗しました。%f" >&2
            rm -f "$tmp_file"
            umask "$old_umask"
            return 1
        }

        mv "$tmp_file" "$OP_MOD_TOKEN_FILE" || {
            print -P "%F{160}エラー: トークンファイルの配置に失敗しました。%f" >&2
            rm -f "$tmp_file"
            umask "$old_umask"
            return 1
        }

        umask "$old_umask"

        print -P "  %F{34}トークンを保存しました: ${OP_MOD_TOKEN_FILE}%f"
    fi
}

# --- セットアップ ---
module_setup() {
    print -P ""
    print -P "%F{36}%B[1Password]%b%f"
    print -P "---------------------------------------------"

    local env
    env=$(_1password_detect_env)

    case "$env" in
        wsl)    print -P "情報: 環境を検出しました — WSL" ;;
        linux)  print -P "情報: 環境を検出しました — ネイティブ Linux" ;;
        macos)  print -P "情報: 環境を検出しました — macOS" ;;
        *)
            print -P "%F{160}エラー: 未対応の OS です (OSTYPE=${OSTYPE})。%f" >&2
            return 1
            ;;
    esac

    # --- 1. op CLI のインストール ---
    if command -v op >/dev/null 2>&1; then
        print -P "情報: op CLI は既にインストールされています ($(op --version 2>/dev/null || echo '不明'))。スキップします。"
    else
        print -P "1Password CLI (op) をインストールします..."
        case "$env" in
            wsl|linux)
                if ! command -v apt-get >/dev/null 2>&1; then
                    print -P "%F{160}エラー: apt-get が見つかりません。Debian/Ubuntu 系のみ対応しています。%f" >&2
                    return 1
                fi
                _1password_install_op_apt || return 1
                ;;
            macos)
                if ! command -v brew >/dev/null 2>&1; then
                    print -P "%F{160}エラー: Homebrew がインストールされていません。%f" >&2
                    print -P "  インストール: https://brew.sh/" >&2
                    return 1
                fi
                _1password_install_op_brew || return 1
                ;;
        esac

        if (( ! DRY_RUN )); then
            if command -v op >/dev/null 2>&1; then
                print -P "  %F{34}op CLI のインストールが完了しました ($(op --version 2>/dev/null))。%f"
            else
                print -P "%F{160}エラー: op CLI のインストール後にコマンドが見つかりません。%f" >&2
                return 1
            fi
        fi
    fi

    # --- 2. 設定ファイルの配置 ---
    print -P ""
    print -P "設定ファイルを配置します..."
    for entry in "${OP_MOD_MANAGED_FILES[@]}"; do
        local src="${entry[(ws:|:)1]}"
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"
        local hint="${entry[(ws:|:)4]}"
        install_config "$src" "$dst" "$label" "$hint"
    done

    # --- 3. SSH エージェント設定の案内 ---
    _1password_setup_ssh_agent "$env"

    # --- 4. Git コミット署名設定 ---
    _1password_setup_git_signing "$env"

    # --- 5. サービスアカウントトークン設定 ---
    _1password_setup_service_account_token

    # --- 完了メッセージ ---
    print -P ""
    if (( DRY_RUN )); then
        print -P "情報: 1Password セットアップ予定です（dry-run）。"
    else
        print -P "%F{34}1Password のセットアップが完了しました。%f"
    fi

    print -P ""
    print -P "NOTE: 1Password デスクトップアプリが必要です。CLI 単体では認証できません。"
    print -P "  初回は 'op signin' でサインインしてください。"
}

# --- アンインストール ---
module_uninstall() {
    local restored=0

    # Git 署名設定の解除
    if command -v git >/dev/null 2>&1; then
        local current_format
        current_format=$(git config --global gpg.format 2>/dev/null || true)
        if [[ "$current_format" == "ssh" ]]; then
            if (( DRY_RUN )); then
                print -P "%F{242}  [DRY-RUN] git config --global --unset gpg.format%f"
                print -P "%F{242}  [DRY-RUN] git config --global --unset gpg.ssh.program%f"
                print -P "%F{242}  [DRY-RUN] git config --global --unset commit.gpgsign%f"
            else
                git config --global --unset gpg.format 2>/dev/null
                git config --global --unset gpg.ssh.program 2>/dev/null
                git config --global --unset commit.gpgsign 2>/dev/null
                print -P "情報: Git 署名設定を解除しました。"
                local remaining_key
                remaining_key=$(git config --global user.signingkey 2>/dev/null || true)
                if [[ -n "$remaining_key" ]]; then
                    print -P "  NOTE: user.signingkey ('${remaining_key}') は残っています。"
                    print -P "  不要な場合は: git config --global --unset user.signingkey"
                fi
            fi
            restored=1
        fi
    fi

    # サービスアカウントトークンの削除
    if [[ -f "$OP_MOD_TOKEN_FILE" ]]; then
        print -P -n "サービスアカウントトークンを削除しますか？ (${OP_MOD_TOKEN_FILE}) [y/N]: "
        local remove_token
        read -r remove_token
        if [[ "$remove_token" == [yY] ]]; then
            if (( DRY_RUN )); then
                print -P "%F{242}  [DRY-RUN] rm -f ${OP_MOD_TOKEN_FILE}%f"
            else
                # Use shred for secure deletion if available
                if command -v shred >/dev/null 2>&1; then
                    shred -u "$OP_MOD_TOKEN_FILE" || {
                        print -P "%F{160}エラー: トークンファイルの安全な削除に失敗しました。%f" >&2
                        return 1
                    }
                else
                    rm -f "$OP_MOD_TOKEN_FILE" || {
                        print -P "%F{160}エラー: トークンファイルの削除に失敗しました。%f" >&2
                        return 1
                    }
                fi
                print -P "情報: サービスアカウントトークンを削除しました。"
            fi
            restored=1
        else
            print -P "情報: トークンファイルは残しました。手動で削除する場合: rm ${OP_MOD_TOKEN_FILE}"
        fi
    fi

    # 管理対象ファイルのバックアップ復元 / 削除
    for entry in "${OP_MOD_MANAGED_FILES[@]}"; do
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"

        local -a latest_backup
        latest_backup=( "${dst}.backup."*(N^/Om[1]) )

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
        print -P "%F{34}1Password のアンインストールが完了しました。%f"
    else
        print -P "情報: 1Password の復元・削除対象はありませんでした。"
    fi

    print -P ""
    print -P "NOTE: 1Password CLI 本体は削除されていません。不要な場合は手動で削除してください:"

    local env
    env=$(_1password_detect_env)
    case "$env" in
        wsl|linux)
            print -P "  sudo apt-get remove 1password-cli"
            print -P "  sudo rm -f /etc/apt/sources.list.d/1password.list"
            print -P "  sudo rm -f /etc/apt/keyrings/1password-archive-keyring.gpg"
            ;;
        macos)
            print -P "  brew uninstall --cask 1password-cli"
            ;;
        *)
            print -P "  OS に応じたパッケージマネージャーで削除してください。"
            ;;
    esac
}
