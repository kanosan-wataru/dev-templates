# ---------------------------------------------
# モジュール: Claude Code
# Anthropic CLI + 設定ファイル配置 (Node.js v18+ 必要)
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="claude-code"
MODULE_NAME="Claude Code"
MODULE_DESC="Anthropic CLI + 設定ファイル (Node.js v18+ 必要)"
MODULE_DEFAULT=0
MODULE_ORDER=20

# --- Claude Code 固有変数 ---
# NOTE: モジュール固有の変数には衝突回避のため CLAUDE_MOD_ プレフィックスを使用
CLAUDE_MOD_CONFIG_DIR="$HOME/.claude"
CLAUDE_MOD_SKILLS_DIR="$CLAUDE_MOD_CONFIG_DIR/skills"

# 管理対象ファイルのリスト（配布元パス, 配置先パス, 表示名, 未検出時メッセージ）
# NOTE: 配列の各要素は "src|dst|label|hint" の形式
CLAUDE_MOD_MANAGED_FILES=(
    # CLAUDE.md（グローバル設定）
    "$SCRIPT_DIR/.claude/CLAUDE.md|$CLAUDE_MOD_CONFIG_DIR/CLAUDE.md|CLAUDE.md|"
    # settings.json（権限・プラグイン設定）
    "$SCRIPT_DIR/.claude/settings.json|$CLAUDE_MOD_CONFIG_DIR/settings.json|settings.json|"
    # hookify ルールファイル
    "$SCRIPT_DIR/.claude/hookify.block-force-push.local.md|$CLAUDE_MOD_CONFIG_DIR/hookify.block-force-push.local.md|hookify.block-force-push.local.md|hookify ルールは手動で設定してください。"
    "$SCRIPT_DIR/.claude/hookify.block-sensitive-files.local.md|$CLAUDE_MOD_CONFIG_DIR/hookify.block-sensitive-files.local.md|hookify.block-sensitive-files.local.md|hookify ルールは手動で設定してください。"
    "$SCRIPT_DIR/.claude/hookify.warn-git-add.local.md|$CLAUDE_MOD_CONFIG_DIR/hookify.warn-git-add.local.md|hookify.warn-git-add.local.md|hookify ルールは手動で設定してください。"
    # スキル: ci
    "$SCRIPT_DIR/.claude/skills/ci/SKILL.md|$CLAUDE_MOD_SKILLS_DIR/ci/SKILL.md|skills/ci/SKILL.md|"
    # スキル: commit
    "$SCRIPT_DIR/.claude/skills/commit/SKILL.md|$CLAUDE_MOD_SKILLS_DIR/commit/SKILL.md|skills/commit/SKILL.md|"
    "$SCRIPT_DIR/.claude/skills/commit/references/format-guide.md|$CLAUDE_MOD_SKILLS_DIR/commit/references/format-guide.md|skills/commit/references/format-guide.md|"
    # スキル: create-issue
    "$SCRIPT_DIR/.claude/skills/create-issue/SKILL.md|$CLAUDE_MOD_SKILLS_DIR/create-issue/SKILL.md|skills/create-issue/SKILL.md|"
    # スキル: create-pr
    "$SCRIPT_DIR/.claude/skills/create-pr/SKILL.md|$CLAUDE_MOD_SKILLS_DIR/create-pr/SKILL.md|skills/create-pr/SKILL.md|"
    # スキル: git-cleanup
    "$SCRIPT_DIR/.claude/skills/git-cleanup/SKILL.md|$CLAUDE_MOD_SKILLS_DIR/git-cleanup/SKILL.md|skills/git-cleanup/SKILL.md|"
    # スキル: start-work
    "$SCRIPT_DIR/.claude/skills/start-work/SKILL.md|$CLAUDE_MOD_SKILLS_DIR/start-work/SKILL.md|skills/start-work/SKILL.md|"
    # スキル: test
    "$SCRIPT_DIR/.claude/skills/test/SKILL.md|$CLAUDE_MOD_SKILLS_DIR/test/SKILL.md|skills/test/SKILL.md|"
)

# 配置先ディレクトリのリスト（スキルのサブディレクトリを事前作成するため）
# NOTE: install_config は親ディレクトリの自動作成を行わないため、ここで明示的に列挙する
CLAUDE_MOD_REQUIRED_DIRS=(
    "$CLAUDE_MOD_CONFIG_DIR"
    "$CLAUDE_MOD_SKILLS_DIR/ci"
    "$CLAUDE_MOD_SKILLS_DIR/commit/references"
    "$CLAUDE_MOD_SKILLS_DIR/create-issue"
    "$CLAUDE_MOD_SKILLS_DIR/create-pr"
    "$CLAUDE_MOD_SKILLS_DIR/git-cleanup"
    "$CLAUDE_MOD_SKILLS_DIR/start-work"
    "$CLAUDE_MOD_SKILLS_DIR/test"
)

