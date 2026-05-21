# ---------------------------------------------
# setup.sh で使うオーケストレーション系ヘルパー
#
# 抽出理由: 以前は setup.sh 内に inline 定義されていたが、テスト側で
# verbatim copy を維持する負担が大きく、本番との silent drift リスクが
# あった。lib に切り出して setup.sh とテスト双方から source できる
# 形にする。
#
# 依存: lib/colors.sh (msg_*), lib/array.sh (array_contains)
#       caller scope の変数:
#         - ensure_node:        (なし。node/npm を $PATH から検索)
#         - resolve_module_deps: MODULE_DEPS_MAP, MODULE_ID_SET, MODULES,
#                                selected_module_ids
# ---------------------------------------------

# Verify Node.js and npm availability
# Args: $1=minimum major version (default: 18)
# Returns: 0=available, 1=unavailable
ensure_node() {
    local min_version="${1:-18}"

    if ! command -v node >/dev/null 2>&1; then
        msg_error "Node.js がインストールされていません。"
        printf '  nvm, fnm, volta 等で Node.js v%s 以上をインストールしてください。\n' "$min_version" >&2
        printf '  例: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash\n' >&2
        return 1
    fi

    local node_ver
    node_ver=$(node -v | sed 's/^v//' | cut -d. -f1)

    # Validate numeric values
    if [[ ! "$min_version" =~ ^[0-9]+$ ]]; then
        msg_error "ensure_node に不正な引数が渡されました: ${min_version}"
        return 1
    fi
    if [[ ! "$node_ver" =~ ^[0-9]+$ ]]; then
        msg_error "Node.js のバージョンを取得できませんでした。"
        return 1
    fi

    if ((node_ver < min_version)); then
        msg_error "Node.js v${min_version} 以上が必要です（現在: v${node_ver}）"
        printf '  Node.js をアップグレードしてください。\n' >&2
        return 1
    fi

    if ! command -v npm >/dev/null 2>&1; then
        msg_error "npm がインストールされていません。"
        printf '  Node.js に付属の npm が利用可能か確認してください。\n' >&2
        return 1
    fi

    return 0
}

# Resolve module dependencies and auto-add missing dependency modules
# Modifies: selected_module_ids (adds missing dependencies)
resolve_module_deps() {
    local -a added_deps=()
    local changed=1
    # 防御的上限: monotonic に追加されるため通常 N + 1 回で収束する
    # (N = MODULE_ID_SET 全要素、+1 は終了検知の最終反復)。
    # この上限を超えるのは MODULE_DEPS_MAP 異常 / 将来 loop body が
    # 非 monotonic に変更されたケースのみ。後者の場合、このガードが
    # 無限ループに対する唯一の防壁になる点に注意。
    local max_iter=$((${#MODULE_ID_SET[@]} + 1))
    local iter=0

    # Iterate until no more transitive dependencies are found
    while ((changed)); do
        changed=0
        if ((++iter > max_iter)); then
            msg_error "依存関係の解決が ${max_iter} 反復を超えました（循環依存または異常なメタデータの可能性）。"
            printf '  選択中のモジュール: %s\n' "${selected_module_ids[*]}" >&2
            exit 1
        fi
        for mod_id in "${selected_module_ids[@]}"; do
            local deps="${MODULE_DEPS_MAP[$mod_id]:-}"
            [[ -z "$deps" ]] && continue

            # MODULE_DEPS is a space-separated list
            read -ra _deps <<<"$deps"
            local dep
            for dep in "${_deps[@]}"; do
                # Check if dep is already selected
                if ! array_contains "$dep" "${selected_module_ids[@]}"; then
                    # O(1) existence check
                    if [[ -n "${MODULE_ID_SET[$dep]:-}" ]]; then
                        selected_module_ids+=("$dep")
                        added_deps+=("$dep")
                        changed=1
                    else
                        msg_warn "モジュール '${mod_id}' の依存先 '${dep}' が見つかりません。"
                    fi
                fi
            done
        done
    done

    # Notify user of auto-added dependencies
    if ((${#added_deps[@]} > 0)); then
        printf '\n'
        color_print "$C_CYAN" "依存関係の自動解決:"
        for dep in "${added_deps[@]}"; do
            printf '  + %s (依存先として自動追加)\n' "$dep"
        done
        printf '\n'
    fi

    # Re-sort by MODULE_ORDER so dependencies are installed first
    if ((${#added_deps[@]} > 0)); then
        local -a sorted_ids=()
        local entry entry_id
        for entry in "${MODULES[@]}"; do
            entry_id="${entry%%|*}"
            if array_contains "$entry_id" "${selected_module_ids[@]}"; then
                sorted_ids+=("$entry_id")
            fi
        done
        selected_module_ids=("${sorted_ids[@]}")
    fi
}
