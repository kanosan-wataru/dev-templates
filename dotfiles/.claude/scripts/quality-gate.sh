#!/bin/bash
# quality-gate.sh -- PostToolUse hook (Edit/Write)
# 編集後に一般的な品質問題をチェックする

# stdin からツール入力を読み取る
INPUT=$(cat)

# ファイルパスを抽出（JSON入力から）
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('file_path', data.get('filePath', '')))
except:
    print('')
" 2>/dev/null)

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# 拡張子を取得
EXT="${FILE_PATH##*.}"

ISSUES=""

# console.log チェック（JS/TS ファイル）
if [[ "$EXT" =~ ^(js|ts|jsx|tsx)$ ]]; then
  CONSOLE_COUNT=$(grep -c "console\.log" "$FILE_PATH" 2>/dev/null || echo "0")
  if [ "$CONSOLE_COUNT" -gt 0 ]; then
    ISSUES="${ISSUES}\n  ${CONSOLE_COUNT} console.log found in ${FILE_PATH}"
  fi
fi

# print() チェック（Python ファイル、テスト以外）
if [[ "$EXT" == "py" ]] && [[ "$FILE_PATH" != *"test_"* ]] && [[ "$FILE_PATH" != *"_test.py" ]]; then
  PRINT_COUNT=$(grep -cE "^\s*print\(" "$FILE_PATH" 2>/dev/null || echo "0")
  if [ "$PRINT_COUNT" -gt 3 ]; then
    ISSUES="${ISSUES}\n  ${PRINT_COUNT} print() calls in ${FILE_PATH} (use logging instead?)"
  fi
fi

# TODO/FIXME チェック（新規追加のみ -- git diffで確認）
TODO_COUNT=$(git diff HEAD -- "$FILE_PATH" 2>/dev/null | grep "^+" | grep -ciE "(TODO|FIXME|HACK|XXX)" || echo "0")
if [ "$TODO_COUNT" -gt 0 ]; then
  ISSUES="${ISSUES}\n  ${TODO_COUNT} new TODO/FIXME added in ${FILE_PATH}"
fi

if [ -n "$ISSUES" ]; then
  echo -e "$ISSUES" >&2
fi

exit 0
