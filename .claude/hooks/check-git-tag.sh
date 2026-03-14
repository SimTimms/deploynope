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

# Detect staging/active operations
EXTRA=""
if echo "$COMMAND" | grep -q 'staging/active'; then
  if echo "$COMMAND" | grep -q '\-d'; then
    EXTRA="\n\nThis CLEARS the staging claim. Only do this after master has been reset and deployment is confirmed healthy."
  else
    EXTRA="\n\nThis CLAIMS staging. Ensure staging contention checks have passed. Notify the team in Slack after this."
  fi
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] Git tag operation intercepted.\n\nCommand: ${COMMAND}${EXTRA}\n\nApprove this tag operation?"
  }
}
EOF

exit 0
