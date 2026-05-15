#!/usr/bin/env bash
# 設定ディレクトリ単位のインストール/アンインストール共通ヘルパ
# 配布元配下の全ファイルを install_config で再帰配置し、バックアップから復元する

# 依存:
#   - setup.sh の install_config / run_cmd / DRY_RUN / msg_warn / msg_error
#   - lib/backup.sh の find_newest_backup
#   - bash 4.3+ (uninstall_tree の nameref)

# 配布元ディレクトリ配下の全ファイルを install_config で配置する
# 親ディレクトリは必要に応じて mkdir -p する
# 引数:
#   $1=src_dir       配布元ディレクトリ
#   $2=dst_dir       配置先ディレクトリ
#   $3=label_prefix  メッセージ表示用ラベルのプレフィックス (例: "agents", ".copilot")
install_tree() {
    local src_dir="$1" dst_dir="$2" label_prefix="$3"

    if [[ ! -d "$src_dir" ]]; then
        msg_warn "配布元ディレクトリが見つかりません: ${src_dir}"
        return 0
    fi

    local src_file rel_path dst_file dst_parent
    local count=0
    while IFS= read -r -d '' src_file; do
        rel_path="${src_file#"$src_dir"/}"
        dst_file="${dst_dir}/${rel_path}"
        dst_parent="$(dirname "$dst_file")"

        # install_config は cp -p のみで親を作らないため、ここで先回りで作成
        if [[ ! -d "$dst_parent" ]]; then
            run_cmd command mkdir -p "$dst_parent" || {
                msg_error "${dst_parent} の作成に失敗しました。"
                return 1
            }
        fi

        # install_config が失敗 (戻り値非0) を返した場合は伝播する
        # NOTE: 現状 install_config はハード失敗時 exit 1 だが、将来の戻り値変更で
        # サイレント失敗にならないよう明示的に伝播する
        # quiet=1: 個別 info を抑制し、ループ完了後にサマリ 1 行のみ出力する
        install_config "$src_file" "$dst_file" "${label_prefix}/${rel_path}" "" 1 || return $?
        count=$((count + 1))
    done < <(find "$src_dir" -type f -print0)

    if ((count > 0)); then
        msg_info "${label_prefix}: ${count} ファイルを配置/同期しました。"
    fi
}

# 配布元の管理対象ファイルに対応する配置先をバックアップから復元する
# 配置先側の非管理ファイル (ユーザーデータ等) には触らないため src-iter
# 引数:
#   $1=src_dir       配布元ディレクトリ (管理対象を確定するため)
#   $2=dst_dir       配置先ディレクトリ
#   $3=label_prefix  メッセージ表示用ラベルのプレフィックス
#   $4=counter_var   復元件数をインクリメントするグローバル変数名 (nameref)
# NOTE: 復元発生時に counter_var をインクリメント (DRY_RUN 時はインクリメントしない)
# NOTE: 人間向けメッセージは stderr へ送る (呼び出し側が $() でキャプチャしないため)
# NOTE: nameref 名 (__install_tree_counter_ref) は循環参照回避のためサニタイズ済みの sentinel
uninstall_tree() {
    local src_dir="$1" dst_dir="$2" label_prefix="$3"
    local -n __install_tree_counter_ref="$4"

    [[ -d "$src_dir" ]] || return 0
    [[ -d "$dst_dir" ]] || return 0

    local src_file rel_path dst_file label
    while IFS= read -r -d '' src_file; do
        rel_path="${src_file#"$src_dir"/}"
        dst_file="${dst_dir}/${rel_path}"
        label="${label_prefix}/${rel_path}"
        restore_file_from_backup "$dst_file" "$label" __install_tree_counter_ref || return 1
    done < <(find "$src_dir" -type f -print0)
}

# 単一ファイルをバックアップから復元する (uninstall_tree や個別ファイル復元ループから使用)
# 引数:
#   $1=dst_file       配置先ファイルパス
#   $2=label          表示用ラベル
#   $3=counter_var    復元時にインクリメントする変数名 (nameref, DRY_RUN 時は変更しない)
# NOTE: バックアップが見つからず dst_file が存在する場合は警告のみ
# NOTE: 人間向けメッセージは stderr へ送る
restore_file_from_backup() {
    local dst_file="$1" label="$2"
    local -n __install_tree_counter_ref="$3"
    local newest backup_name
    newest=$(find_newest_backup "${dst_file}.backup."'*') || true

    if [[ -n "$newest" ]]; then
        backup_name=$(basename "$newest")
        if ((DRY_RUN)); then
            msg_dry_run "${label} を ${backup_name} から復元予定です。"
        else
            printf '%s\n' "復元: ${label} をバックアップ (${backup_name}) から戻します。" >&2
        fi
        run_cmd command mv "$newest" "$dst_file" || {
            msg_error "${label} の復元に失敗しました。"
            return 1
        }
        # DRY_RUN 中はカウンタを増やさない (実復元件数の表示を嘘にしないため)
        if ! ((DRY_RUN)); then
            __install_tree_counter_ref=$((__install_tree_counter_ref + 1))
        fi
    elif [[ -f "$dst_file" || -L "$dst_file" ]]; then
        msg_warn "${label} のバックアップが見つかりません。手動で確認してください: ${dst_file}"
    fi
}
