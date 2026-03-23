#!/bin/bash
# Shared helpers for DeployNOPE hooks
# Source this file at the top of each hook after reading INPUT and COMMAND.

# resolve_effective_cwd
# When commands contain "cd /path && git ...", the effective working directory
# is the cd target, not the .cwd from the tool input. This matters in worktrees
# where .cwd points to the primary repo but the command operates in a worktree.
#
# Usage: CWD=$(resolve_effective_cwd "$INPUT" "$COMMAND")
resolve_effective_cwd() {
  local INPUT="$1"
  local COMMAND="$2"
  local CWD

  # First, check if the command starts with cd <path>
  local CD_TARGET
  CD_TARGET=$(echo "$COMMAND" | sed -n 's/^[[:space:]]*cd[[:space:]]\{1,\}\([^;&|]*\)[[:space:]]*[;&|].*/\1/p' | sed 's/[[:space:]]*$//')

  if [ -n "$CD_TARGET" ] && [ -d "$CD_TARGET" ] && (cd "$CD_TARGET" 2>/dev/null && git rev-parse --git-dir &>/dev/null); then
    CWD="$CD_TARGET"
  else
    # Fall back to .cwd from the tool input
    CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
  fi

  echo "$CWD"
}

# resolve_branch
# Gets the current branch for the effective working directory.
# Uses resolve_effective_cwd internally.
#
# Usage: BRANCH=$(resolve_branch "$INPUT" "$COMMAND")
resolve_branch() {
  local INPUT="$1"
  local COMMAND="$2"
  local CWD
  CWD=$(resolve_effective_cwd "$INPUT" "$COMMAND")

  cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown"
}

# resolve_config_value
# Reads a value from .deploynope.json in the effective CWD.
#
# Usage: VALUE=$(resolve_config_value "$CWD" "productionBranch")
resolve_config_value() {
  local CWD="$1"
  local KEY="$2"
  cd "$CWD" 2>/dev/null && jq -r ".$KEY // empty" .deploynope.json 2>/dev/null || echo ""
}

# resolve_prod_branch
# Determines the production branch name from config or remote detection.
#
# Usage: PROD_BRANCH=$(resolve_prod_branch "$CWD")
resolve_prod_branch() {
  local CWD="$1"
  local PROD_BRANCH
  PROD_BRANCH=$(resolve_config_value "$CWD" "productionBranch")
  if [ -z "$PROD_BRANCH" ]; then
    if cd "$CWD" 2>/dev/null && git rev-parse --verify origin/main &>/dev/null; then
      PROD_BRANCH="main"
    else
      PROD_BRANCH="master"
    fi
  fi
  echo "$PROD_BRANCH"
}

# resolve_staging_branch
# Determines the staging branch name from config or default.
#
# Usage: STAGING_BRANCH=$(resolve_staging_branch "$CWD")
resolve_staging_branch() {
  local CWD="$1"
  local STAGING_BRANCH
  STAGING_BRANCH=$(resolve_config_value "$CWD" "stagingBranch")
  if [ -z "$STAGING_BRANCH" ]; then
    STAGING_BRANCH="staging"
  fi
  echo "$STAGING_BRANCH"
}

# resolve_dev_branch
# Determines the development branch name from config or default.
#
# Usage: DEV_BRANCH=$(resolve_dev_branch "$CWD")
resolve_dev_branch() {
  local CWD="$1"
  local DEV_BRANCH
  DEV_BRANCH=$(resolve_config_value "$CWD" "developmentBranch")
  if [ -z "$DEV_BRANCH" ]; then
    DEV_BRANCH="development"
  fi
  echo "$DEV_BRANCH"
}

# resolve_version
# Reads the version from package.json in the effective CWD.
#
# Usage: VERSION=$(resolve_version "$CWD")
resolve_version() {
  local CWD="$1"
  cd "$CWD" 2>/dev/null && jq -r '.version // "N/A"' package.json 2>/dev/null || echo "N/A"
}

# resolve_repo_name
# Gets the repo name (owner/repo) from git remote origin.
#
# Usage: REPO=$(resolve_repo_name "$CWD")
resolve_repo_name() {
  local CWD="$1"
  cd "$CWD" 2>/dev/null && git remote get-url origin 2>/dev/null | sed 's/.*github\.com[:/]//' | sed 's/\.git$//' || echo "unknown"
}

