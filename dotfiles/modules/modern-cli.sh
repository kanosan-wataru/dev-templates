# ---------------------------------------------
# モジュール: モダン CLI ツール
# eza / bat / fd / ripgrep (Rust 製 CLI) + skillshare (AI CLI スキル同期)
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="modern-cli"
MODULE_NAME="モダン CLI ツール"
MODULE_DESC="eza / bat / fd / ripgrep / skillshare"
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

# Skillshare 関連変数
# NOTE: ソースは dotfiles/.claude/skills/ をそのまま symlink で利用する (真実のソース)
MCLI_MOD_SKILLSHARE_INSTALL_DIR="${HOME}/.local/bin"
MCLI_MOD_SKILLSHARE_REPO="runkids/skillshare"
MCLI_MOD_SKILLSHARE_CONFIG_DIR="${HOME}/.config/skillshare"
MCLI_MOD_SKILLSHARE_CONFIG_TEMPLATE="${SCRIPT_DIR}/.config/skillshare/config.yaml.template"
# 真実のソース (dotfiles 内の .claude/{skills,agents} を git で追跡する想定)
MCLI_MOD_SKILLSHARE_SKILLS_SRC="${SCRIPT_DIR}/.claude/skills"
MCLI_MOD_SKILLSHARE_AGENTS_SRC="${SCRIPT_DIR}/.claude/agents"

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

# --- ヘルパー: skillshare CLI のインストール ---
# GitHub Releases から最新バイナリを取得して ~/.local/bin に配置する。
# NOTE: curl|sh は使わず、スクリプトをダウンロードしてから明示的に実行する。
_mcli_install_skillshare() {
    local install_dir="$MCLI_MOD_SKILLSHARE_INSTALL_DIR"

    if command -v skillshare >/dev/null 2>&1 && ! ((UPGRADE)); then
        msg_info "skillshare は既にインストールされています ($(skillshare --version 2>/dev/null | head -1 || echo unknown))。"
        return 0
    fi

    if ((DRY_RUN)); then
        msg_dry_run "wget -qO /tmp/skillshare-install.sh https://raw.githubusercontent.com/${MCLI_MOD_SKILLSHARE_REPO}/main/install.sh"
        msg_dry_run "INSTALL_DIR=${install_dir} sh /tmp/skillshare-install.sh"
        return 0
    fi

    run_cmd mkdir -p "$install_dir" || {
        msg_error "${install_dir} の作成に失敗しました。"
        return 1
    }

    local installer_path
    installer_path=$(mktemp /tmp/skillshare-install.XXXXXX.sh) || {
        msg_error "一時ファイルの作成に失敗しました。"
        return 1
    }

    msg_step "skillshare インストーラーをダウンロードします..."
    if ! wget -qO "$installer_path" "https://raw.githubusercontent.com/${MCLI_MOD_SKILLSHARE_REPO}/main/install.sh"; then
        if ! curl -fsSL "https://raw.githubusercontent.com/${MCLI_MOD_SKILLSHARE_REPO}/main/install.sh" -o "$installer_path"; then
            msg_error "skillshare インストーラーのダウンロードに失敗しました。"
            rm -f "$installer_path"
            return 1
        fi
    fi

    msg_step "skillshare をインストールします (${install_dir})..."
    if ! INSTALL_DIR="$install_dir" sh "$installer_path"; then
        msg_error "skillshare のインストールに失敗しました。"
        rm -f "$installer_path"
        return 1
    fi
    rm -f "$installer_path"

    # PATH 確認
    if ! command -v skillshare >/dev/null 2>&1; then
        msg_warn "skillshare はインストール済みですが PATH に含まれていません。"
        msg_step "export PATH=\"\$HOME/.local/bin:\$PATH\" をシェル設定に追加してください。"
    fi
}

# --- ヘルパー: skillshare の source 配下に symlink を作成 ---
# 引数: $1=ソース(実体ディレクトリ) $2=symlinkを置くパス $3=ラベル(skills/agents)
# 既存 symlink が同じターゲットを指していればスキップ、別ターゲットなら更新、
# 実ディレクトリが存在する場合は警告のみ (破壊しない)。
_mcli_link_skillshare_source() {
    local src="$1" link="$2" label="$3"

    if [[ -L "$link" ]]; then
        local current
        current=$(readlink "$link")
        if [[ "$current" == "$src" ]]; then
            msg_info "${link} -> ${src} は既に正しく設定されています (${label})。"
        else
            run_cmd ln -sfn "$src" "$link" || return 1
        fi
    elif [[ -d "$link" ]]; then
        msg_warn "${link} が既存ディレクトリです。${label} の symlink 化は手動で行ってください。"
        msg_step "  mv ${link} ${link}.bak && ln -sfn ${src} ${link}"
    else
        run_cmd ln -sfn "$src" "$link" || return 1
        msg_success "skillshare ${label} ソースを ${src} へ symlink しました。"
    fi
}

