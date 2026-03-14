#!/bin/bash
# DeployNOPE hook: intercept PR creation for user approval
# Blocks PRs targeting production directly.
# Blocks PRs targeting staging or development (wrong process).
# Allows PRs targeting release branches (version pattern) with confirmation.

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

# Determine staging and development branch names
STAGING_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.stagingBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$STAGING_BRANCH" ]; then
  STAGING_BRANCH="staging"
fi
DEV_BRANCH=$(cd "$CWD" 2>/dev/null && jq -r '.developmentBranch // empty' .deploynope.json 2>/dev/null)
if [ -z "$DEV_BRANCH" ]; then
  DEV_BRANCH="development"
fi

# Extract target branch from --base flag if present (macOS compatible)
TARGET_BRANCH=$(echo "$COMMAND" | sed -n 's/.*--base[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p')
if [ -z "$TARGET_BRANCH" ]; then
  # gh pr create defaults to the repo's default branch (usually production)
  TARGET_BRANCH="$PROD_BRANCH"
fi

# Extract title if present (macOS compatible)
PR_TITLE=$(echo "$COMMAND" | sed -n 's/.*--title[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "$PR_TITLE" ]; then
  PR_TITLE="(not specified)"
fi

# BLOCK: PRs targeting production
if [ "$TARGET_BRANCH" = "$PROD_BRANCH" ] || [ "$TARGET_BRANCH" = "master" ] || [ "$TARGET_BRANCH" = "main" ]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[DeployNOPE] BLOCKED — PR targets production branch '${PROD_BRANCH}'.\n\nDeployNOPE does not allow PRs to the production branch. All changes reach production via the staging → production reset process.\n\nThe correct flow is:\n1. Feature branch → release branch (via PR)\n2. Release branch → staging reset → validate → production reset\n\nCreate a release branch first if one doesn't exist, then target the PR there."
  }
}
EOF
  exit 0
fi

# BLOCK: PRs targeting staging
if [ "$TARGET_BRANCH" = "$STAGING_BRANCH" ]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[DeployNOPE] BLOCKED — PR targets staging branch '${STAGING_BRANCH}'.\n\nStaging is not updated via PRs. It is updated via 'git reset --hard' from a release branch during the deployment process.\n\nThe correct flow is:\n1. Feature branch → release branch (via PR)\n2. Release branch → staging reset → validate → production reset\n\nTarget this PR at a release branch instead."
  }
}
EOF
  exit 0
fi

# BLOCK: PRs targeting development
if [ "$TARGET_BRANCH" = "$DEV_BRANCH" ] || [ "$TARGET_BRANCH" = "develop" ] || [ "$TARGET_BRANCH" = "dev" ]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[DeployNOPE] BLOCKED — PR targets development branch '${DEV_BRANCH}'.\n\nFeature branches should target a release branch, not development. The development branch is updated by merging the release branch into it AFTER production deployment.\n\nThe correct flow is:\n1. Feature branch → release branch (via PR)\n2. Release branch → staging reset → validate → production reset\n3. Release branch merged into development (post-deploy)\n\nCreate a release branch first if one doesn't exist, then target the PR there."
  }
}
EOF
  exit 0
fi

# ALLOW with confirmation: PRs targeting anything else (release branches, etc.)
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
