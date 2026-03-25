#!/bin/bash
# DeployNOPE hook: update dashboard with stage from assistant responses
# Fires on Stop event — parses the DeployNOPE tag from last_assistant_message
# Tag format: <emoji> DeployNOPE <context> · <Stage>

INPUT=$(cat)

# Extract last_assistant_message
MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)
if [ -z "$MESSAGE" ]; then
  exit 0
fi

# Look for DeployNOPE tag pattern: emoji + DeployNOPE + context + · + Stage
# Matches: 🤓 DeployNOPE 2.17.0 · Feature
#          ⚠️ DeployNOPE 2.17.0 · Staging Validation
#          🚨 DeployNOPE 2.17.0 · Rollback
DEPLOYNOPE_TAG=$(echo "$MESSAGE" | grep -oE '(🤓|⚠️|🚨) DeployNOPE [^·]+· [A-Za-z ]+' | head -1)

if [ -z "$DEPLOYNOPE_TAG" ]; then
  exit 0
fi

# Parse the tag
SEVERITY=$(echo "$DEPLOYNOPE_TAG" | grep -oE '^(🤓|⚠️|🚨)')
CONTEXT=$(echo "$DEPLOYNOPE_TAG" | sed 's/^[^ ]* DeployNOPE //' | sed 's/ · .*//' | sed 's/[[:space:]]*$//')
STAGE=$(echo "$DEPLOYNOPE_TAG" | sed 's/.*· //' | sed 's/[[:space:]]*$//')

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

# Update agent's deploynope stage info
jq \
  --arg id "$AGENT_ID" \
  --arg cwd "$CWD" \
  --arg branch "$BRANCH" \
  --arg repo "$REPO" \
  --arg now "$NOW" \
  --arg severity "$SEVERITY" \
  --arg context "$CONTEXT" \
  --arg stage "$STAGE" \
  '
  .agents[$id] = (.agents[$id] // {}) * {
    id: $id,
    cwd: $cwd,
    branch: $branch,
    repo: $repo,
    lastSeenAt: $now,
    startedAt: ((.agents[$id].startedAt) // $now),
    deploynope: {
      active: true,
      severity: $severity,
      context: $context,
      stage: $stage,
      completedAt: (
        if ($stage | ascii_downcase) == "complete"
        then $now
        else (.agents[$id].deploynope.completedAt // null)
        end
      ),
      modifiedAfterComplete: (
        if (.agents[$id].deploynope.completedAt // null) != null
           and ($stage | ascii_downcase) != "complete"
        then true
        else (.agents[$id].deploynope.modifiedAfterComplete // false)
        end
      ),
      gate: (
        if ($stage | ascii_downcase | test("validation|sign.?off|awaiting|gate"))
        then { waiting: true, label: ($stage + " — sign-off required"), since: $now }
        elif (.agents[$id].deploynope.gate.waiting // false)
        then null
        else (.agents[$id].deploynope.gate // null)
        end
      )
    }
  }
  ' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"

exit 0
