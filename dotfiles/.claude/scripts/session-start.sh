#!/bin/bash
# session-start.sh -- SessionStart hook
# 前回セッションの状態を表示する

PERSIST_FILE="${HOME}/.claude/sessions/last-session.json"

if [ -f "$PERSIST_FILE" ]; then
  TIMESTAMP=$(python3 -c "import json; print(json.load(open('$PERSIST_FILE'))['timestamp'])" 2>/dev/null)
  BRANCH=$(python3 -c "import json; print(json.load(open('$PERSIST_FILE'))['branch'])" 2>/dev/null)
  LAST_COMMIT=$(python3 -c "import json; print(json.load(open('$PERSIST_FILE'))['last_commit'])" 2>/dev/null)
  TOOL_CALLS=$(python3 -c "import json; print(json.load(open('$PERSIST_FILE'))['tool_calls'])" 2>/dev/null)

  echo "Previous session: ${TIMESTAMP}" >&2
  echo "   Branch: ${BRANCH}" >&2
  echo "   Last commit: ${LAST_COMMIT}" >&2
  echo "   Tool calls: ${TOOL_CALLS}" >&2
fi

# ツールコールカウンターを初期化
mkdir -p "${HOME}/.claude/cache"
echo "0" > "${HOME}/.claude/cache/.tool-call-count"

exit 0
