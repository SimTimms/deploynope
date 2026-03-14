#!/bin/bash
# DeployNOPE hook: intercept PR creation for user approval
# Blocks PRs targeting production directly. Asks for all others.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept gh pr create commands
if ! echo "$COMMAND" | grep -qE '^\s*gh\s+pr\s+create'; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(cd "$CWD" 2>/dev/null && jq -r '.version // "N/A"' package.json 2>/dev/null || echo "N/A")

# Determine production branch
PROD_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.productionBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$PROD_BRANCH" ]; then
  if cd "$CWD" 2>/dev/null && git rev-parse --verify origin/main &>/dev/null; then
    PROD_BRANCH="main"
  else
    PROD_BRANCH="master"
  fi
fi

# Extract target branch from --base flag if present
TARGET_BRANCH=$(echo "$COMMAND" | grep -oP '(?<=--base\s)\S+' || echo "")
if [ -z "$TARGET_BRANCH" ]; then
  # gh pr create defaults to the repo's default branch
  TARGET_BRANCH="$PROD_BRANCH (default)"
fi

# Extract title if present
PR_TITLE=$(echo "$COMMAND" | grep -oP '(?<=--title\s")[^"]*' || echo "$COMMAND" | grep -oP "(?<=--title\s')[^']*" || echo "(not specified)")

# Block PRs targeting production
if echo "$TARGET_BRANCH" | grep -qE "^(${PROD_BRANCH}|master|main)"; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[DeployNOPE] BLOCKED — PR targets production branch '${PROD_BRANCH}'.\n\nDeployNOPE does not allow PRs directly to the production branch. All changes reach production via the staging → production reset process.\n\nIf this PR should target a release branch or development, re-create it with --base <branch>."
  }
}
EOF
  exit 0
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] PR creation intercepted.\n\nSource: ${BRANCH}\nTarget: ${TARGET_BRANCH}\nTitle: ${PR_TITLE}\nVersion: ${VERSION}\nCommand: ${COMMAND}\n\nApprove this PR creation?"
  }
}
EOF

exit 0
