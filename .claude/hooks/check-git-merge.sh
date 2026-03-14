#!/bin/bash
# DeployNOPE hook: intercept git merge for user approval
# Shows source and target branches, flags merges into critical branches.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git merge commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+merge'; then
  exit 0
fi

# Skip --abort (that's a safety action, not a merge)
if echo "$COMMAND" | grep -q '\-\-abort'; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(cd "$CWD" 2>/dev/null && jq -r '.version // "N/A"' package.json 2>/dev/null || echo "N/A")

# Extract source branch being merged
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

EXTRA=""
if [ "$BRANCH" = "$PROD_BRANCH" ]; then
  EXTRA="\n\n🚨 You are merging INTO the production branch. DeployNOPE requires all changes reach production via staging reset, not direct merge."
elif [ "$BRANCH" = "staging" ]; then
  EXTRA="\n\n⚠️ You are merging into staging. Ensure staging contention check has passed and staging/active tag is claimed."
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] Git merge intercepted.\n\nMerging: ${MERGE_SOURCE} → ${BRANCH}\nVersion: ${VERSION}\nCommand: ${COMMAND}${EXTRA}\n\nApprove this merge?"
  }
}
EOF

exit 0
