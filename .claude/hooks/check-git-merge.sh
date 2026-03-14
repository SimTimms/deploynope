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

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(cd "$CWD" 2>/dev/null && jq -r '.version // "N/A"' package.json 2>/dev/null || echo "N/A")

# Extract source branch being merged (first non-flag argument after "merge")
MERGE_SOURCE=$(echo "$COMMAND" | awk '{for(i=1;i<=NF;i++) if($i!="git" && $i!="merge" && substr($i,1,1)!="-") {print $i; exit}}')

# Determine production branch
PROD_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.productionBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$PROD_BRANCH" ]; then
  if cd "$CWD" 2>/dev/null && git rev-parse --verify origin/main &>/dev/null; then
    PROD_BRANCH="main"
  else
    PROD_BRANCH="master"
  fi
fi

# Determine staging and development branches from config
STAGING_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.stagingBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$STAGING_BRANCH" ]; then
  STAGING_BRANCH="staging"
fi
DEV_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.developmentBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$DEV_BRANCH" ]; then
  DEV_BRANCH="development"
fi

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
