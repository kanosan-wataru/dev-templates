# ---------------------------------------------
# モジュール: Codex CLI
# OpenAI Codex CLI + 設定ファイル配置 (Node.js v18+ 必要)
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="codex-cli"
MODULE_NAME="Codex CLI"
MODULE_DESC="OpenAI Codex CLI (Node.js v18+ 必要)"
MODULE_DEFAULT=0
MODULE_ORDER=31
# TODO: MODULE_DEPS is not yet consumed by setup.sh -- kept for future dependency resolution
MODULE_DEPS="node"

# --- Codex CLI 固有変数 ---
# NOTE: モジュール固有の変数には衝突回避のため CODEX_MOD_ プレフィックスを使用
CODEX_MOD_CONFIG_DIR="$HOME/.codex"
CODEX_MOD_RULES_DIR="$CODEX_MOD_CONFIG_DIR/rules"
CODEX_MOD_SKILLS_DIR="$CODEX_MOD_CONFIG_DIR/skills"

# 管理対象ファイルのリスト（配布元パス, 配置先パス, 表示名, 未検出時メッセージ）
# NOTE: 配列の各要素は "src|dst|label|hint" の形式
CODEX_MOD_MANAGED_FILES=(
    # config.toml (model and reasoning settings)
    "$SCRIPT_DIR/.codex/config.toml|$CODEX_MOD_CONFIG_DIR/config.toml|config.toml|"
    # rules/default.rules (sandbox allow/deny rules)
    "$SCRIPT_DIR/.codex/rules/default.rules|$CODEX_MOD_RULES_DIR/default.rules|rules/default.rules|"
    # AGENTS.md (agent identity and capabilities)
    "$SCRIPT_DIR/.codex/AGENTS.md|$CODEX_MOD_CONFIG_DIR/AGENTS.md|AGENTS.md|"
    # skills/context-loader (project context loading skill)
    "$SCRIPT_DIR/.codex/skills/context-loader/SKILL.md|$CODEX_MOD_SKILLS_DIR/context-loader/SKILL.md|skills/context-loader/SKILL.md|"
)

# 配置先ディレクトリのリスト（サブディレクトリを事前作成するため）
# NOTE: install_config は親ディレクトリの自動作成を行わないため、ここで明示的に列挙する
CODEX_MOD_REQUIRED_DIRS=(
    "$CODEX_MOD_CONFIG_DIR"
    "$CODEX_MOD_RULES_DIR"
    "$CODEX_MOD_SKILLS_DIR"
    "$CODEX_MOD_SKILLS_DIR/context-loader"
)

# --- セットアップ ---
module_setup() {
    print -P ""
    print -P "%F{36}%B[Codex CLI]%b%f"
    print -P "---------------------------------------------"

    # =========================================
    # CLI インストール
    # =========================================

    # べき等性チェック
    if command -v codex >/dev/null 2>&1; then
        local current_ver
        current_ver=$(codex --version 2>/dev/null || print "unknown")
        print -P "情報: Codex CLI は既にインストールされています (${current_ver})。スキップします。"
    else
        # Node.js / npm の確認
        if ! ensure_node; then
            print -P "%F{220}スキップ: Codex CLI のインストールには Node.js v18+ が必要です。%f"
            return 1
        fi

        print -P "Codex CLI をインストールします..."
        run_cmd npm install -g @openai/codex || {
            print -P "%F{160}エラー: Codex CLI のインストールに失敗しました。%f" >&2
            print -P "  npm install -g の権限エラーの場合:" >&2
            print -P "    npm config set prefix ~/.local" >&2
            print -P "  または nvm/fnm をお使いの場合は sudo 不要です。" >&2
            return 1
        }

        if (( DRY_RUN )); then
            print -P "情報: Codex CLI をインストール予定です（dry-run）。"
        else
            print -P "%F{34}Codex CLI のインストールが完了しました。%f"
            print -P ""
            print -P "初回セットアップ:"
            print -P "  export OPENAI_API_KEY=<your-api-key>"
            print -P "  codex  # 対話的に使用開始"
            print -P "  詳細: https://github.com/openai/codex"
        fi
    fi

    # =========================================
    # 設定ファイルの配置
    # =========================================
    print -P ""
    print -P "設定ファイルを配置します..."

    # 必要なディレクトリを事前作成（権限 700）
    for dir in "${CODEX_MOD_REQUIRED_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            run_cmd command mkdir -p "$dir" || {
                print -P "%F{160}エラー: ${dir} の作成に失敗しました。%f" >&2
                return 1
            }
            # NOTE: config may contain sensitive settings; restrict permissions
            run_cmd command chmod 700 "$dir" || {
                print -P "%F{160}エラー: ${dir} の権限設定に失敗しました。%f" >&2
                return 1
            }
            if (( DRY_RUN )); then
                print -P "情報: ${dir} を作成予定です（dry-run）。"
            else
                print -P "情報: ${dir} を作成しました。"
            fi
        fi
    done

    # 設定ファイルの配置
    for entry in "${CODEX_MOD_MANAGED_FILES[@]}"; do
        local src="${entry[(ws:|:)1]}"
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"
        local hint="${entry[(ws:|:)4]}"
        install_config "$src" "$dst" "$label" "$hint"
    done

    print -P "%F{34}Codex CLI 設定ファイルの配置が完了しました。%f"
}

# --- アンインストール ---
module_uninstall() {
    local restored=0

    # =========================================
    # 設定ファイルの復元
    # =========================================
    for entry in "${CODEX_MOD_MANAGED_FILES[@]}"; do
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"

        # Zsh Glob 限定子で最新のバックアップを検索（Om: 更新日時の降順、[1]: 最初の1件）
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
            print -P "%F{220}警告: ${label} のバックアップが見つかりません。手動で確認してください: ${dst}%f"
        else
            print -P "情報: ${label} は配置されていません。スキップします。"
        fi
    done

    if (( restored )); then
        print -P "%F{34}Codex CLI 設定ファイルのアンインストールが完了しました。%f"
    else
        print -P "情報: Codex CLI 設定ファイルの復元・削除対象はありませんでした。"
    fi

    # =========================================
    # CLI アンインストール
    # =========================================

    # インストール状態を判定（コマンドの存在 or npm パッケージの存在）
    if ! command -v codex >/dev/null 2>&1; then
        if ! { command -v npm >/dev/null 2>&1 && npm ls -g @openai/codex >/dev/null 2>&1 }; then
            print -P "情報: Codex CLI はインストールされていません。スキップします。"
            return 0
        fi
    fi

    if ! command -v npm >/dev/null 2>&1; then
        print -P "%F{220}スキップ: npm が見つからないため Codex CLI をアンインストールできません。%f"
        return 1
    fi

    print -P "Codex CLI をアンインストールします..."
    run_cmd npm uninstall -g @openai/codex || {
        print -P "%F{160}エラー: Codex CLI のアンインストールに失敗しました。%f" >&2
        return 1
    }
    print -P "%F{34}Codex CLI をアンインストールしました。%f"
    # NOTE: ~/.codex/ ディレクトリはユーザーデータ（セッション、メモリ等）を含むため削除しない
    print -P "NOTE: ~/.codex/ ディレクトリはユーザーデータを含むため削除されていません。不要な場合は手動で削除してください:"
    print -P "  rm -rf ~/.codex/"
}
