#!/usr/bin/env zsh

# ---------------------------------------------
# 開発環境セットアップスクリプト
#
# 使用法:
#   zsh setup.sh                  インタラクティブモード（モジュール選択）
#   zsh setup.sh --all            全モジュール一括インストール
#   zsh setup.sh --select zsh     特定モジュールを指定（複数可）
#   zsh setup.sh --dry-run        変更内容のプレビューのみ
#   zsh setup.sh --uninstall      バックアップから復元
#   zsh setup.sh --help           ヘルプ表示
#
# モジュールは modules/ ディレクトリから動的に読み込まれます。
# 新規モジュールの追加方法は modules/ 内の既存ファイルを参照してください。
# ---------------------------------------------

# --- Zsh実行確認 ---
if [ -z "$ZSH_VERSION" ]; then
    print -P "%F{160}エラー: このスクリプトは Zsh で実行する必要があります。%f" >&2
    print -P "実行例: zsh $0" >&2
    exit 1
fi


# ==============================================
# 引数パース
# ==============================================
DRY_RUN=0
UNINSTALL=0
ALL_FLAG=0
HELP_FLAG=0
typeset -a SELECT_MODULES

while (( $# > 0 )); do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --uninstall)
            UNINSTALL=1
            ;;
        --all)
            ALL_FLAG=1
            ;;
        --select)
            if (( $# < 2 )); then
                print -P "%F{160}エラー: --select にはモジュール名が必要です%f" >&2
                exit 1
            fi
            shift
            SELECT_MODULES+=("$1")
            ;;
        --help|-h)
            HELP_FLAG=1
            ;;
        *)
            print -P "%F{160}エラー: 不明なオプション: $1%f" >&2
            print -P "ヘルプ: zsh $0 --help" >&2
            exit 1
            ;;
    esac
    shift
done


# ==============================================
# 共通変数
# ==============================================
SCRIPT_DIR="${0:a:h}"
BACKUP_SUFFIX=".backup.$(command date +%Y%m%d%H%M%S)"


# ==============================================
# ヘルパー関数
# ==============================================

# dry-run 対応の実行ラッパー
# DRY_RUN=1 の場合はコマンドを表示するだけで実行しない
run_cmd() {
    if (( DRY_RUN )); then
        print -P "%F{242}  [DRY-RUN] ${(q)@}%f"
    else
        "$@"
    fi
}

# 設定ファイルのバックアップと配置を行うヘルパー（べき等性対応）
# 引数: $1=配布元パス $2=配置先パス $3=表示名 $4=未検出時の補足メッセージ
install_config() {
    local src="$1" dst="$2" label="$3" missing_hint="$4"

    # 配布元が存在しない場合は警告のみ
    if [[ ! -f "$src" ]]; then
        if [[ -n "$missing_hint" ]]; then
            print -P "%F{220}警告: ${label} が見つかりません。${missing_hint}%f"
        else
            print -P "%F{160}エラー: 配布元の ${label} が見つかりません: ${src}%f" >&2
            exit 1
        fi
        return 0
    fi

    # べき等性チェック: シンボリックリンクでなく、内容が同一ならスキップ
    if [[ -f "$dst" && ! -h "$dst" ]] && cmp -s "$src" "$dst"; then
        print -P "情報: ${label} は既に最新の状態です。スキップします。"
        return 0
    fi

    # バックアップ処理（既存ファイルまたはシンボリックリンクがある場合）
    if [[ -f "$dst" || -h "$dst" ]]; then
        run_cmd command mv "$dst" "${dst}${BACKUP_SUFFIX}" || {
            print -P "%F{160}エラー: ${label} のバックアップに失敗しました。%f" >&2
            exit 1
        }
        if (( DRY_RUN )); then
            print -P "情報: 既存の ${label} を ${dst}${BACKUP_SUFFIX} にバックアップします（予定）。"
        else
            print -P "情報: 既存の ${label} を ${dst}${BACKUP_SUFFIX} にバックアップしました。"
        fi
    fi

    # 配置処理
    run_cmd command cp -p "$src" "$dst" || {
        print -P "%F{160}エラー: ${label} の配置に失敗しました。%f" >&2
        if [[ -f "${dst}${BACKUP_SUFFIX}" ]]; then
            print -P "  バックアップは ${dst}${BACKUP_SUFFIX} に保存されています。" >&2
            print -P "  手動で復元するには: mv '${dst}${BACKUP_SUFFIX}' '$dst'" >&2
        fi
        exit 1
    }
    if (( DRY_RUN )); then
        print -P "情報: ${label} を配置予定です（dry-run）。"
    else
        print -P "情報: ${label} を配置しました。"
    fi
}

