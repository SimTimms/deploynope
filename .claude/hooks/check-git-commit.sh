#!/bin/bash
# DeployNOPE hook: intercept every git commit for user approval
# Warns when committing directly to protected branches.
# Fires on PreToolUse for Bash commands containing "git commit"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git commit commands (match anywhere in command to handle cd/&& prefixes)
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+commit'; then
  exit 0
fi

# Extract useful context
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(cd "$CWD" 2>/dev/null && jq -r '.version // "N/A"' package.json 2>/dev/null || echo "N/A")

# Determine protected branch names
PROD_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.productionBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$PROD_BRANCH" ]; then
  if cd "$CWD" 2>/dev/null && git rev-parse --verify origin/main &>/dev/null; then
    PROD_BRANCH="main"
  else
    PROD_BRANCH="master"
  fi
fi
STAGING_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.stagingBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$STAGING_BRANCH" ]; then
  STAGING_BRANCH="staging"
fi
DEV_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.developmentBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$DEV_BRANCH" ]; then
  DEV_BRANCH="development"
fi

# Warn if committing to a protected branch
PROTECTED_WARNING=""
if [ "$BRANCH" = "$PROD_BRANCH" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  PROTECTED_WARNING="\n\nWARNING: You are committing directly to the PRODUCTION branch '${BRANCH}'. Direct commits to production should only be release manifests or post-deploy records. If this is feature work, you should be on a feature or release branch instead."
elif [ "$BRANCH" = "$STAGING_BRANCH" ] || [ "$BRANCH" = "staging" ]; then
  PROTECTED_WARNING="\n\nWARNING: You are committing directly to the STAGING branch '${BRANCH}'. Staging is updated via resets, not direct commits. If this is intentional, proceed with caution."
elif [ "$BRANCH" = "$DEV_BRANCH" ] || [ "$BRANCH" = "development" ] || [ "$BRANCH" = "develop" ] || [ "$BRANCH" = "dev" ]; then
  PROTECTED_WARNING="\n\nWARNING: You are committing directly to the DEVELOPMENT branch '${BRANCH}'. Development is updated by merging release branches after deployment. If this is intentional, proceed with caution."
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] Git commit intercepted.\n\nBranch: ${BRANCH}\nVersion: ${VERSION}\nCommand: ${COMMAND}${PROTECTED_WARNING}\n\nReview and approve this commit."
  }
}
EOF

exit 0
