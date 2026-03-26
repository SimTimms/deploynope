#!/bin/bash
# DeployNOPE hook (PostToolUse): capture PR URL from gh pr create output
# and write it to the dashboard state as a pending gate.

INPUT=$(cat)

# Only process Bash tool results
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# Check if the output contains a GitHub PR URL
OUTPUT=$(echo "$INPUT" | jq -r '.tool_result // empty' 2>/dev/null)
PR_URL=$(echo "$OUTPUT" | grep -oE 'https://github\.com/[^/]+/[^/]+/pull/[0-9]+' | head -1)

if [ -z "$PR_URL" ]; then
  exit 0
fi

# Extract PR number
PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')

# Source shared helpers
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/hook-helpers.sh"

CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
if [ -z "$CWD" ]; then
  exit 0
fi

STATE_DIR="$HOME/.deploynope"
STATE_FILE="$STATE_DIR/dashboard-state.json"
AGENT_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
if [ -z "$AGENT_ID" ]; then
  AGENT_ID="${CLAUDE_CODE_SSE_PORT:-$$}"
fi
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$STATE_DIR"

if [ ! -f "$STATE_FILE" ]; then
  echo '{"version":1,"agents":{},"stagingClaim":null,"warnings":[],"activity":[]}' > "$STATE_FILE"
fi

BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
REPO=$(resolve_repo_name "$CWD")

# Update agent with PR gate info (under exclusive lock)
state_locked_update \
  --arg id "$AGENT_ID" \
  --arg cwd "$CWD" \
  --arg branch "$BRANCH" \
  --arg repo "$REPO" \
  --arg now "$NOW" \
  --arg prUrl "$PR_URL" \
  --arg prNumber "$PR_NUMBER" \
  '
  .agents[$id] = (.agents[$id] // {}) * {
    id: $id,
    cwd: $cwd,
    branch: $branch,
    repo: $repo,
    lastSeenAt: $now,
    startedAt: ((.agents[$id].startedAt) // $now),
    pr: {
      url: $prUrl,
      number: ($prNumber | tonumber),
      createdAt: $now,
      merged: false
    }
  }
  ' "$STATE_FILE"

exit 0
