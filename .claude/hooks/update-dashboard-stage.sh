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

# Resolve agent ID: find an existing agent by branch name so the hook enriches
# the scan-created entry rather than creating a duplicate. This means the scan
# populates the agent, and the hook takes over with DeployNOPE data.
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
if [ -z "$SESSION_ID" ]; then
  SESSION_ID="${CLAUDE_CODE_SSE_PORT:-$$}"
fi

BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
REPO=$(resolve_repo_name "$CWD")

EXISTING_ID=""
if [ -f "$STATE_FILE" ]; then
  # 1. Match by branch AND cwd (strongest — same branch in same directory)
  #    Skip protected branches — DeployNOPE stages should never enrich a main/staging/dev agent
  if [ -n "$BRANCH" ] && [ "$BRANCH" != "unknown" ]; then
    EXISTING_ID=$(jq -r --arg cwd "$CWD" --arg branch "$BRANCH" '
      [.agents[] | select(
        .cwd == $cwd and .branch == $branch and
        ($branch | test("^(main|master|staging|development)$") | not)
      )] | .[0].id // empty
    ' "$STATE_FILE" 2>/dev/null)
  fi
  # 2. Match by context against branch name (covers worktrees where cwd differs
  #    and context may be the branch name e.g. "style-changes")
  if [ -z "$EXISTING_ID" ] && [ -n "$CONTEXT" ]; then
    EXISTING_ID=$(jq -r --arg ctx "$CONTEXT" '
      [.agents[] | select(.branch == $ctx)] | .[0].id // empty
    ' "$STATE_FILE" 2>/dev/null)
  fi
  # 3. Match by repo: find a non-protected, non-complete branch agent in the same repo.
  #    Covers context changes (e.g. "style-changes" → "2.21.0") and worktree cwd mismatches.
  #    Excludes completed deployments so we don't hijack a finished workflow.
  if [ -z "$EXISTING_ID" ] && [ -n "$REPO" ]; then
    EXISTING_ID=$(jq -r --arg repo "$REPO" '
      [.agents[] | select(
        .repo == $repo and
        (.branch // "" | test("^(main|master|staging|development)$") | not) and
        ((.deploynope.stage // "" | ascii_downcase) != "complete")
      )] |
      sort_by(if (.deploynope.active // false) then 0 else 1 end) |
      .[0].id // empty
    ' "$STATE_FILE" 2>/dev/null)
  fi
fi

if [ -n "$EXISTING_ID" ]; then
  AGENT_ID="$EXISTING_ID"
elif [ -n "$CONTEXT" ]; then
  AGENT_ID="$CONTEXT"
else
  AGENT_ID="$SESSION_ID"
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$STATE_DIR"

if [ ! -f "$STATE_FILE" ]; then
  echo '{"version":1,"agents":{},"stagingClaim":null,"warnings":[],"activity":[]}' > "$STATE_FILE"
fi

# ── Branch drift detection ──────────────────────────────────────────────────
# Check how many commits the current branch is behind the production branch
DRIFT_BEHIND=0
DRIFT_AHEAD=0
DRIFT_BASE="main"
if [ -d "$CWD/.git" ] || (cd "$CWD" 2>/dev/null && git rev-parse --git-dir &>/dev/null); then
  # Read production branch from .deploynope.json if available
  if [ -f "$CWD/.deploynope.json" ]; then
    DRIFT_BASE=$(jq -r '.productionBranch // "main"' "$CWD/.deploynope.json" 2>/dev/null)
  fi
  # Fetch silently to ensure we have latest refs
  (cd "$CWD" 2>/dev/null && git fetch -q origin 2>/dev/null) || true
  # Count commits on origin/production that are not on the current branch
  DRIFT_BEHIND=$(cd "$CWD" 2>/dev/null && git rev-list --count HEAD.."origin/$DRIFT_BASE" 2>/dev/null || echo "0")
  DRIFT_BEHIND=$(echo "$DRIFT_BEHIND" | grep -oE '^[0-9]+$' || echo "0")
  [ -z "$DRIFT_BEHIND" ] && DRIFT_BEHIND=0
  # Count commits ahead of production
  DRIFT_AHEAD=$(cd "$CWD" 2>/dev/null && git rev-list --count "origin/$DRIFT_BASE"..HEAD 2>/dev/null || echo "0")
  DRIFT_AHEAD=$(echo "$DRIFT_AHEAD" | grep -oE '^[0-9]+$' || echo "0")
  [ -z "$DRIFT_AHEAD" ] && DRIFT_AHEAD=0
fi

# Update agent's deploynope stage info (under exclusive lock)
state_locked_update \
  --arg id "$AGENT_ID" \
  --arg cwd "$CWD" \
  --arg branch "$BRANCH" \
  --arg repo "$REPO" \
  --arg now "$NOW" \
  --arg severity "$SEVERITY" \
  --arg context "$CONTEXT" \
  --arg stage "$STAGE" \
  --argjson driftBehind "$DRIFT_BEHIND" \
  --argjson driftAhead "$DRIFT_AHEAD" \
  --arg driftBase "$DRIFT_BASE" \
  '
  .agents[$id] = (.agents[$id] // {}) * {
    id: $id,
    cwd: ((.agents[$id].cwd) // $cwd),
    branch: ((.agents[$id].branch) // $branch),
    repo: ((.agents[$id].repo) // $repo),
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
      ),
      drift: {
        behindBy: $driftBehind,
        aheadBy: $driftAhead,
        baseBranch: $driftBase,
        lastChecked: $now
      }
    }
  }
  ' "$STATE_FILE"

exit 0