# --- ヘルパー: skillshare の設定とターゲット同期 ---
# - ~/.config/skillshare/config.yaml をテンプレートから生成
# - ~/.config/skillshare/skills を dotfiles の .claude/skills へ symlink
# - 存在する AI CLI のディレクトリのみを target として追加 (claude は意図的に除外)
# - skillshare sync で symlink を配信
_mcli_setup_skillshare() {
    local config_dir="$MCLI_MOD_SKILLSHARE_CONFIG_DIR"
    local config_template="$MCLI_MOD_SKILLSHARE_CONFIG_TEMPLATE"
    local skills_src="$MCLI_MOD_SKILLSHARE_SKILLS_SRC"
    local agents_src="$MCLI_MOD_SKILLSHARE_AGENTS_SRC"

    if [[ ! -d "$skills_src" ]]; then
        msg_warn "スキルソースが見つかりません: ${skills_src}"
        msg_step "dotfiles/.claude/skills/ にスキルを配置してください。skillshare のセットアップをスキップします。"
        return 0
    fi

    if [[ ! -f "$config_template" ]]; then
        msg_warn "config.yaml テンプレートが見つかりません: ${config_template}"
        return 0
    fi

    if ! command -v skillshare >/dev/null 2>&1; then
        msg_warn "skillshare コマンドが利用できません。設定をスキップします。"
        return 0
    fi

    # 1. ~/.config/skillshare/ を準備
    run_cmd mkdir -p "$config_dir" || return 1

    # 2. config.yaml を生成 (プレースホルダー置換)
    local config_path="${config_dir}/config.yaml"
    if [[ -f "$config_path" ]] && ! ((UPGRADE)) && ! ((FORCE)); then
        msg_info "skillshare config.yaml は既に存在します。スキップします。"
    else
        if ((DRY_RUN)); then
            msg_dry_run "config.yaml を ${config_template} から生成します (置換: __SKILLS_SOURCE__ / __AGENTS_SOURCE__ / __HOME__)"
        else
            msg_step "skillshare config.yaml を生成します..."
            # NOTE: sed -e "s|...|...|" だとパスに | & \ が含まれると壊れるため、bash の
            # parameter expansion (${var//pattern/replacement}) を使う。これは sed と異なり
            # 置換文字列内のメタ文字 (&, \) を特殊扱いしない安全なリテラル置換。
            local template_content
            template_content=$(<"$config_template") || {
                msg_error "config.yaml テンプレートの読み込みに失敗しました。"
                return 1
            }
            template_content="${template_content//__SKILLS_SOURCE__/$skills_src}"
            template_content="${template_content//__AGENTS_SOURCE__/$agents_src}"
            template_content="${template_content//__HOME__/$HOME}"
            printf '%s\n' "$template_content" >"$config_path" || {
                msg_error "config.yaml の生成に失敗しました。"
                return 1
            }
        fi
    fi

    # 3. ~/.config/skillshare/{skills,agents} を symlink で source に向ける
    _mcli_link_skillshare_source "$skills_src" "${config_dir}/skills" "skills" || return 1
    if [[ -d "$agents_src" ]]; then
        _mcli_link_skillshare_source "$agents_src" "${config_dir}/agents" "agents" || return 1
    else
        msg_info "agents ソース ${agents_src} が見つかりません。agents の symlink をスキップします。"
    fi

    # 4. ターゲット追加 (存在するもののみ、claude は除外)
    local -a targets=(
        "gemini|${HOME}/.gemini/skills"
        "codex|${HOME}/.codex/skills"
        "opencode|${HOME}/.config/opencode/skills"
    )
    for entry in "${targets[@]}"; do
        IFS='|' read -r name path <<<"$entry"
        # 親ディレクトリの存在のみ確認 (skills 自体は skillshare が作る)
        local parent
        parent=$(dirname "$path")
        if [[ ! -d "$parent" ]]; then
            msg_info "${name} がインストールされていません。target を追加しません。"
            continue
        fi
        # 既に登録済みか確認
        if skillshare target list 2>/dev/null | grep -qE "^  ${name}\b"; then
            msg_info "skillshare target '${name}' は既に登録済みです。"
            continue
        fi
        if ((DRY_RUN)); then
            msg_dry_run "skillshare target add ${name} ${path}"
        else
            run_cmd skillshare target add "$name" "$path" || msg_warn "${name} の target 追加に失敗しました。"
        fi
    done

    # 5. sync 実行 (skills + agents)
    if ((DRY_RUN)); then
        msg_dry_run "skillshare sync --all"
    else
        msg_step "skillshare sync --all を実行します (skills + agents)..."
        printf "y\n" | skillshare sync --all >/dev/null 2>&1 || msg_warn "skillshare sync に失敗しました (手動で 'skillshare sync --all' を実行してください)。"
    fi

    # 6. Codex 専用: .md エージェント → .toml 変換
    #    Skillshare は同形式 (.md) のみ扱うため、TOML を要求する Codex には変換スクリプトで対応する。
    local codex_converter="${SCRIPT_DIR}/scripts/sync-codex-agents.py"
    if [[ -d "$agents_src" ]] && [[ -x "$codex_converter" ]] && [[ -d "${HOME}/.codex" ]]; then
        if ((DRY_RUN)); then
            msg_dry_run "python3 ${codex_converter} ${agents_src} ${HOME}/.codex/agents"
        else
            msg_step "Codex 用に .md → .toml 変換を実行します..."
            if command -v python3 >/dev/null 2>&1; then
                python3 "$codex_converter" "$agents_src" "${HOME}/.codex/agents" || \
                    msg_warn "Codex agents の変換に失敗しました。"
            else
                msg_warn "python3 が見つかりません。Codex agents 変換をスキップします。"
            fi
        fi
    fi
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

        # Idempotency check (skip if already installed and not upgrading)
        if command -v "$cmd_name" >/dev/null 2>&1; then
            if ! ((UPGRADE)); then
                msg_info "${cmd_name} は既にインストールされています。スキップします。"
                ((skipped++))
                continue
            fi
            msg_info "${cmd_name} のアップグレードを実行します... (現在: $(${cmd_name} --version 2>/dev/null | head -1 || echo 'unknown'))"
        fi
        if [[ -n "$alt_cmd" ]] && command -v "$alt_cmd" >/dev/null 2>&1; then
            if ! ((UPGRADE)); then
                msg_info "${alt_cmd} (${cmd_name}) は既にインストールされています。スキップします。"
                ((skipped++))
                continue
            fi
            msg_info "${cmd_name} のアップグレードを実行します... (現在: $(${alt_cmd} --version 2>/dev/null | head -1 || echo 'unknown'))"
        fi

        printf '%s\n' "${cmd_name} をインストールします... (${desc})"

        case "$os" in
        macos)
            if ((UPGRADE)); then
                run_cmd brew upgrade "$brew_pkg" || {
                    msg_warn "${cmd_name} のアップグレードに失敗しました（既に最新の可能性があります）。"
                    continue
                }
            else
                run_cmd brew install "$brew_pkg" || {
                    msg_error "${cmd_name} のインストールに失敗しました。"
                    ((failed++))
                    continue
                }
            fi
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
        # 失敗があっても skillshare セットアップは試行する (独立した処理)
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

    # ==========================================
    # skillshare: AI CLI 間のスキル同期
    # ==========================================
    printf '\n'
    msg_header "skillshare (AI CLI スキル同期)"
    print_separator
    _mcli_install_skillshare || msg_warn "skillshare のインストールに失敗しました。スキル同期セットアップをスキップします。"
    _mcli_setup_skillshare || msg_warn "skillshare の設定に失敗しました。"

    if ((failed > 0)); then
        return 1
    fi
}

