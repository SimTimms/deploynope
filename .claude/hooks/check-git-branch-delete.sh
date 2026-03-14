#!/bin/bash
# DeployNOPE hook: intercept branch deletion for user approval
# Catches git branch -d, -D, and git push origin --delete.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Catch git branch -d/-D
if echo "$COMMAND" | grep -qE '^\s*git\s+branch\s+-[dD]'; then
  BRANCH_TO_DELETE=$(echo "$COMMAND" | grep -oP '(?<=-[dD]\s)\S+' || echo "unknown")

  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] Branch deletion intercepted.\n\nBranch to delete: ${BRANCH_TO_DELETE}\nCommand: ${COMMAND}\n\nApprove this branch deletion?"
  }
}
EOF
  exit 0
fi

# Catch git push origin --delete
if echo "$COMMAND" | grep -qE '^\s*git\s+push\s+\S+\s+--delete'; then
  BRANCH_TO_DELETE=$(echo "$COMMAND" | grep -oP '(?<=--delete\s)\S+' || echo "unknown")

  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] Remote branch deletion intercepted.\n\nBranch to delete (remote): ${BRANCH_TO_DELETE}\nCommand: ${COMMAND}\n\n⚠️ This deletes the branch on the remote. This affects the whole team.\n\nApprove this remote branch deletion?"
  }
}
EOF
  exit 0
fi

# Catch git push origin :branch (colon syntax for remote delete)
if echo "$COMMAND" | grep -qE '^\s*git\s+push\s+\S+\s+:'; then
  BRANCH_TO_DELETE=$(echo "$COMMAND" | grep -oP '(?<=\s):\S+' | sed 's/^://' || echo "unknown")

  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "[DeployNOPE] Remote branch/tag deletion intercepted (colon syntax).\n\nRef to delete: ${BRANCH_TO_DELETE}\nCommand: ${COMMAND}\n\n⚠️ This deletes a ref on the remote. This affects the whole team.\n\nApprove this remote deletion?"
  }
}
EOF
  exit 0
fi

exit 0
