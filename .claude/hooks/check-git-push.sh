#!/bin/bash
# DeployNOPE hook: intercept every git push for user approval
# Hard-blocks pushes to production when staging exists.
# Escalates force-push warnings for staging and release branches.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git push commands (match anywhere in command to handle cd/&& prefixes)
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+push'; then
  exit 0
fi

# Source shared helpers
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/hook-helpers.sh"

# Extract useful context
CWD=$(resolve_effective_cwd "$INPUT" "$COMMAND")
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(resolve_version "$CWD")

# Determine production branch from .deploynope.json or default to main/master
PROD_BRANCH=$(resolve_prod_branch "$CWD")

# Determine staging branch
STAGING_BRANCH=$(resolve_staging_branch "$CWD")

# Check if staging branch exists
HAS_STAGING="false"
if cd "$CWD" 2>/dev/null && git rev-parse --verify "origin/${STAGING_BRANCH}" &>/dev/null; then
  HAS_STAGING="true"
fi

# Extract explicit push target from command: git push [flags...] <remote> [<branch>]
# Skip flags (words starting with -) to find the remote (1st non-flag) and branch (2nd non-flag)
# This takes priority over the current branch for determining what's being pushed
EXPLICIT_PUSH_TARGET=""
_PUSH_ARGS=$(echo "$COMMAND" | sed -n 's/.*git[[:space:]]\{1,\}push[[:space:]]\{1,\}//p')
if [ -n "$_PUSH_ARGS" ]; then
  # Extract non-flag arguments (skip words starting with -)
  _NON_FLAG_ARGS=$(echo "$_PUSH_ARGS" | tr ' ' '\n' | grep -v '^-' | head -2)
  # Second non-flag argument is the branch/refspec (first is the remote)
  _RAW_TARGET=$(echo "$_NON_FLAG_ARGS" | sed -n '2p')
  # Handle refspec format (e.g. HEAD:main, feature:main) — extract the destination after ':'
  if echo "$_RAW_TARGET" | grep -q ':'; then
    EXPLICIT_PUSH_TARGET=$(echo "$_RAW_TARGET" | cut -d':' -f2)
  else
    EXPLICIT_PUSH_TARGET="$_RAW_TARGET"
  fi
fi

# Use explicit target if available, otherwise fall back to current branch
PUSH_BRANCH="${EXPLICIT_PUSH_TARGET:-$BRANCH}"

# Detect if pushing to production branch
PUSHING_TO_PROD="false"
if [ "$PUSH_BRANCH" = "$PROD_BRANCH" ]; then
  PUSHING_TO_PROD="true"
fi
# Also catch explicit "git push origin main" style commands (safety net)
if echo "$COMMAND" | grep -qE "git\s+push\s+\S+\s+${PROD_BRANCH}"; then
  PUSHING_TO_PROD="true"
fi

# Count commits to push
COMMITS=$(cd "$CWD" 2>/dev/null && git log "origin/${PUSH_BRANCH}..HEAD" --oneline 2>/dev/null || echo "")
COMMIT_COUNT=$(echo "$COMMITS" | grep -c '.' 2>/dev/null || echo "0")
if [ -z "$COMMITS" ]; then
  COMMIT_COUNT="0"
fi

# Detect force-push flags
IS_FORCE_PUSH="false"
if echo "$COMMAND" | grep -qE '\s--force($|\s)|\s-f($|\s)'; then
  IS_FORCE_PUSH="true"
fi
if echo "$COMMAND" | grep -q '\-\-force-with-lease'; then
  IS_FORCE_PUSH="true"
fi

# Production push with staging exists
if [ "$PUSHING_TO_PROD" = "true" ] && [ "$HAS_STAGING" = "true" ]; then

  # ALLOW with confirmation: --force-with-lease is the controlled staging -> production reset
  if echo "$COMMAND" | grep -q '\-\-force-with-lease'; then
    STAGING_SHA=$(cd "$CWD" 2>/dev/null && git rev-parse "origin/${STAGING_BRANCH}" 2>/dev/null || echo "unknown")
    LOCAL_SHA=$(cd "$CWD" 2>/dev/null && git rev-parse HEAD 2>/dev/null || echo "unknown")

    REASON=$(printf '[DeployNOPE] PRODUCTION RESET — force-with-lease push to '\''%s'\'' detected.\n\nThis appears to be the staging → production reset step.\n\nLocal HEAD: %s\norigin/%s: %s\nVersion: %s\n\nThis will update production to match staging. Approve this production reset?' "$PROD_BRANCH" "$LOCAL_SHA" "$STAGING_BRANCH" "$STAGING_SHA" "$VERSION")
    jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
    exit 0
  fi

  # HARD BLOCK: regular push to production when staging exists
  REASON=$(printf '[DeployNOPE] BLOCKED — Direct push to production branch '\''%s'\'' is not allowed. A staging branch exists. All changes must go through the staging → production reset process. Use /deploynope-deploy to follow the correct procedure.' "$PROD_BRANCH")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
fi

# WARNING: pushing to production without staging
if [ "$PUSHING_TO_PROD" = "true" ] && [ "$HAS_STAGING" = "false" ]; then
  REASON=$(printf '[DeployNOPE] Push to production branch '\''%s'\'' — NO STAGING BRANCH detected.\n\nBranch: %s → origin/%s\nVersion: %s\nCommits: %s\n%s\n\nNo staging validation is possible. Consider running /deploynope-configure to set up staging infrastructure.\n\nApprove this direct push to production?' "$PROD_BRANCH" "$PUSH_BRANCH" "$PUSH_BRANCH" "$VERSION" "$COMMIT_COUNT" "$COMMITS")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
fi

# Escalated warning for force-pushes to staging or other branches
if [ "$IS_FORCE_PUSH" = "true" ]; then
  FORCE_TARGET="$PUSH_BRANCH"

  if [ "$FORCE_TARGET" = "$STAGING_BRANCH" ]; then
    REASON=$(printf '[DeployNOPE] FORCE-PUSH TO STAGING — This could overwrite another deployment in progress.\n\nBranch: %s\nVersion: %s\n\nForce-pushing to staging can destroy work from a concurrent deployment. Verify that no one else is using staging right now.\n\nApprove this force-push to staging?' "$FORCE_TARGET" "$VERSION")
    jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
    exit 0
  fi

  # Force-push to any other branch — escalated warning
  REASON=$(printf '[DeployNOPE] FORCE-PUSH detected.\n\nTarget: %s\nVersion: %s\n\nForce-pushing rewrites history. If others have based work on this branch, their work will be affected.\n\nApprove this force-push?' "$FORCE_TARGET" "$VERSION")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
fi

# All other pushes: ask for approval with details
REASON=$(printf '[DeployNOPE] Git push intercepted.\n\nBranch: %s → origin/%s\nVersion: %s\nCommits: %s\n%s\n\nReview and approve this push.' "$PUSH_BRANCH" "$PUSH_BRANCH" "$VERSION" "$COMMIT_COUNT" "$COMMITS")
jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'

exit 0
