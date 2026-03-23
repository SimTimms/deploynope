#!/bin/bash
# DeployNOPE hook: intercept PR creation for user approval
# Blocks PRs targeting production directly.
# Blocks PRs targeting staging or development (wrong process).
# Allows PRs targeting release branches (version pattern) with confirmation.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept gh pr create commands (match anywhere in command to handle cd/&& prefixes)
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*gh\s+pr\s+create'; then
  exit 0
fi

# Source shared helpers
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/hook-helpers.sh"

CWD=$(resolve_effective_cwd "$INPUT" "$COMMAND")
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(resolve_version "$CWD")

# Determine production branch
PROD_BRANCH=$(resolve_prod_branch "$CWD")

# Determine staging and development branch names
STAGING_BRANCH=$(resolve_staging_branch "$CWD")
DEV_BRANCH=$(resolve_dev_branch "$CWD")

# Extract target branch from --base flag if present (macOS compatible)
TARGET_BRANCH=$(echo "$COMMAND" | sed -n 's/.*--base[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p')
if [ -z "$TARGET_BRANCH" ]; then
  # gh pr create defaults to the repo's default branch (usually production)
  TARGET_BRANCH="$PROD_BRANCH"
fi

# Extract title if present — handle both quoted and unquoted (macOS compatible)
PR_TITLE=$(echo "$COMMAND" | sed -n 's/.*--title[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "$PR_TITLE" ]; then
  PR_TITLE=$(echo "$COMMAND" | sed -n 's/.*--title[[:space:]]\{1,\}\([^[:space:]-]*\).*/\1/p')
fi
if [ -z "$PR_TITLE" ]; then
  PR_TITLE="(not specified)"
fi

# BLOCK: PRs targeting production (config-driven + safety net for common names)
if [ "$TARGET_BRANCH" = "$PROD_BRANCH" ] || [ "$TARGET_BRANCH" = "master" ] || [ "$TARGET_BRANCH" = "main" ]; then
  REASON=$(printf '[DeployNOPE] BLOCKED — PR targets production branch '\''%s'\''.\n\nDeployNOPE does not allow PRs to the production branch. All changes reach production via the staging → production reset process.\n\nThe correct flow is:\n1. Feature branch → release branch (via PR)\n2. Release branch → staging reset → validate → production reset\n\nCreate a release branch first if one does not exist, then target the PR there.' "$PROD_BRANCH")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
fi

# BLOCK: PRs targeting staging
if [ "$TARGET_BRANCH" = "$STAGING_BRANCH" ]; then
  REASON=$(printf '[DeployNOPE] BLOCKED — PR targets staging branch '\''%s'\''.\n\nStaging is not updated via PRs. It is updated via '\''git reset --hard'\'' from a release branch during the deployment process.\n\nThe correct flow is:\n1. Feature branch → release branch (via PR)\n2. Release branch → staging reset → validate → production reset\n\nTarget this PR at a release branch instead.' "$STAGING_BRANCH")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
fi

# BLOCK: PRs targeting development
if [ "$TARGET_BRANCH" = "$DEV_BRANCH" ] || [ "$TARGET_BRANCH" = "develop" ] || [ "$TARGET_BRANCH" = "dev" ]; then
  REASON=$(printf '[DeployNOPE] BLOCKED — PR targets development branch '\''%s'\''.\n\nFeature branches should target a release branch, not development. The development branch is updated by merging the release branch into it AFTER production deployment.\n\nThe correct flow is:\n1. Feature branch → release branch (via PR)\n2. Release branch → staging reset → validate → production reset\n3. Release branch merged into development (post-deploy)\n\nCreate a release branch first if one does not exist, then target the PR there.' "$DEV_BRANCH")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
fi

# ALLOW with confirmation: PRs targeting anything else (release branches, etc.)
REASON=$(printf '[DeployNOPE] PR creation intercepted.\n\nSource: %s\nTarget: %s\nTitle: %s\nVersion: %s\n\nApprove this PR creation?' "$BRANCH" "$TARGET_BRANCH" "$PR_TITLE" "$VERSION")
jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'

dashboard_update "$CWD" "gh-pr" "$COMMAND" "ask"

exit 0
