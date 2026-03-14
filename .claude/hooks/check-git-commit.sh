#!/bin/bash
# DeployNOPE hook: intercept every git commit for user approval
# Warns when committing directly to protected branches.
# Fires on PreToolUse for Bash commands containing "git commit"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git commit commands (match anywhere in command to handle cd/&& prefixes)
# Exclude false positives: echo/printf wrapping "git commit" in their arguments
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+commit'; then
  exit 0
fi
if echo "$COMMAND" | grep -qE '(^|\s)(echo|printf)\s'; then
  # If the command starts with echo/printf, only intercept if there's a real
  # git commit after a command separator (&&, ||, ;)
  if ! echo "$COMMAND" | grep -qE '(&&|\|\||;)\s*git\s+commit'; then
    exit 0
  fi
fi

# Source shared helpers
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/hook-helpers.sh"

# Extract useful context
CWD=$(resolve_effective_cwd "$INPUT" "$COMMAND")
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(resolve_version "$CWD")

# Determine protected branch names
PROD_BRANCH=$(resolve_prod_branch "$CWD")
STAGING_BRANCH=$(resolve_staging_branch "$CWD")
DEV_BRANCH=$(resolve_dev_branch "$CWD")

# Warn if committing to a protected branch
PROTECTED_WARNING=""
if [ "$BRANCH" = "$PROD_BRANCH" ]; then
  PROTECTED_WARNING=$(printf '\n\nWARNING: You are committing directly to the PRODUCTION branch '\''%s'\''. Direct commits to production should only be release manifests or post-deploy records. If this is feature work, you should be on a feature or release branch instead.' "$BRANCH")
elif [ "$BRANCH" = "$STAGING_BRANCH" ]; then
  PROTECTED_WARNING=$(printf '\n\nWARNING: You are committing directly to the STAGING branch '\''%s'\''. Staging is updated via resets, not direct commits. If this is intentional, proceed with caution.' "$BRANCH")
elif [ "$BRANCH" = "$DEV_BRANCH" ]; then
  PROTECTED_WARNING=$(printf '\n\nWARNING: You are committing directly to the DEVELOPMENT branch '\''%s'\''. Development is updated by merging release branches after deployment. If this is intentional, proceed with caution.' "$BRANCH")
fi

REASON=$(printf '[DeployNOPE] Git commit intercepted.\n\nBranch: %s\nVersion: %s\nCommand: %s%s\n\nReview and approve this commit.' "$BRANCH" "$VERSION" "$COMMAND" "$PROTECTED_WARNING")
jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'

exit 0
