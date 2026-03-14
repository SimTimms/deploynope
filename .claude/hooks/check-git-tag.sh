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

# Determine production branch name for messages
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
PROD_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.productionBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$PROD_BRANCH" ]; then
  if cd "$CWD" 2>/dev/null && git rev-parse --verify origin/main &>/dev/null; then
    PROD_BRANCH="main"
  else
    PROD_BRANCH="master"
  fi
fi

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

exit 0
