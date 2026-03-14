#!/bin/bash
# DeployNOPE hook: intercept every git commit for user approval
# Fires on PreToolUse for Bash commands containing "git commit"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept git commit commands (match anywhere in command to handle cd/&& prefixes)
# Exclude false positives: echo/printf wrapping "git commit" in their arguments
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+commit'; then
  exit 0
fi
if echo "$COMMAND" | grep -qE '(^|\s)(echo|printf)\s'; then
  # If the command starts with echo/printf, only intercept if there's a real
  # git commit after a command separator (&&, ||, ;)
  if ! echo "$COMMAND" | grep -qE '(&&|\|\||;)\s*git\s+commit'; then
    exit 0
  fi
fi

# Extract useful context
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
VERSION=$(cd "$CWD" 2>/dev/null && jq -r '.version // "N/A"' package.json 2>/dev/null || echo "N/A")

# Build JSON output safely (jq handles escaping of $COMMAND)
REASON=$(printf '[DeployNOPE] Git commit intercepted.\n\nBranch: %s\nVersion: %s\nCommand: %s\n\nReview and approve this commit.' "$BRANCH" "$VERSION" "$COMMAND")

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: $reason
  }
}'

exit 0