# Node.js v18+ と npm の存在を確認するヘルパー
# 戻り値: 0=利用可能, 1=利用不可
ensure_node() {
    if ! command -v node >/dev/null 2>&1; then
        print -P "%F{160}エラー: Node.js がインストールされていません。%f" >&2
        print -P "  nvm, fnm, volta 等で Node.js v18 以上をインストールしてください。" >&2
        print -P "  例: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash" >&2
        return 1
    fi

    local node_ver
    node_ver=$(node -v | sed 's/^v//' | cut -d. -f1)
    if (( node_ver < 18 )); then
        print -P "%F{160}エラー: Node.js v18 以上が必要です（現在: v${node_ver}）%f" >&2
        print -P "  Node.js をアップグレードしてください。" >&2
        return 1
    fi

    if ! command -v npm >/dev/null 2>&1; then
        print -P "%F{160}エラー: npm がインストールされていません。%f" >&2
        print -P "  Node.js に付属の npm が利用可能か確認してください。" >&2
        return 1
    fi

    return 0
}


# ==============================================
# チェックボックス選択UI（tput ベース + 再描画方式）
# ==============================================

# チェックボックスメニューを表示し、選択結果を返す
# 引数: メニュー項目の配列（"表示名|説明|デフォルト選択(0/1)" 形式）
# 出力: 選択されたインデックス（1始まり）をスペース区切りで REPLY 変数に設定
# 戻り値: 0=正常終了, 1=キャンセル（q キー）
checkbox_menu() {
    local -a items=("$@")
    local item_count=${#items}
    local cursor=1
    local -a selected
    local -a labels
    local -a descs
    local redraw=0

    # メニュー項目をパース
    for i in {1..$item_count}; do
        labels[$i]="${items[$i][(ws:|:)1]}"
        descs[$i]="${items[$i][(ws:|:)2]}"
        selected[$i]="${items[$i][(ws:|:)3]}"
    done

    # ヘッダー行数（操作説明 + 空行）
    local header_lines=2
    # 合計描画行数（ヘッダー + メニュー項目）
    local total_lines=$(( header_lines + item_count ))

    # 端末状態の保護: 異常終了時にカーソルとリセットを復帰
    trap '_checkbox_cleanup' INT TERM QUIT
    tput civis 2>/dev/null  # カーソル非表示

    # 画面下部でのスクロールスペースを事前確保
    for i in {1..$total_lines}; do print ""; done
    for i in {1..$total_lines}; do tput cuu1; done

    # 描画ループ
    while true; do
        _checkbox_draw "$item_count" "$cursor" "$header_lines" "$redraw"
        redraw=1

        # キー入力待ち
        local key=""
        read -k 1 key

        case "$key" in
            $'\e')
                # ESC シーケンスの解析（矢印キー対応）
                local key2="" key3=""
                read -k 1 -t 0.05 key2 2>/dev/null
                if [[ "$key2" == "[" || "$key2" == "O" ]]; then
                    read -k 1 -t 0.05 key3 2>/dev/null
                    case "$key3" in
                        A) # 上矢印
                            (( cursor > 1 )) && (( cursor-- ))
                            ;;
                        B) # 下矢印
                            (( cursor < item_count )) && (( cursor++ ))
                            ;;
                    esac
                fi
                ;;
            k) # vim: 上移動
                (( cursor > 1 )) && (( cursor-- ))
                ;;
            j) # vim: 下移動
                (( cursor < item_count )) && (( cursor++ ))
                ;;
            ' ') # スペース: 選択トグル
                if (( selected[$cursor] )); then
                    selected[$cursor]=0
                else
                    selected[$cursor]=1
                fi
                ;;
            a) # 全選択/全解除トグル
                local all_selected=1
                for i in {1..$item_count}; do
                    if (( ! selected[$i] )); then
                        all_selected=0
                        break
                    fi
                done
                local new_val=$(( ! all_selected ))
                for i in {1..$item_count}; do
                    selected[$i]=$new_val
                done
                ;;
            q) # キャンセル
                tput cnorm 2>/dev/null
                trap - INT TERM QUIT
                return 1
                ;;
            $'\n') # Enter: 確定
                break
                ;;
        esac
    done

    # クリーンアップ
    tput cnorm 2>/dev/null  # カーソル表示復帰
    trap - INT TERM QUIT

    # 選択されたインデックスを REPLY 変数に設定
    REPLY=""
    for i in {1..$item_count}; do
        if (( selected[$i] )); then
            REPLY+="$i "
        fi
    done
    return 0
}