# --- セットアップ ---
module_setup() {
    print -P ""
    print -P "%F{36}%B[Claude Code]%b%f"
    print -P "---------------------------------------------"

    # =========================================
    # CLI インストール
    # =========================================

    # べき等性チェック
    if command -v claude >/dev/null 2>&1; then
        local current_ver
        current_ver=$(claude --version 2>/dev/null || print "unknown")
        print -P "情報: Claude Code は既にインストールされています (${current_ver})。スキップします。"
    else
        # Node.js / npm の確認
        if ! ensure_node; then
            print -P "%F{220}スキップ: Claude Code のインストールには Node.js v18+ が必要です。%f"
            return 1
        fi

        print -P "Claude Code をインストールします..."
        run_cmd npm install -g @anthropic-ai/claude-code || {
            print -P "%F{160}エラー: Claude Code のインストールに失敗しました。%f" >&2
            print -P "  npm install -g の権限エラーの場合:" >&2
            print -P "    npm config set prefix ~/.local" >&2
            print -P "  または nvm/fnm をお使いの場合は sudo 不要です。" >&2
            return 1
        }

        if (( DRY_RUN )); then
            print -P "情報: Claude Code をインストール予定です（dry-run）。"
        else
            print -P "%F{34}Claude Code のインストールが完了しました。%f"
            print -P ""
            print -P "初回セットアップ:"
            print -P "  claude  # 対話的に API キーを設定"
            print -P "  詳細: https://docs.anthropic.com/en/docs/claude-code"
        fi
    fi

    # =========================================
    # 設定ファイルの配置
    # =========================================
    print -P ""
    print -P "設定ファイルを配置します..."

    # 必要なディレクトリを事前作成
    for dir in "${CLAUDE_MOD_REQUIRED_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            run_cmd command mkdir -p "$dir" || {
                print -P "%F{160}エラー: ${dir} の作成に失敗しました。%f" >&2
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
    for entry in "${CLAUDE_MOD_MANAGED_FILES[@]}"; do
        local src="${entry[(ws:|:)1]}"
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"
        local hint="${entry[(ws:|:)4]}"
        install_config "$src" "$dst" "$label" "$hint"
    done

    print -P "%F{34}Claude Code 設定ファイルの配置が完了しました。%f"
}

# --- アンインストール ---
module_uninstall() {
    local restored=0

    # =========================================
    # 設定ファイルの復元・削除
    # =========================================
    for entry in "${CLAUDE_MOD_MANAGED_FILES[@]}"; do
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"

        # Zsh Glob 限定子で最新のバックアップを検索（シンボリックリンクも含む、ディレクトリは除外）
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
            print -P "削除: ${label} を削除します（セットアップ前の状態に復元）。"
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
        print -P "%F{34}Claude Code 設定ファイルのアンインストールが完了しました。%f"
    else
        print -P "情報: Claude Code 設定ファイルの復元・削除対象はありませんでした。"
    fi

    # =========================================
    # CLI アンインストール
    # =========================================

    # インストール状態を判定（コマンドの存在 or npm パッケージの存在）
    if ! command -v claude >/dev/null 2>&1; then
        if ! { command -v npm >/dev/null 2>&1 && npm ls -g @anthropic-ai/claude-code >/dev/null 2>&1 }; then
            print -P "情報: Claude Code はインストールされていません。スキップします。"
            return 0
        fi
    fi

    if ! command -v npm >/dev/null 2>&1; then
        print -P "%F{220}スキップ: npm が見つからないため Claude Code をアンインストールできません。%f"
        return 1
    fi

    print -P "Claude Code をアンインストールします..."
    run_cmd npm uninstall -g @anthropic-ai/claude-code || {
        print -P "%F{160}エラー: Claude Code のアンインストールに失敗しました。%f" >&2
        return 1
    }
    print -P "%F{34}Claude Code をアンインストールしました。%f"
    print -P "NOTE: ~/.claude/ ディレクトリの空ディレクトリは削除されていません。不要な場合は手動で削除してください:"
    print -P "  rm -rf ~/.claude/skills/"
}
