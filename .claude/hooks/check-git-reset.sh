#!/bin/bash
# DeployNOPE hook: intercept git reset --hard for user approval
# Shows what will be overwritten and flags staging/production resets.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git reset --hard commands (match anywhere in command to handle cd/&& prefixes)
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+reset\s+--hard'; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(cd "$CWD" 2>/dev/null && jq -r '.version // "N/A"' package.json 2>/dev/null || echo "N/A")

# Extract the reset target
RESET_TARGET=$(echo "$COMMAND" | sed -n 's/.*--hard[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p')
if [ -z "$RESET_TARGET" ]; then
  RESET_TARGET="unknown"
fi

# Get current HEAD for context
CURRENT_HEAD=$(cd "$CWD" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Determine production branch
PROD_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.productionBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$PROD_BRANCH" ]; then
  if cd "$CWD" 2>/dev/null && git rev-parse --verify origin/main &>/dev/null; then
    PROD_BRANCH="main"
  else
    PROD_BRANCH="master"
  fi
fi

# Determine staging branch from config
STAGING_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.stagingBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$STAGING_BRANCH" ]; then
  STAGING_BRANCH="staging"
fi

# Flag if resetting a critical branch
SEVERITY="WARNING"
EXTRA=""
if [ "$BRANCH" = "$PROD_BRANCH" ]; then
  SEVERITY="PRODUCTION BRANCH"
  EXTRA=$(printf '\n\nThis resets the PRODUCTION branch. Ensure branch protection toggle procedure is being followed.')
elif [ "$BRANCH" = "$STAGING_BRANCH" ]; then
  SEVERITY="STAGING BRANCH"
  EXTRA=$(printf '\n\nThis resets STAGING. Ensure staging contention check has passed and staging/active tag is claimed.')
fi

REASON=$(printf '[DeployNOPE] %s — git reset --hard intercepted.\n\nBranch: %s\nCurrent HEAD: %s\nReset target: %s\nVersion: %s\nCommand: %s%s\n\nThis is destructive and cannot be undone. Approve this reset?' "$SEVERITY" "$BRANCH" "$CURRENT_HEAD" "$RESET_TARGET" "$VERSION" "$COMMAND" "$EXTRA")
jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'

exit 0