# チェックボックスメニューの描画（内部関数）
_checkbox_draw() {
    local item_count=$1 cursor=$2 header_lines=$3 redraw=$4
    local total_lines=$(( header_lines + item_count ))
    local max_width=${COLUMNS:-80}

    # 再描画時は描画開始位置に戻る
    if (( redraw )); then
        for i in {1..$total_lines}; do tput cuu1; done
    fi

    # ヘッダー
    tput el
    print -P "%F{36}%B インストールするモジュールを選択してください:%b%f"
    tput el
    print -P "%F{242} (↑↓/jk: 移動, スペース: 選択, a: 全選択, Enter: 確定, q: キャンセル)%f"

    # メニュー項目
    for i in {1..$item_count}; do
        tput el  # 行末クリア（前回描画の残りを消す）

        local prefix=" "
        local check="[ ]"
        local label_color=""
        local reset=""

        if (( selected[$i] )); then
            check="[x]"
        fi

        if (( i == cursor )); then
            # カーソル行: シアン太字
            tput bold 2>/dev/null
            tput setaf 6 2>/dev/null
            prefix=">"
        fi

        # 表示文字列を組み立て、端末幅に収める
        local line=" ${prefix} ${check} ${labels[$i]}  ${descs[$i]}"
        if (( ${#line} > max_width )); then
            line="${line[1,$((max_width - 1))]}"
        fi
        print "$line"

        if (( i == cursor )); then
            tput sgr0 2>/dev/null
        fi
    done
}

# チェックボックスUIの異常終了時クリーンアップ
_checkbox_cleanup() {
    tput cnorm 2>/dev/null  # カーソル表示復帰
    tput sgr0 2>/dev/null   # 装飾リセット
    print ""
    exit 130
}


# ==============================================
# モジュール動的読み込み
# ==============================================

# modules/ ディレクトリからモジュールファイルを読み込み、
# MODULES 配列と setup_*/uninstall_* 関数を動的に構築する
load_modules() {
    local modules_dir="$SCRIPT_DIR/modules"

    if [[ ! -d "$modules_dir" ]]; then
        print -P "%F{160}エラー: modules/ ディレクトリが見つかりません: ${modules_dir}%f" >&2
        exit 1
    fi

    typeset -a _unsorted

    for module_file in "$modules_dir"/*.sh(N); do
        # 前回ループの残留関数をクリーンアップ
        unset 'functions[module_setup]' 'functions[module_uninstall]' 2>/dev/null

        # メタデータ変数をリセット
        local MODULE_ID="" MODULE_NAME="" MODULE_DESC="" MODULE_DEFAULT=0 MODULE_ORDER=50

        # モジュールファイルをソース
        if ! source "$module_file"; then
            print -P "%F{220}警告: ${module_file:t} の読み込みに失敗しました（構文エラーの可能性）。スキップします。%f" >&2
            continue
        fi

        # バリデーション: 必須メタデータの確認
        if [[ -z "$MODULE_ID" || -z "$MODULE_NAME" ]]; then
            print -P "%F{220}警告: ${module_file:t} のメタデータが不正です。スキップします。%f"
            continue
        fi

        # module_setup / module_uninstall が定義されているか確認
        if [[ -z "${functions[module_setup]}" ]]; then
            print -P "%F{220}警告: ${module_file:t} に module_setup が定義されていません。スキップします。%f"
            continue
        fi

        # functions[] で関数をリネーム（名前衝突を回避）
        local safe_id="${MODULE_ID//-/_}"

        # モジュール ID 衝突の検出（ハイフン/アンダースコア変換による衝突を含む）
        if [[ -n "${functions[setup_${safe_id}]}" ]]; then
            print -P "%F{160}エラー: モジュール '${MODULE_ID}' の関数名が既存モジュールと衝突しています。スキップします。%f" >&2
            unset 'functions[module_setup]' 'functions[module_uninstall]'
            continue
        fi

        functions[setup_${safe_id}]=$functions[module_setup]
        unset 'functions[module_setup]'

        if [[ -n "${functions[module_uninstall]}" ]]; then
            functions[uninstall_${safe_id}]=$functions[module_uninstall]
            unset 'functions[module_uninstall]'
        fi

        # ORDER 付きで一時配列に格納（後でソート）
        _unsorted+=("$(printf '%03d' "$MODULE_ORDER")|${MODULE_ID}|${MODULE_NAME}|${MODULE_DESC}|${MODULE_DEFAULT}")
    done

    if (( ${#_unsorted} == 0 )); then
        print -P "%F{160}エラー: 有効なモジュールが見つかりません。%f" >&2
        exit 1
    fi

    # MODULE_ORDER でソートして MODULES 配列を構築
    MODULES=()
    for entry in ${(o)_unsorted}; do
        # ORDER 部分（先頭の "NNN|"）を除去
        MODULES+=("${entry#*|}")
    done
}

# モジュールを読み込む
load_modules


# ==============================================
# ヘルプ表示（モジュール読み込み後に動的生成）
# ==============================================
if (( HELP_FLAG )); then
    print -P "使用法: zsh $0 [オプション]"
    print -P ""
    print -P "オプション:"
    print -P "  --dry-run          変更内容のプレビューのみ（実際には変更しない）"
    print -P "  --uninstall        全モジュールをアンインストール（バックアップから復元）"
    print -P "  --all              全モジュールを一括インストール"
    print -P "  --select MODULE    特定モジュールを指定（複数指定可）"
    print -P "  --help, -h         このヘルプを表示"
    print -P ""
    print -P "モジュール:"
    for entry in "${MODULES[@]}"; do
        printf "  %-14s %s (%s)\n" "${entry[(ws:|:)1]}" "${entry[(ws:|:)2]}" "${entry[(ws:|:)3]}"
    done
    print -P ""
    print -P "例:"
    print -P "  zsh $0                              インタラクティブ選択"
    print -P "  zsh $0 --all                        全モジュール一括"
    print -P "  zsh $0 --select zsh --select claude-code  複数指定"
    print -P "  zsh $0 --all --dry-run              全モジュールをプレビュー"
    exit 0
fi


# ==============================================
# --select バリデーション（モジュール読み込み後に検証）
# ==============================================
for mod_id in "${SELECT_MODULES[@]}"; do
    typeset found=0
    for entry in "${MODULES[@]}"; do
        if [[ "${entry[(ws:|:)1]}" == "$mod_id" ]]; then
            found=1
            break
        fi
    done
    if (( ! found )); then
        print -P "%F{160}エラー: 不明なモジュール: ${mod_id}%f" >&2
        print -P "利用可能なモジュール:" >&2
        for entry in "${MODULES[@]}"; do
            print -P "  ${entry[(ws:|:)1]}" >&2
        done
        exit 1
    fi
done


# ==============================================
# モジュール実行ディスパッチ
# ==============================================

# モジュール ID からセットアップ関数を動的に実行
run_module_setup() {
    local module_id="$1"
    local func_name="setup_${module_id//-/_}"
    if [[ -n "${functions[$func_name]}" ]]; then
        "$func_name"
    else
        print -P "%F{160}エラー: 不明なモジュール: ${module_id}%f" >&2
        return 1
    fi
}

# モジュール ID からアンインストール関数を動的に実行
# NOTE: module_uninstall が未定義のモジュールは正常にスキップする
run_module_uninstall() {
    local module_id="$1"
    local func_name="uninstall_${module_id//-/_}"
    if [[ -n "${functions[$func_name]}" ]]; then
        "$func_name"
    else
        print -P "情報: ${module_id} にはアンインストール処理が定義されていません。スキップします。"
        return 0
    fi
}


# ==============================================
# アンインストールモード
# NOTE: --uninstall は常に全モジュールを対象にする
# ==============================================
if (( UNINSTALL )); then
    print -P "全モジュールのアンインストール（復元）を開始します..."
    print -P "============================================="

    if (( DRY_RUN )); then
        print -P "%F{33}[DRY-RUN モード] 実際には変更を行いません。%f"
        print -P "---------------------------------------------"
    fi

    typeset -i uninstall_errors=0

    # NOTE: セットアップと逆順（MODULE_ORDER 降順）でアンインストールする
    for entry in "${(@Oa)MODULES}"; do
        typeset mod_id="${entry[(ws:|:)1]}"
        typeset mod_name="${entry[(ws:|:)2]}"
        print -P ""
        print -P "%F{36}%B[${mod_name}]%b%f"
        print -P "---------------------------------------------"
        if ! run_module_uninstall "$mod_id"; then
            (( uninstall_errors++ ))
        fi
    done

    print -P ""
    print -P "============================================="
    if (( uninstall_errors > 0 )); then
        print -P "%F{220}アンインストールが完了しましたが、${uninstall_errors} 件のモジュールでエラーが発生しました。%f"
        print -P "============================================="
        exit 1
    else
        print -P "%F{34}アンインストールが完了しました。%f"
        print -P "============================================="
        exit 0
    fi
fi


# ==============================================
# 通常セットアップモード
# ==============================================
print -P ""
print -P "%F{36}%B 開発環境セットアップ%b%f"
print -P "============================================="

if (( DRY_RUN )); then
    print -P "%F{33}[DRY-RUN モード] 実際には変更を行いません。%f"
    print -P "---------------------------------------------"
fi

print -P "情報: Zsh で実行されています (バージョン: $ZSH_VERSION)"
print -P "---------------------------------------------"

# --- モジュール選択 ---
typeset -a selected_module_ids

if (( ${#SELECT_MODULES[@]} > 0 )); then
    # --select で明示指定された場合（MODULE_ORDER 順に並べ替え）
    for entry in "${MODULES[@]}"; do
        typeset mod_id="${entry[(ws:|:)1]}"
        if (( ${SELECT_MODULES[(I)$mod_id]} )); then
            selected_module_ids+=("$mod_id")
        fi
    done

elif (( ALL_FLAG )); then
    # --all の場合: 全モジュールを選択
    for entry in "${MODULES[@]}"; do
        selected_module_ids+=("${entry[(ws:|:)1]}")
    done

elif [[ -t 0 ]]; then
    # TTY 環境: インタラクティブ選択（チェックボックスUI）
    print -P ""

    if ! command -v tput >/dev/null 2>&1; then
        # tput が利用できない場合はデフォルト選択のモジュールのみインストール
        print -P "%F{220}情報: tput が利用できないため、デフォルトのモジュールをインストールします。%f"
        for entry in "${MODULES[@]}"; do
            if (( ${entry[(ws:|:)4]} == 1 )); then
                selected_module_ids+=("${entry[(ws:|:)1]}")
            fi
        done
    else
        # チェックボックスメニュー用の項目を構築
        typeset -a menu_items
        for entry in "${MODULES[@]}"; do
            typeset mod_name="${entry[(ws:|:)2]}"
            typeset mod_desc="${entry[(ws:|:)3]}"
            typeset mod_default="${entry[(ws:|:)4]}"
            menu_items+=("${mod_name}|${mod_desc}|${mod_default}")
        done

        # チェックボックスメニュー表示
        checkbox_menu "${menu_items[@]}"
        typeset menu_status=$?
        typeset selection="$REPLY"

        if (( menu_status != 0 )); then
            print -P ""
            print -P "%F{220}キャンセルされました。%f"
            exit 0
        fi

        if [[ -z "$selection" ]]; then
            print -P ""
            print -P "%F{220}モジュールが選択されませんでした。終了します。%f"
            exit 0
        fi

        # 選択されたインデックスからモジュール ID を取得
        for idx in ${(s: :)selection}; do
            selected_module_ids+=("${MODULES[$idx][(ws:|:)1]}")
        done
    fi

    print -P ""
else
    # 非 TTY 環境（CI / パイプ）: --all と同等
    print -P "情報: 非インタラクティブ環境を検出。全モジュールをインストールします。"
    for entry in "${MODULES[@]}"; do
        selected_module_ids+=("${entry[(ws:|:)1]}")
    done
fi

# 選択されたモジュールを表示
print -P ""
print -P "%F{36}選択されたモジュール:%f"
for mod_id in "${selected_module_ids[@]}"; do
    for entry in "${MODULES[@]}"; do
        if [[ "${entry[(ws:|:)1]}" == "$mod_id" ]]; then
            print -P "  - ${entry[(ws:|:)2]} (${entry[(ws:|:)3]})"
            break
        fi
    done
done
print -P "---------------------------------------------"

# --- 選択されたモジュールを順次セットアップ ---
typeset -i setup_errors=0
for mod_id in "${selected_module_ids[@]}"; do
    if ! run_module_setup "$mod_id"; then
        (( setup_errors++ ))
    fi
done

# --- 完了 ---
print -P ""
print -P "============================================="
if (( DRY_RUN )); then
    print -P "%F{33}[DRY-RUN] 上記が実行される変更内容です。実際に適用するには --dry-run を外して再実行してください。%f"
elif (( setup_errors > 0 )); then
    print -P "%F{220}セットアップが完了しましたが、${setup_errors} 件のモジュールでエラーが発生しました。%f"
else
    print -P "%F{34}セットアップが正常に完了しました。%f"

    # Zsh が選択されていた場合のみシェル再起動を案内
    for mod_id in "${selected_module_ids[@]}"; do
        if [[ "$mod_id" == "zsh" ]]; then
            print -P "全ての変更を有効にするために、Zsh シェルを%B再起動%bするか '%Bexec zsh%b' を実行してください。"
            print -P "(source ~/.zshrc は環境が汚れる場合があるため、exec zsh を推奨します)"
            break
        fi
    done
fi
print -P "============================================="

if (( setup_errors > 0 )); then
    exit 1
fi
exit 0
