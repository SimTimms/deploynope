#!/bin/bash
# DeployNOPE hook: intercept git reset --hard for user approval
# Hard-blocks resets on production unless branch protection is verified unlocked.
# Shows what will be overwritten and flags staging/production resets.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git reset --hard commands (match anywhere in command to handle cd/&& prefixes)
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+reset\s+--hard'; then
  exit 0
fi

# Source shared helpers
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/hook-helpers.sh"

CWD=$(resolve_effective_cwd "$INPUT" "$COMMAND")
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(resolve_version "$CWD")

# Extract the reset target
RESET_TARGET=$(echo "$COMMAND" | sed -n 's/.*--hard[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p')
if [ -z "$RESET_TARGET" ]; then
  RESET_TARGET="unknown"
fi

# Get current HEAD for context
CURRENT_HEAD=$(cd "$CWD" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Determine production branch
PROD_BRANCH=$(resolve_prod_branch "$CWD")

# Determine staging branch from config
STAGING_BRANCH=$(resolve_staging_branch "$CWD")

# HARD BLOCK: reset --hard on production branch requires verified protection unlock
if [ "$BRANCH" = "$PROD_BRANCH" ]; then
  STATE_FILE="$CWD/.deploynope-protection-unlocked"
  if [ -f "$STATE_FILE" ]; then
    # Protection was toggled off via the proper procedure — allow with confirmation
    UNLOCKED_AT=$(head -1 "$STATE_FILE" 2>/dev/null)
    REASON=$(printf '[DeployNOPE] PRODUCTION RESET — branch protection verified unlocked.\n\nBranch: %s\nCurrent HEAD: %s\nReset target: %s\nVersion: %s\nProtection unlocked at: %s\n\nThis resets the PRODUCTION branch. Force-push protection has been verified as unlocked. Approve this reset?' "$BRANCH" "$CURRENT_HEAD" "$RESET_TARGET" "$VERSION" "$UNLOCKED_AT")
    jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
    exit 0
  else
    # No state file — hard block
    REASON=$(printf '[DeployNOPE] BLOCKED — git reset --hard on production branch '\''%s'\'' requires branch protection to be unlocked first.\n\nNo protection unlock state file found (.deploynope-protection-unlocked). This means either:\n1. Force-push has not been enabled on '\''%s'\'' yet, or\n2. The protection toggle was done outside the DeployNOPE workflow.\n\nUse /deploynope-deploy to follow the correct procedure. The branch protection API call (enabling force-push) must happen first — the hook will create the state file automatically.' "$PROD_BRANCH" "$PROD_BRANCH")
    jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
  fi
fi

# Flag if resetting staging
SEVERITY="WARNING"
EXTRA=""
if [ "$BRANCH" = "$STAGING_BRANCH" ]; then
  SEVERITY="STAGING BRANCH"
  EXTRA=$(printf '\n\nThis resets STAGING. Ensure staging contention check has passed and staging/active tag is claimed.')
fi

REASON=$(printf '[DeployNOPE] %s — git reset --hard intercepted.\n\nBranch: %s\nCurrent HEAD: %s\nReset target: %s\nVersion: %s\nCommand: %s%s\n\nThis is destructive and cannot be undone. Approve this reset?' "$SEVERITY" "$BRANCH" "$CURRENT_HEAD" "$RESET_TARGET" "$VERSION" "$COMMAND" "$EXTRA")
jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'

exit 0
