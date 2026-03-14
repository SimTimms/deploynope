#!/bin/bash
# DeployNOPE hook: intercept every git commit for user approval
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

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] Git commit intercepted.\n\nBranch: ${BRANCH}\nVersion: ${VERSION}\nCommand: ${COMMAND}\n\nReview and approve this commit."
  }
}
EOF

exit 0
