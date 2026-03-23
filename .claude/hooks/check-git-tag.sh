#!/bin/bash
# DeployNOPE hook: intercept git tag operations for user approval
# Flags staging/active claim and clear operations especially.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git tag commands (create/delete) (match anywhere in command to handle cd/&& prefixes)
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+tag'; then
  exit 0
fi

# Skip read-only tag operations (list, show)
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+tag\s+-[ln]'; then
  exit 0
fi
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+tag\s*$'; then
  exit 0
fi

# Source shared helpers
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/hook-helpers.sh"

# Determine production branch name for messages
CWD=$(resolve_effective_cwd "$INPUT" "$COMMAND")
PROD_BRANCH=$(resolve_prod_branch "$CWD")

# Detect staging/active operations
EXTRA=""
if echo "$COMMAND" | grep -q 'staging/active'; then
  if echo "$COMMAND" | grep -q '\-d'; then
    EXTRA=$(printf '\n\nThis CLEARS the staging claim. Only do this after %s has been reset and deployment is confirmed healthy.' "$PROD_BRANCH")
  else
    EXTRA=$(printf '\n\nThis CLAIMS staging. Ensure staging contention checks have passed. Notify the team in Slack after this.')
  fi
fi

REASON=$(printf '[DeployNOPE] Git tag operation intercepted.\n\nCommand: %s%s\n\nApprove this tag operation?' "$COMMAND" "$EXTRA")
jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'

dashboard_update "$CWD" "git-tag" "$COMMAND" "ask" &

exit 0
