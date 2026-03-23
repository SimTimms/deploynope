#!/bin/bash
# DeployNOPE hook: intercept gh api calls that modify branch protection
# Flags any attempt to change branch protection settings.
# Tracks protection unlock/relock state via .deploynope-protection-unlocked file.

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

# Source shared helpers
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/hook-helpers.sh"

CWD=$(resolve_effective_cwd "$INPUT" "$COMMAND")

# Detect if this is enabling or disabling force-push
FORCE_PUSH_STATE="unknown"
STATE_FILE="$CWD/.deploynope-protection-unlocked"

if echo "$COMMAND" | grep -q 'allow_force_pushes.*true'; then
  FORCE_PUSH_STATE="ENABLING force-push"
elif echo "$COMMAND" | grep -q 'allow_force_pushes.*false'; then
  FORCE_PUSH_STATE="DISABLING force-push (re-locking)"
  # Remove state file — protection is being re-locked
  rm -f "$STATE_FILE" 2>/dev/null
fi

# Extract the API path
API_PATH=$(echo "$COMMAND" | awk '{for(i=1;i<=NF;i++) if($i=="api") {print $(i+1); exit}}')

# Check if there's an existing stale unlock BEFORE writing the new state file
STALE_WARNING=""
if [ "$FORCE_PUSH_STATE" = "ENABLING force-push" ] && [ -f "$STATE_FILE" ]; then
  STALE_WARNING="\n\nWARNING: A previous protection unlock state file already exists. This may indicate a prior deployment that did not re-lock protection."
fi

# Write state file AFTER the stale check so we don't false-positive on ourselves
if [ "$FORCE_PUSH_STATE" = "ENABLING force-push" ]; then
  echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$STATE_FILE" 2>/dev/null
fi

REASON=$(printf '[DeployNOPE] BRANCH PROTECTION MODIFICATION intercepted.\n\nAPI path: %s\nAction: %s%s\n\nBranch protection changes are security-critical. If enabling force-push, it MUST be re-disabled immediately after the reset — even if the reset fails.\n\nApprove this branch protection change?' "$API_PATH" "$FORCE_PUSH_STATE" "$STALE_WARNING")
jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'

dashboard_update "$CWD" "gh-api-protection" "$COMMAND" "ask" &

exit 0
