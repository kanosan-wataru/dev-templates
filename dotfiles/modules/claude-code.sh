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
CLAUDE_MOD_MCP_TEMPLATE="$SCRIPT_DIR/.claude/mcp-servers.json"
CLAUDE_MOD_CLAUDE_JSON="$HOME/.claude.json"

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
    # Shared shell module: .env loading (environment variables for MCP servers)
    "$SCRIPT_DIR/.shell/env.sh|${HOME}/.shell/env.sh|.shell/env.sh|"
    # エージェント定義
    "$SCRIPT_DIR/.claude/agents/general-purpose.md|$CLAUDE_MOD_CONFIG_DIR/agents/general-purpose.md|agents/general-purpose.md|"
    "$SCRIPT_DIR/.claude/agents/gemini-explore.md|$CLAUDE_MOD_CONFIG_DIR/agents/gemini-explore.md|agents/gemini-explore.md|"
    "$SCRIPT_DIR/.claude/agents/codex-debugger.md|$CLAUDE_MOD_CONFIG_DIR/agents/codex-debugger.md|agents/codex-debugger.md|"
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
    "$CLAUDE_MOD_CONFIG_DIR/agents"
    "${HOME}/.shell"
)

# --- MCP サーバー設定のマージ ---
# テンプレートの mcpServers を ~/.claude.json にマージする（既存設定を保持）
# jq が必要。未インストールの場合は警告してスキップする。
_claude_mod_merge_mcp_servers() {
    local template="$CLAUDE_MOD_MCP_TEMPLATE"
    local target="$CLAUDE_MOD_CLAUDE_JSON"

    # テンプレートファイルの存在確認
    if [[ ! -f "$template" ]]; then
        msg_warn "MCP サーバーテンプレートが見つかりません: ${template}"
        msg_step "MCP サーバー設定のマージをスキップします。"
        return 0
    fi

    # jq の存在確認
    if ! command -v jq >/dev/null 2>&1; then
        msg_warn "jq がインストールされていないため、MCP サーバー設定のマージをスキップします。"
        msg_step "手動で設定するか、jq をインストールして再実行してください:"
        msg_step "  sudo apt install jq  # Debian/Ubuntu"
        msg_step "  brew install jq      # macOS"
        return 0
    fi

    # テンプレートの JSON バリデーション
    if ! jq empty "$template" 2>/dev/null; then
        msg_error "MCP サーバーテンプレートの JSON が不正です: ${template}"
        return 1
    fi

    # ターゲットファイルが存在しない場合: テンプレートの内容でそのまま作成
    if [[ ! -f "$target" ]]; then
        if ((DRY_RUN)); then
            msg_info "${target} を新規作成予定です（dry-run）。"
        else
            # NOTE: jq でフォーマットしてから書き出す（一時ファイル経由でアトミックに書き込む）
            local tmpfile
            tmpfile=$(mktemp "${target}.tmp.XXXXXX") || {
                msg_error "一時ファイルの作成に失敗しました。"
                return 1
            }
            jq '.' "$template" >"$tmpfile" || {
                command rm -f "$tmpfile"
                msg_error "${target} の作成に失敗しました。"
                return 1
            }
            command mv "$tmpfile" "$target" || {
                command rm -f "$tmpfile"
                msg_error "${target} への移動に失敗しました。"
                return 1
            }
            # NOTE: このモジュールで新規作成したことを記録するマーカーファイル
            touch "${target}.created-by-claude-mod"
            msg_info "${target} を新規作成しました（MCP サーバー設定）。"
        fi
        return 0
    fi

    # 既存ファイルの JSON バリデーション
    if ! jq empty "$target" 2>/dev/null; then
        msg_error "${target} の JSON が不正です。手動で修正してください。"
        return 1
    fi

    # べき等性チェック: テンプレートの mcpServers が既に全て同一内容で存在するかを確認
    local needs_update
    needs_update=$(jq --slurpfile tmpl "$template" '
        # テンプレートの mcpServers を取得
        ($tmpl[0].mcpServers // {}) as $new_servers |
        # 既存の mcpServers を取得
        (.mcpServers // {}) as $existing |
        # 全てのテンプレートキーが既存に同一内容で存在するか判定
        [
            $new_servers | to_entries[] |
            select(
                ($existing[.key] // null) != .value
            )
        ] | length > 0
    ' "$target" 2>/dev/null) || {
        msg_error "MCP サーバー設定の比較に失敗しました。"
        return 1
    }

    if [[ "$needs_update" == "false" ]]; then
        msg_info "MCP サーバー設定は既に最新の状態です。スキップします。"
        return 0
    fi

    # バックアップを作成してからマージ
    run_cmd command cp -p "$target" "${target}${BACKUP_SUFFIX}" || {
        msg_error "${target} のバックアップに失敗しました。"
        return 1
    }
    if ((DRY_RUN)); then
        msg_info "${target} を ${target}${BACKUP_SUFFIX} にバックアップ予定です（dry-run）。"
        msg_info "MCP サーバー設定をマージ予定です（dry-run）。"
        return 0
    fi
    msg_info "${target} を ${target}${BACKUP_SUFFIX} にバックアップしました。"

    # jq の再帰マージ (*) で mcpServers をマージ
    # NOTE: * 演算子はオブジェクトを再帰的にマージし、右辺（テンプレート）で上書きする
    local merged
    merged=$(jq --slurpfile tmpl "$template" '
        .mcpServers = ((.mcpServers // {}) * ($tmpl[0].mcpServers // {}))
    ' "$target" 2>/dev/null) || {
        msg_error "MCP サーバー設定のマージに失敗しました。"
        printf '%s\n' "  バックアップから復元するには: mv '${target}${BACKUP_SUFFIX}' '${target}'" >&2
        return 1
    }

    # マージ結果を書き出し（一時ファイル経由でアトミックに書き込む）
    local tmpfile
    tmpfile=$(mktemp "${target}.tmp.XXXXXX") || {
        msg_error "一時ファイルの作成に失敗しました。"
        return 1
    }
    printf '%s\n' "$merged" >"$tmpfile" || {
        command rm -f "$tmpfile"
        msg_error "${target} への書き込みに失敗しました。"
        printf '%s\n' "  バックアップから復元するには: mv '${target}${BACKUP_SUFFIX}' '${target}'" >&2
        return 1
    }
    command mv "$tmpfile" "$target" || {
        command rm -f "$tmpfile"
        msg_error "${target} への移動に失敗しました。"
        printf '%s\n' "  バックアップから復元するには: mv '${target}${BACKUP_SUFFIX}' '${target}'" >&2
        return 1
    }

    msg_info "MCP サーバー設定をマージしました。"
}

# --- MCP サーバー設定の削除 ---
# テンプレートに定義されたサーバー名を ~/.claude.json から削除する
# NOTE: ~/.claude.json 自体は削除しない（他の設定が含まれるため）
_claude_mod_remove_mcp_servers() {
    local template="$CLAUDE_MOD_MCP_TEMPLATE"
    local target="$CLAUDE_MOD_CLAUDE_JSON"

    # ターゲットファイルが存在しない場合はスキップ
    if [[ ! -f "$target" ]]; then
        msg_info "${target} が存在しません。MCP サーバー設定の削除をスキップします。"
        return 0
    fi

    # jq の存在確認
    if ! command -v jq >/dev/null 2>&1; then
        msg_warn "jq がインストールされていないため、MCP サーバー設定の削除をスキップします。"
        return 0
    fi

    # テンプレートが存在しない場合はスキップ
    if [[ ! -f "$template" ]]; then
        msg_warn "MCP サーバーテンプレートが見つかりません。MCP サーバー設定の削除をスキップします。"
        return 0
    fi

    # 既存ファイルの JSON バリデーション
    if ! jq empty "$target" 2>/dev/null; then
        msg_warn "${target} の JSON が不正です。MCP サーバー設定の削除をスキップします。"
        return 0
    fi

    # mcpServers キーが存在しない場合はスキップ
    local has_mcp_servers
    has_mcp_servers=$(jq 'has("mcpServers")' "$target" 2>/dev/null)
    if [[ "$has_mcp_servers" != "true" ]]; then
        msg_info "${target} に mcpServers が存在しません。スキップします。"
        return 0
    fi

    # テンプレートからサーバー名のリストを取得
    local -a server_names
    while IFS= read -r name; do
        server_names+=("$name")
    done < <(jq -r '.mcpServers | keys[]' "$template" 2>/dev/null)
    if ((${#server_names[@]} == 0)); then
        msg_info "削除対象の MCP サーバーがありません。スキップします。"
        return 0
    fi

    # 削除対象のサーバーが一つも存在しないか確認
    local has_any=0
    for name in "${server_names[@]}"; do
        local exists
        exists=$(jq --arg n "$name" '.mcpServers | has($n)' "$target" 2>/dev/null)
        if [[ "$exists" == "true" ]]; then
            has_any=1
            break
        fi
    done

    if ((!has_any)); then
        msg_info "削除対象の MCP サーバーは存在しません。スキップします。"
        return 0
    fi

    # バックアップ
    run_cmd command cp -p "$target" "${target}${BACKUP_SUFFIX}" || {
        msg_error "${target} のバックアップに失敗しました。"
        return 1
    }
    if ((DRY_RUN)); then
        msg_info "${target} を ${target}${BACKUP_SUFFIX} にバックアップ予定です（dry-run）。"
        msg_info "MCP サーバー設定を削除予定です（dry-run）: ${server_names[*]}"
        return 0
    fi
    msg_info "${target} を ${target}${BACKUP_SUFFIX} にバックアップしました。"

    # jq でテンプレートに定義されたサーバーを一括削除
    # NOTE: jq の del() でキーを削除。サーバー名リストを JSON 配列として渡す
    local names_json
    names_json=$(printf '%s\n' "${server_names[@]}" | jq -R . | jq -s .)

    local result
    result=$(jq --argjson names "$names_json" '
        .mcpServers |= (. // {} | to_entries | map(select(.key as $k | $names | index($k) | not)) | from_entries)
    ' "$target" 2>/dev/null) || {
        msg_error "MCP サーバー設定の削除に失敗しました。"
        printf '%s\n' "  バックアップから復元するには: mv '${target}${BACKUP_SUFFIX}' '${target}'" >&2
        return 1
    }

    # 結果を書き出し（一時ファイル経由でアトミックに書き込む）
    local tmpfile
    tmpfile=$(mktemp "${target}.tmp.XXXXXX") || {
        msg_error "一時ファイルの作成に失敗しました。"
        return 1
    }
    printf '%s\n' "$result" >"$tmpfile" || {
        command rm -f "$tmpfile"
        msg_error "${target} への書き込みに失敗しました。"
        printf '%s\n' "  バックアップから復元するには: mv '${target}${BACKUP_SUFFIX}' '${target}'" >&2
        return 1
    }
    command mv "$tmpfile" "$target" || {
        command rm -f "$tmpfile"
        msg_error "${target} への移動に失敗しました。"
        printf '%s\n' "  バックアップから復元するには: mv '${target}${BACKUP_SUFFIX}' '${target}'" >&2
        return 1
    }

    msg_info "MCP サーバー設定を削除しました: ${server_names[*]}"

    # このモジュールで作成したファイルで、mcpServers 以外のキーがなく mcpServers が空の場合のみ削除
    if [[ -f "${target}.created-by-claude-mod" ]]; then
        local total_keys remaining_servers
        total_keys=$(jq 'keys | length' "$target" 2>/dev/null)
        remaining_servers=$(jq '.mcpServers | length' "$target" 2>/dev/null)
        # mcpServers のみ（キー数1）かつ中身が空の場合のみファイル削除
        if [[ "$total_keys" == "1" ]] && [[ "$remaining_servers" == "0" ]]; then
            command rm -f "$target" "${target}.created-by-claude-mod"
            msg_info "${target} はこのモジュールで作成されたため削除しました。"
        elif [[ "$remaining_servers" == "0" ]]; then
            # mcpServers は空だが他のキーが存在する場合はマーカーのみ削除
            command rm -f "${target}.created-by-claude-mod"
            msg_info "${target} の mcpServers は空ですが、他の設定が存在するためファイルは保持します。"
        fi
    fi
}

# --- セットアップ ---
setup_claude_code() {
    msg_header "Claude Code"
    print_separator

    # =========================================
    # CLI インストール
    # =========================================

    # べき等性チェック
    if command -v claude >/dev/null 2>&1 && ! ((UPGRADE)); then
        local current_ver
        current_ver=$(claude --version 2>/dev/null || printf '%s' "unknown")
        msg_info "Claude Code は既にインストールされています (${current_ver})。スキップします。"
    else
        # Upgrade path: show info message when upgrading an existing installation
        if command -v claude >/dev/null 2>&1 && ((UPGRADE)); then
            msg_info "Claude Code のアップグレードを実行します..."
        fi
        # Node.js / npm の確認
        if ! ensure_node; then
            msg_warn "Claude Code のインストールには Node.js v18+ が必要です。"
            return 1
        fi

        msg_info "Claude Code をインストールします..."
        run_cmd npm install -g @anthropic-ai/claude-code || {
            msg_error "Claude Code のインストールに失敗しました。"
            msg_step "npm install -g の権限エラーの場合:" >&2
            msg_step "  npm config set prefix ~/.local" >&2
            msg_step "または nvm/fnm をお使いの場合は sudo 不要です。" >&2
            return 1
        }

        if ((DRY_RUN)); then
            msg_info "Claude Code をインストール予定です（dry-run）。"
        else
            msg_success "Claude Code のインストールが完了しました。"
            printf '\n'
            printf '%s\n' "初回セットアップ:"
            msg_step "claude  # 対話的に API キーを設定"
            msg_step "詳細: https://docs.anthropic.com/en/docs/claude-code"
        fi
    fi

    # =========================================
    # 設定ファイルの配置
    # =========================================
    printf '\n'
    msg_info "設定ファイルを配置します..."

    # 必要なディレクトリを事前作成
    for dir in "${CLAUDE_MOD_REQUIRED_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            run_cmd command mkdir -p "$dir" || {
                msg_error "${dir} の作成に失敗しました。"
                return 1
            }
            if ((DRY_RUN)); then
                msg_info "${dir} を作成予定です（dry-run）。"
            else
                msg_info "${dir} を作成しました。"
            fi
        fi
    done

    # 設定ファイルの配置
    for entry in "${CLAUDE_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r src dst label hint <<<"$entry"
        install_config "$src" "$dst" "$label" "$hint"
    done

    # MCP サーバー設定のマージ（~/.claude.json に追加）
    _claude_mod_merge_mcp_servers || return 1

    msg_success "Claude Code 設定ファイルの配置が完了しました。"
}

# --- ステータス表示 ---
module_status() {
    local status version
    if command -v claude &>/dev/null; then
        version=$(claude --version 2>/dev/null | head -1 || printf '%s' "installed")
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "$version"
    else
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
    fi
}

# --- アンインストール ---
uninstall_claude_code() {
    local restored=0

    # =========================================
    # MCP サーバー設定の削除（~/.claude.json から除去）
    # =========================================
    _claude_mod_remove_mcp_servers || return 1

    # =========================================
    # 設定ファイルの復元・削除
    # =========================================
    for entry in "${CLAUDE_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r _src dst label _hint <<<"$entry"

        # find_newest_backup で最新のバックアップを検索
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
            msg_warn "${label} のバックアップが見つかりません。手動で確認してください: ${dst}"
        else
            msg_info "${label} は配置されていません。スキップします。"
        fi
    done

    if ((restored)); then
        msg_success "Claude Code 設定ファイルのアンインストールが完了しました。"
    else
        msg_info "Claude Code 設定ファイルの復元・削除対象はありませんでした。"
    fi

    # =========================================
    # CLI アンインストール
    # =========================================

    # インストール状態を判定（コマンドの存在 or npm パッケージの存在）
    if ! command -v claude >/dev/null 2>&1; then
        if ! { command -v npm >/dev/null 2>&1 && npm ls -g @anthropic-ai/claude-code >/dev/null 2>&1; }; then
            msg_info "Claude Code はインストールされていません。スキップします。"
            return 0
        fi
    fi

    if ! command -v npm >/dev/null 2>&1; then
        msg_warn "npm が見つからないため Claude Code をアンインストールできません。"
        return 1
    fi

    msg_info "Claude Code をアンインストールします..."
    run_cmd npm uninstall -g @anthropic-ai/claude-code || {
        msg_error "Claude Code のアンインストールに失敗しました。"
        return 1
    }
    msg_success "Claude Code をアンインストールしました。"
    printf '%s\n' "NOTE: ~/.claude/ ディレクトリの空ディレクトリは削除されていません。不要な場合は手動で削除してください:"
    msg_step "rm -rf ~/.claude/skills/"
}
