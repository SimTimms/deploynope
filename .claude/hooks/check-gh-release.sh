#!/bin/bash
# DeployNOPE hook: intercept GitHub Release creation for user approval
# Shows version, tag, and repo details before allowing.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept gh release create commands (match anywhere in command to handle cd/&& prefixes)
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*gh\s+release\s+create'; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(cd "$CWD" 2>/dev/null && jq -r '.version // "N/A"' package.json 2>/dev/null || echo "N/A")

# Extract the tag from the command (word after "create")
TAG=$(echo "$COMMAND" | sed -n 's/.*create[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p')
if [ -z "$TAG" ]; then
  TAG="unknown"
fi

# Extract repo if --repo flag is present
REPO=$(echo "$COMMAND" | sed -n 's/.*--repo[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p')
if [ -z "$REPO" ]; then
  REPO="(current repo)"
fi

# Get the remote URL for context
REMOTE=$(cd "$CWD" 2>/dev/null && git remote get-url origin 2>/dev/null || echo "unknown")

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] GitHub Release creation intercepted.\n\nTag: ${TAG}\nRepo: ${REPO}\nBranch: ${BRANCH}\nVersion (package.json): ${VERSION}\nRemote: ${REMOTE}\nCommand: ${COMMAND}\n\nRemember: releases must be created on BOTH repos with matching versions.\n\nApprove this release?"
  }
}
EOF

exit 0
