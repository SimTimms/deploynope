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
