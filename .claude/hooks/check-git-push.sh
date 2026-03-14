#!/bin/bash
# DeployNOPE hook: intercept every git push for user approval
# Hard-blocks pushes to production when staging exists; asks for all others.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git push commands (match anywhere in command to handle cd/&& prefixes)
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+push'; then
  exit 0
fi

# Extract useful context
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(cd "$CWD" 2>/dev/null && jq -r '.version // "N/A"' package.json 2>/dev/null || echo "N/A")

# Determine production branch from .deploynope.json or default to main/master
PROD_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.productionBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$PROD_BRANCH" ]; then
  if cd "$CWD" 2>/dev/null && git rev-parse --verify origin/main &>/dev/null; then
    PROD_BRANCH="main"
  else
    PROD_BRANCH="master"
  fi
fi

# Check if staging branch exists
HAS_STAGING="false"
if cd "$CWD" 2>/dev/null && git rev-parse --verify origin/staging &>/dev/null; then
  HAS_STAGING="true"
fi

# Detect if pushing to production branch
PUSHING_TO_PROD="false"
if [ "$BRANCH" = "$PROD_BRANCH" ]; then
  PUSHING_TO_PROD="true"
fi
# Also catch explicit "git push origin main" style commands
if echo "$COMMAND" | grep -qE "git\s+push\s+\S+\s+${PROD_BRANCH}"; then
  PUSHING_TO_PROD="true"
fi

# Count commits to push
COMMITS=$(cd "$CWD" 2>/dev/null && git log "origin/${BRANCH}..HEAD" --oneline 2>/dev/null || echo "")
COMMIT_COUNT=$(echo "$COMMITS" | grep -c '.' 2>/dev/null || echo "0")
if [ -z "$COMMITS" ]; then
  COMMIT_COUNT="0"
fi

# Production push with staging exists
if [ "$PUSHING_TO_PROD" = "true" ] && [ "$HAS_STAGING" = "true" ]; then

  # ALLOW with confirmation: --force-with-lease is the controlled staging → production reset
  if echo "$COMMAND" | grep -q '\-\-force-with-lease'; then
    # Verify staging and local production are aligned (this IS the reset step)
    STAGING_SHA=$(cd "$CWD" 2>/dev/null && git rev-parse origin/staging 2>/dev/null || echo "unknown")
    LOCAL_SHA=$(cd "$CWD" 2>/dev/null && git rev-parse HEAD 2>/dev/null || echo "unknown")

    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] PRODUCTION RESET — force-with-lease push to '${PROD_BRANCH}' detected.\n\nThis appears to be the staging → production reset step.\n\nLocal HEAD: ${LOCAL_SHA}\norigin/staging: ${STAGING_SHA}\nVersion: ${VERSION}\n\nThis will update production to match staging. Approve this production reset?"
  }
}
EOF
    exit 0
  fi

  # HARD BLOCK: regular push to production when staging exists
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[DeployNOPE] BLOCKED — Direct push to production branch '${PROD_BRANCH}' is not allowed. A staging branch exists. All changes must go through the staging → production reset process. Use /deploynope-deploy to follow the correct procedure."
  }
}
EOF
  exit 0
fi

# WARNING: pushing to production without staging
if [ "$PUSHING_TO_PROD" = "true" ] && [ "$HAS_STAGING" = "false" ]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] Push to production branch '${PROD_BRANCH}' — NO STAGING BRANCH detected.\n\nBranch: ${BRANCH} → origin/${BRANCH}\nVersion: ${VERSION}\nCommits: ${COMMIT_COUNT}\n${COMMITS}\n\nNo staging validation is possible. Consider running /deploynope-configure to set up staging infrastructure.\n\nApprove this direct push to production?"
  }
}
EOF
  exit 0
fi

# All other pushes: ask for approval with details
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] Git push intercepted.\n\nBranch: ${BRANCH} → origin/${BRANCH}\nVersion: ${VERSION}\nCommits: ${COMMIT_COUNT}\n${COMMITS}\n\nReview and approve this push."
  }
}
EOF

exit 0
