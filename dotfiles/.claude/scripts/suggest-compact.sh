#!/bin/bash
# suggest-compact.sh -- PreToolUse hook
# ツールコール回数を追跡し、閾値超過時にコンパクト提案する

COUNTER_FILE="${HOME}/.claude/cache/.tool-call-count"
THRESHOLD=${COMPACT_THRESHOLD:-80}
REMINDER_INTERVAL=30

# カウンターファイルの初期化（存在しない場合）
mkdir -p "$(dirname "$COUNTER_FILE")"
if [ ! -f "$COUNTER_FILE" ]; then
    echo "0" >"$COUNTER_FILE"
fi

# カウントをインクリメント
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
COUNT=$((COUNT + 1))
echo "$COUNT" >"$COUNTER_FILE"

# 閾値チェック
if [ "$COUNT" -eq "$THRESHOLD" ]; then
    echo "Tool call count reached ${THRESHOLD}. Consider running /compact at a logical task boundary to free up context." >&2
elif [ "$COUNT" -gt "$THRESHOLD" ]; then
    SINCE=$((COUNT - THRESHOLD))
    if [ $((SINCE % REMINDER_INTERVAL)) -eq 0 ]; then
        echo "${COUNT} tool calls in session. Consider /compact if switching tasks." >&2
    fi
fi

exit 0
