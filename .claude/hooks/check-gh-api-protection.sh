#!/bin/bash
# DeployNOPE hook: intercept gh api calls that modify branch protection
# Flags any attempt to change branch protection settings.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept gh api calls that touch branch protection
if ! echo "$COMMAND" | grep -qE '^\s*gh\s+api'; then
  exit 0
fi

if ! echo "$COMMAND" | grep -q 'protection'; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Detect if this is enabling or disabling force-push
FORCE_PUSH_STATE="unknown"
if echo "$COMMAND" | grep -q '"allow_force_pushes":\s*true'; then
  FORCE_PUSH_STATE="ENABLING force-push"
elif echo "$COMMAND" | grep -q '"allow_force_pushes":\s*false'; then
  FORCE_PUSH_STATE="DISABLING force-push (re-locking)"
fi

# Extract the repo/branch from the URL
API_PATH=$(echo "$COMMAND" | grep -oP '(?<=gh api\s)\S+' || echo "unknown")

# Detect if this is a PUT (modification) vs GET (read-only)
IS_WRITE="false"
if echo "$COMMAND" | grep -qE '\-X\s+PUT'; then
  IS_WRITE="true"
fi

if [ "$IS_WRITE" = "false" ]; then
  # Read-only API calls to check protection status are fine
  exit 0
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] 🔐 BRANCH PROTECTION MODIFICATION intercepted.\n\nAPI path: ${API_PATH}\nAction: ${FORCE_PUSH_STATE}\nCommand: ${COMMAND}\n\n⚠️ Branch protection changes are security-critical. If enabling force-push, it MUST be re-disabled immediately after the reset — even if the reset fails.\n\nApprove this branch protection change?"
  }
}
EOF

exit 0
