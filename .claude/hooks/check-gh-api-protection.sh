#!/bin/bash
# DeployNOPE hook: intercept gh api calls that modify branch protection
# Flags any attempt to change branch protection settings.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept gh api calls that touch branch protection (match anywhere in command to handle cd/&& prefixes)
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*gh\s+api'; then
  exit 0
fi

if ! echo "$COMMAND" | grep -q 'protection'; then
  exit 0
fi

# Detect if this is a PUT (modification) vs GET (read-only)
if ! echo "$COMMAND" | grep -qE '\-X\s+PUT'; then
  # Read-only API calls to check protection status are fine
  exit 0
fi

# Detect if this is enabling or disabling force-push
FORCE_PUSH_STATE="unknown"
if echo "$COMMAND" | grep -q 'allow_force_pushes.*true'; then
  FORCE_PUSH_STATE="ENABLING force-push"
elif echo "$COMMAND" | grep -q 'allow_force_pushes.*false'; then
  FORCE_PUSH_STATE="DISABLING force-push (re-locking)"
fi

# Extract the API path
API_PATH=$(echo "$COMMAND" | awk '{for(i=1;i<=NF;i++) if($i=="api") {print $(i+1); exit}}')

REASON=$(printf '[DeployNOPE] BRANCH PROTECTION MODIFICATION intercepted.\n\nAPI path: %s\nAction: %s\n\nBranch protection changes are security-critical. If enabling force-push, it MUST be re-disabled immediately after the reset — even if the reset fails.\n\nApprove this branch protection change?' "$API_PATH" "$FORCE_PUSH_STATE")
jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'

exit 0
