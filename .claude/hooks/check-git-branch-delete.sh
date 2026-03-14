#!/bin/bash
# DeployNOPE hook: intercept branch deletion for user approval
# Catches git branch -d, -D, and git push origin --delete.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Catch git branch -d/-D (match anywhere in command to handle cd/&& prefixes)
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+branch\s+-[dD]'; then
  BRANCH_TO_DELETE=$(echo "$COMMAND" | awk '{for(i=1;i<=NF;i++) if($i~/-[dD]/) {print $(i+1); exit}}')
  if [ -z "$BRANCH_TO_DELETE" ]; then
    BRANCH_TO_DELETE="unknown"
  fi

  REASON=$(printf '[DeployNOPE] Branch deletion intercepted.\n\nBranch to delete: %s\n\nApprove this branch deletion?' "$BRANCH_TO_DELETE")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
fi

# Catch git push origin --delete (match anywhere in command to handle cd/&& prefixes)
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+push\s+\S+\s+--delete'; then
  BRANCH_TO_DELETE=$(echo "$COMMAND" | awk '{for(i=1;i<=NF;i++) if($i=="--delete") {print $(i+1); exit}}')
  if [ -z "$BRANCH_TO_DELETE" ]; then
    BRANCH_TO_DELETE="unknown"
  fi

  REASON=$(printf '[DeployNOPE] Remote branch deletion intercepted.\n\nBranch to delete (remote): %s\n\nThis deletes the branch on the remote. This affects the whole team.\n\nApprove this remote branch deletion?' "$BRANCH_TO_DELETE")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
fi

# Catch git push origin :branch (colon syntax for remote delete) (match anywhere in command to handle cd/&& prefixes)
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+push\s+\S+\s+:'; then
  BRANCH_TO_DELETE=$(echo "$COMMAND" | awk '{for(i=1;i<=NF;i++) if(substr($i,1,1)==":") {print substr($i,2); exit}}')
  if [ -z "$BRANCH_TO_DELETE" ]; then
    BRANCH_TO_DELETE="unknown"
  fi

  REASON=$(printf '[DeployNOPE] Remote branch/tag deletion intercepted (colon syntax).\n\nRef to delete: %s\n\nThis deletes a ref on the remote. This affects the whole team.\n\nApprove this remote deletion?' "$BRANCH_TO_DELETE")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
fi

exit 0