# dashboard_update
# Writes agent state to ~/.deploynope/dashboard-state.json.
# Called by every hook to keep the dashboard current.
# Runs in the background (&) to avoid slowing down hooks.
#
# Usage: dashboard_update "$CWD" "git-push" "$COMMAND" "ask"
dashboard_update() {
  local CWD="$1"
  local ACTION_TYPE="$2"
  local COMMAND="$3"
  local DECISION="$4"

  local STATE_DIR="$HOME/.deploynope"
  local STATE_FILE="$STATE_DIR/dashboard-state.json"
  local AGENT_ID="${CLAUDE_CODE_SSE_PORT:-$$}"
  local NOW
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  mkdir -p "$STATE_DIR"

  # Initialize state file if missing
  if [ ! -f "$STATE_FILE" ]; then
    echo '{"version":1,"agents":{},"stagingClaim":null,"warnings":[],"activity":[]}' > "$STATE_FILE"
  fi

  local BRANCH
  BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
  local VERSION
  VERSION=$(resolve_version "$CWD")
  local REPO
  REPO=$(resolve_repo_name "$CWD")
  local PROD_BRANCH
  PROD_BRANCH=$(resolve_prod_branch "$CWD")
  local STAGING_BRANCH
  STAGING_BRANCH=$(resolve_staging_branch "$CWD")
  local DEV_BRANCH
  DEV_BRANCH=$(resolve_dev_branch "$CWD")

  # Determine target branch based on action context
  local TARGET=""
  case "$ACTION_TYPE" in
    git-push)
      # Extract push target from command
      local _PUSH_TARGET
      _PUSH_TARGET=$(echo "$COMMAND" | sed -n 's/.*git[[:space:]]\{1,\}push[[:space:]]\{1,\}//p' | tr ' ' '\n' | grep -v '^-' | sed -n '2p')
      if echo "$_PUSH_TARGET" | grep -q ':'; then
        TARGET=$(echo "$_PUSH_TARGET" | cut -d':' -f2)
      elif [ -n "$_PUSH_TARGET" ]; then
        TARGET="$_PUSH_TARGET"
      else
        TARGET="origin/$BRANCH"
      fi
      ;;
    git-reset)   TARGET="$BRANCH" ;;
    git-merge)   TARGET="$BRANCH" ;;
    gh-pr)       TARGET=$(echo "$COMMAND" | sed -n 's/.*--base[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p') ;;
    gh-release)  TARGET="$PROD_BRANCH" ;;
    *)           TARGET="" ;;
  esac

  # Build activity entry (keep last 50)
  local ACTIVITY_ENTRY
  ACTIVITY_ENTRY=$(jq -n \
    --arg agent "$AGENT_ID" \
    --arg action "$ACTION_TYPE" \
    --arg command "$COMMAND" \
    --arg branch "$BRANCH" \
    --arg repo "$REPO" \
    --arg decision "$DECISION" \
    --arg ts "$NOW" \
    '{agent:$agent,action:$action,command:$command,branch:$branch,repo:$repo,decision:$decision,timestamp:$ts}')

  # Atomic update: read, modify, write to tmp, then mv
  jq \
    --arg id "$AGENT_ID" \
    --arg cwd "$CWD" \
    --arg branch "$BRANCH" \
    --arg target "$TARGET" \
    --arg version "$VERSION" \
    --arg repo "$REPO" \
    --arg now "$NOW" \
    --arg actionType "$ACTION_TYPE" \
    --arg command "$COMMAND" \
    --arg decision "$DECISION" \
    --arg prodBranch "$PROD_BRANCH" \
    --arg stagingBranch "$STAGING_BRANCH" \
    --arg devBranch "$DEV_BRANCH" \
    --argjson activityEntry "$ACTIVITY_ENTRY" \
    '
    .agents[$id] = (.agents[$id] // {}) * {
      id: $id,
      cwd: $cwd,
      branch: $branch,
      target: $target,
      version: $version,
      repo: $repo,
      lastSeenAt: $now,
      startedAt: ((.agents[$id].startedAt) // $now),
      config: {
        prodBranch: $prodBranch,
        stagingBranch: $stagingBranch,
        devBranch: $devBranch
      },
      lastAction: {
        type: $actionType,
        command: $command,
        decision: $decision,
        timestamp: $now
      }
    } |
    .activity = ([$activityEntry] + (.activity // []))[:50]
    ' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"
}
