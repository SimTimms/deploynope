#!/bin/bash
# DeployNOPE hook: intercept git reset --hard for user approval
# Shows what will be overwritten and flags staging/master resets.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git reset --hard commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+reset\s+--hard'; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(cd "$CWD" 2>/dev/null && jq -r '.version // "N/A"' package.json 2>/dev/null || echo "N/A")

# Extract the reset target
RESET_TARGET=$(echo "$COMMAND" | grep -oP '(?<=--hard\s)\S+' || echo "unknown")

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

# Flag if resetting a critical branch
SEVERITY="⚠️"
EXTRA=""
if [ "$BRANCH" = "$PROD_BRANCH" ]; then
  SEVERITY="🚨 PRODUCTION BRANCH"
  EXTRA="\n\nThis resets the PRODUCTION branch. Ensure branch protection toggle procedure is being followed."
elif [ "$BRANCH" = "staging" ]; then
  SEVERITY="🚨 STAGING BRANCH"
  EXTRA="\n\nThis resets STAGING. Ensure staging contention check has passed and staging/active tag is claimed."
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] ${SEVERITY} — git reset --hard intercepted.\n\nBranch: ${BRANCH}\nCurrent HEAD: ${CURRENT_HEAD}\nReset target: ${RESET_TARGET}\nVersion: ${VERSION}\nCommand: ${COMMAND}${EXTRA}\n\nThis is destructive and cannot be undone. Approve this reset?"
  }
}
EOF

exit 0