# --- ステータス表示 ---
module_status() {
    local -a found=() missing=()
    local total_tools=4 # 後段で skillshare 分を加算する

    # eza
    if command -v eza &>/dev/null; then
        # NOTE: eza --version outputs version on line 2 (e.g. "v0.23.4 [+git]")
        found+=("eza $(eza --version 2>/dev/null | sed -n '2p' | awk '{print $1}')")
    else
        missing+=("eza")
    fi

    # bat / batcat
    if command -v bat &>/dev/null; then
        found+=("$(bat --version 2>/dev/null | head -1)")
    elif command -v batcat &>/dev/null; then
        found+=("$(batcat --version 2>/dev/null | head -1)")
    else
        missing+=("bat")
    fi

    # fd / fdfind
    if command -v fd &>/dev/null; then
        found+=("$(fd --version 2>/dev/null | head -1)")
    elif command -v fdfind &>/dev/null; then
        found+=("$(fdfind --version 2>/dev/null | head -1)")
    else
        missing+=("fd")
    fi

    # rg (ripgrep)
    if command -v rg &>/dev/null; then
        found+=("$(rg --version 2>/dev/null | head -1)")
    else
        missing+=("rg")
    fi

    # skillshare (AI CLI スキル同期)
    if command -v skillshare &>/dev/null; then
        found+=("skillshare $(skillshare --version 2>/dev/null | head -1 | awk '{print $NF}')")
    else
        missing+=("skillshare")
    fi
    ((total_tools++))

    local found_count=${#found[@]}

    if ((found_count == total_tools)); then
        # All tools installed
        local versions
        versions=$(printf '%s, ' "${found[@]}")
        versions="${versions%, }"
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "$versions"
    elif ((found_count > 0)); then
        # Partial: some tools installed, some missing
        local found_names missing_names
        found_names=$(printf '%s, ' "${found[@]}")
        found_names="${found_names%, }"
        missing_names=$(printf '%s, ' "${missing[@]}")
        missing_names="${missing_names%, }"
        printf '  %-14s %s%-18s%s found: %s | missing: %s\n' \
            "$MODULE_ID" "${C_YELLOW}" "△ partial" "${C_RESET}" "$found_names" "$missing_names"
    else
        # No tools installed
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
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

    printf '\n'
    printf '%s\n' "skillshare のアンインストール手順:"
    msg_step "rm -f ${MCLI_MOD_SKILLSHARE_INSTALL_DIR}/skillshare"
    msg_step "rm -rf ${MCLI_MOD_SKILLSHARE_CONFIG_DIR}"
    msg_step "# 各 AI CLI の skills/ 内の symlink は skillshare target remove <name> で先に解除すると安全"
}
