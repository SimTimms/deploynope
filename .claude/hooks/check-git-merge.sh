#!/bin/bash
# DeployNOPE hook: intercept git merge for user approval
# Shows source and target branches, flags merges into critical branches.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git merge commands (match anywhere in command to handle cd/&& prefixes)
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+merge'; then
  exit 0
fi

# Skip --abort (that's a safety action, not a merge)
if echo "$COMMAND" | grep -q '\-\-abort'; then
  exit 0
fi

# Source shared helpers
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/hook-helpers.sh"

CWD=$(resolve_effective_cwd "$INPUT" "$COMMAND")
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(resolve_version "$CWD")

# Extract source branch being merged (first non-flag argument after "merge")
MERGE_SOURCE=$(echo "$COMMAND" | awk '{for(i=1;i<=NF;i++) if($i!="git" && $i!="merge" && substr($i,1,1)!="-") {print $i; exit}}')

# Determine production branch
PROD_BRANCH=$(resolve_prod_branch "$CWD")

# Determine staging and development branches from config
STAGING_BRANCH=$(resolve_staging_branch "$CWD")
DEV_BRANCH=$(resolve_dev_branch "$CWD")

EXTRA=""
DECISION="ask"
if [ "$BRANCH" = "$PROD_BRANCH" ]; then
  EXTRA=$(printf '\n\nYou are merging INTO the production branch. DeployNOPE requires all changes reach production via staging reset, not direct merge.')
elif [ "$BRANCH" = "$STAGING_BRANCH" ]; then
  EXTRA=$(printf '\n\nYou are merging into staging. Ensure staging contention check has passed and staging/active tag is claimed.')
elif [ "$BRANCH" = "$DEV_BRANCH" ] || [ "$BRANCH" = "develop" ] || [ "$BRANCH" = "dev" ]; then
  # Only the production branch should be merged into development (post-deployment step)
  # Use config-driven PROD_BRANCH — no hardcoded master/main assumptions
  if [ "$MERGE_SOURCE" != "$PROD_BRANCH" ]; then
    DECISION="deny"
    EXTRA=$(printf '\n\nBLOCKED: Only the production branch ('\''%s'\'') should be merged into '\''%s'\''. Merging other branches into development causes drift and breaks branch alignment.\n\nThe correct flow is:\n1. Feature/release branch → staging reset → validate → production reset\n2. THEN merge '\''%s'\'' into '\''%s'\'' (post-deployment step)\n\nThe branch '\''%s'\'' must go through the full deployment process first.' "$PROD_BRANCH" "$DEV_BRANCH" "$PROD_BRANCH" "$DEV_BRANCH" "$MERGE_SOURCE")
  fi
fi

REASON=$(printf '[DeployNOPE] Git merge intercepted.\n\nMerging: %s → %s\nVersion: %s\nCommand: %s%s\n\nApprove this merge?' "$MERGE_SOURCE" "$BRANCH" "$VERSION" "$COMMAND" "$EXTRA")
jq -n --arg reason "$REASON" --arg decision "$DECISION" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$decision,permissionDecisionReason:$reason}}'

exit 0
