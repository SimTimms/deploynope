#!/bin/bash
# DeployNOPE Dashboard — Scan repos and worktrees to populate the dashboard
# Usage: ./dashboard/scan.sh [repo_path ...]
#
# If no paths given, scans the current directory.
# Automatically discovers worktrees within each repo.
#
# Examples:
#   ./dashboard/scan.sh ~/GitHub/my-app-fe ~/GitHub/my-app-api
#   ./dashboard/scan.sh                     # scans current directory

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_DIR="$(cd "$SCRIPT_DIR/../.claude/hooks" 2>/dev/null && pwd)"

# Try to find hook-helpers relative to this script, fall back to ~/.claude/hooks
if [ -z "$HOOK_DIR" ] || [ ! -f "$HOOK_DIR/hook-helpers.sh" ]; then
  HOOK_DIR="$HOME/.claude/hooks"
fi

if [ ! -f "$HOOK_DIR/hook-helpers.sh" ]; then
  echo "Error: hook-helpers.sh not found. Is DeployNOPE installed?"
  exit 1
fi

. "$HOOK_DIR/hook-helpers.sh"

STATE_DIR="$HOME/.deploynope"
STATE_FILE="$STATE_DIR/dashboard-state.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$STATE_DIR"

if [ ! -f "$STATE_FILE" ]; then
  echo '{"version":1,"agents":{},"stagingClaim":null,"warnings":[],"activity":[]}' > "$STATE_FILE"
fi

# Default to current directory if no args
PATHS=("$@")
if [ ${#PATHS[@]} -eq 0 ]; then
  PATHS=("$(pwd)")
fi

SCANNED=0

scan_repo() {
  local REPO_PATH="$1"
  local LABEL="$2"

  # Must be a git repo
  if ! (cd "$REPO_PATH" 2>/dev/null && git rev-parse --git-dir &>/dev/null); then
    return
  fi

  local BRANCH
  BRANCH=$(cd "$REPO_PATH" && git branch --show-current 2>/dev/null || echo "unknown")
  local REPO
  REPO=$(resolve_repo_name "$REPO_PATH")
  local VERSION
  VERSION=$(resolve_version "$REPO_PATH")
  local LAST_COMMIT
  LAST_COMMIT=$(cd "$REPO_PATH" && git log -1 --format='%s' 2>/dev/null || echo "")
  local LAST_COMMIT_TIME
  LAST_COMMIT_TIME=$(cd "$REPO_PATH" && git log -1 --format='%aI' 2>/dev/null || echo "$NOW")

  # Use repo path as a stable ID for scanned entries (prefix with "scan-")
  local AGENT_ID="scan-$(echo "$REPO_PATH" | sed 's/[^a-zA-Z0-9]/-/g')"

  # Check for .deploynope.json config
  local PROD_BRANCH=""
  local STAGING_BRANCH=""
  local DEV_BRANCH=""
  if [ -f "$REPO_PATH/.deploynope.json" ]; then
    PROD_BRANCH=$(resolve_prod_branch "$REPO_PATH")
    STAGING_BRANCH=$(resolve_staging_branch "$REPO_PATH")
    DEV_BRANCH=$(resolve_dev_branch "$REPO_PATH")
  fi

  # Determine target from branch context
  local TARGET=""
  if [ "$BRANCH" = "${STAGING_BRANCH:-staging}" ]; then
    TARGET="$BRANCH"
  elif [ "$BRANCH" = "${PROD_BRANCH:-main}" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    TARGET="$BRANCH"
  fi

  jq \
    --arg id "$AGENT_ID" \
    --arg cwd "$REPO_PATH" \
    --arg branch "$BRANCH" \
    --arg target "$TARGET" \
    --arg version "$VERSION" \
    --arg repo "$REPO" \
    --arg now "$NOW" \
    --arg lastCommit "$LAST_COMMIT" \
    --arg lastCommitTime "$LAST_COMMIT_TIME" \
    --arg prodBranch "$PROD_BRANCH" \
    --arg stagingBranch "$STAGING_BRANCH" \
    --arg devBranch "$DEV_BRANCH" \
    --arg label "$LABEL" \
    '
    .agents[$id] = {
      id: $id,
      cwd: $cwd,
      branch: $branch,
      target: (if $target == "" then null else $target end),
      version: $version,
      repo: $repo,
      lastSeenAt: $now,
      startedAt: $now,
      scanned: true,
      config: (if $prodBranch == "" then null else {
        prodBranch: $prodBranch,
        stagingBranch: $stagingBranch,
        devBranch: $devBranch
      } end),
      lastAction: {
        type: "scan",
        command: $lastCommit,
        decision: "info",
        timestamp: $lastCommitTime
      }
    }
    ' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"

  SCANNED=$((SCANNED + 1))
  echo "  ✓ $REPO ($BRANCH) — $REPO_PATH"
}

echo "DeployNOPE Dashboard — Scanning repos..."
echo ""

for REPO_PATH in "${PATHS[@]}"; do
  # Resolve to absolute path
  REPO_PATH=$(cd "$REPO_PATH" 2>/dev/null && pwd)
  if [ -z "$REPO_PATH" ]; then
    continue
  fi

  # Scan the repo itself
  scan_repo "$REPO_PATH" ""

  # Discover and scan worktrees
  if (cd "$REPO_PATH" && git rev-parse --git-dir &>/dev/null); then
    WORKTREE_LIST=$(cd "$REPO_PATH" && git worktree list --porcelain 2>/dev/null | grep '^worktree ' | sed 's/^worktree //')
    while IFS= read -r WT_PATH; do
      if [ -n "$WT_PATH" ] && [ "$WT_PATH" != "$REPO_PATH" ]; then
        scan_repo "$WT_PATH" "worktree"
      fi
    done <<< "$WORKTREE_LIST"
  fi
done

echo ""
echo "Scanned $SCANNED repos/worktrees. Dashboard updated."
