#!/bin/bash
# session-persist.sh -- Stop hook
# セッション終了時にコンテキストサマリーを保存する

SESSION_DIR="${HOME}/.claude/sessions"
PERSIST_FILE="${SESSION_DIR}/last-session.json"

mkdir -p "$SESSION_DIR"

# 現在のGit状態を記録
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
LAST_COMMIT=$(git log --oneline -1 2>/dev/null || echo "unknown")
WORKING_DIR=$(pwd)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# セッションサマリーを保存
cat >"$PERSIST_FILE" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "branch": "${BRANCH}",
  "last_commit": "${LAST_COMMIT}",
  "working_dir": "${WORKING_DIR}",
  "tool_calls": $(cat "${HOME}/.claude/cache/.tool-call-count" 2>/dev/null || echo "0")
}
EOF

# ツールコールカウンターをリセット
echo "0" >"${HOME}/.claude/cache/.tool-call-count"

exit 0
