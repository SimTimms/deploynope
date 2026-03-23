#!/bin/bash
# DeployNOPE hook: intercept branch deletion for user approval
# Hard-blocks deletion of production, staging, and development branches.
# Catches git branch -d, -D, and git push origin --delete.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Source shared helpers
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/hook-helpers.sh"

CWD=$(resolve_effective_cwd "$INPUT" "$COMMAND")

# Determine protected branch names
PROD_BRANCH=$(resolve_prod_branch "$CWD")
STAGING_BRANCH=$(resolve_staging_branch "$CWD")
DEV_BRANCH=$(resolve_dev_branch "$CWD")

# Helper: check if a branch name is protected
is_protected_branch() {
  local BNAME="$1"
  case "$BNAME" in
    "$PROD_BRANCH"|main|master|"$STAGING_BRANCH"|staging|"$DEV_BRANCH"|development|develop|dev)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# Catch git branch -d/-D (match anywhere in command to handle cd/&& prefixes)
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+branch\s+-[dD]'; then
  BRANCH_TO_DELETE=$(echo "$COMMAND" | awk '{for(i=1;i<=NF;i++) if($i~/-[dD]/) {print $(i+1); exit}}')
  if [ -z "$BRANCH_TO_DELETE" ]; then
    BRANCH_TO_DELETE="unknown"
  fi

  if is_protected_branch "$BRANCH_TO_DELETE"; then
    REASON=$(printf '[DeployNOPE] BLOCKED — Cannot delete protected branch '\''%s'\''.\n\nProduction ('\''%s'\''), staging ('\''%s'\''), and development ('\''%s'\'') branches cannot be deleted through Claude Code. If you need to delete this branch, do so manually via git outside Claude Code.' "$BRANCH_TO_DELETE" "$PROD_BRANCH" "$STAGING_BRANCH" "$DEV_BRANCH")
    jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
  fi

  REASON=$(printf '[DeployNOPE] Branch deletion intercepted.\n\nBranch to delete: %s\n\nApprove this branch deletion?' "$BRANCH_TO_DELETE")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  dashboard_update "$CWD" "git-branch-delete" "$COMMAND" "ask" &
  exit 0
fi

# Catch git push origin --delete (match anywhere in command to handle cd/&& prefixes)
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+push\s+\S+\s+--delete'; then
  BRANCH_TO_DELETE=$(echo "$COMMAND" | awk '{for(i=1;i<=NF;i++) if($i=="--delete") {print $(i+1); exit}}')
  if [ -z "$BRANCH_TO_DELETE" ]; then
    BRANCH_TO_DELETE="unknown"
  fi

  if is_protected_branch "$BRANCH_TO_DELETE"; then
    REASON=$(printf '[DeployNOPE] BLOCKED — Cannot delete protected remote branch '\''%s'\''.\n\nProduction ('\''%s'\''), staging ('\''%s'\''), and development ('\''%s'\'') branches cannot be deleted through Claude Code. If you need to delete this branch, do so manually via git outside Claude Code.' "$BRANCH_TO_DELETE" "$PROD_BRANCH" "$STAGING_BRANCH" "$DEV_BRANCH")
    jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
  fi

  REASON=$(printf '[DeployNOPE] Remote branch deletion intercepted.\n\nBranch to delete (remote): %s\n\nThis deletes the branch on the remote. This affects the whole team.\n\nApprove this remote branch deletion?' "$BRANCH_TO_DELETE")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  dashboard_update "$CWD" "git-branch-delete" "$COMMAND" "ask" &
  exit 0
fi

# Catch git push origin :branch (colon syntax for remote delete) (match anywhere in command to handle cd/&& prefixes)
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|\||;)\s*git\s+push\s+\S+\s+:'; then
  BRANCH_TO_DELETE=$(echo "$COMMAND" | awk '{for(i=1;i<=NF;i++) if(substr($i,1,1)==":") {print substr($i,2); exit}}')
  if [ -z "$BRANCH_TO_DELETE" ]; then
    BRANCH_TO_DELETE="unknown"
  fi

  if is_protected_branch "$BRANCH_TO_DELETE"; then
    REASON=$(printf '[DeployNOPE] BLOCKED — Cannot delete protected remote ref '\''%s'\''.\n\nProduction ('\''%s'\''), staging ('\''%s'\''), and development ('\''%s'\'') branches cannot be deleted through Claude Code. If you need to delete this ref, do so manually via git outside Claude Code.' "$BRANCH_TO_DELETE" "$PROD_BRANCH" "$STAGING_BRANCH" "$DEV_BRANCH")
    jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
  fi

  REASON=$(printf '[DeployNOPE] Remote branch/tag deletion intercepted (colon syntax).\n\nRef to delete: %s\n\nThis deletes a ref on the remote. This affects the whole team.\n\nApprove this remote deletion?' "$BRANCH_TO_DELETE")
  jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  dashboard_update "$CWD" "git-branch-delete" "$COMMAND" "ask" &
  exit 0
fi

exit 0
