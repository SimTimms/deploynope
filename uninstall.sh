#!/bin/bash
# DeployNOPE Uninstaller
# Removes commands, hooks, and hook configuration from the user level.

set -euo pipefail

DEPLOYNOPE_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_HOOKS_DIR="$CLAUDE_DIR/hooks"
CLAUDE_COMMANDS_DIR="$CLAUDE_DIR/commands"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { printf "${GREEN}[+]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$1"; }

# --- Remove command symlinks (only those pointing into this repo) ---
REMOVED=0
if [ -d "$CLAUDE_COMMANDS_DIR" ]; then
  for f in "$CLAUDE_COMMANDS_DIR"/deploynope-*.md; do
    [ -L "$f" ] || continue
    TARGET="$(readlink "$f")"
    if echo "$TARGET" | grep -q "$DEPLOYNOPE_DIR"; then
      rm "$f"
      REMOVED=$((REMOVED + 1))
    fi
  done
fi
info "Removed $REMOVED command symlinks."

# --- Remove hooks symlink (only if it points to this repo) ---
if [ -L "$CLAUDE_HOOKS_DIR" ]; then
  TARGET="$(readlink "$CLAUDE_HOOKS_DIR")"
  if [ "$TARGET" = "$DEPLOYNOPE_DIR/.claude/hooks" ]; then
    rm "$CLAUDE_HOOKS_DIR"
    info "Removed hooks symlink."
  else
    warn "~/.claude/hooks points to $TARGET (not this repo). Skipping."
  fi
elif [ -e "$CLAUDE_HOOKS_DIR" ]; then
  warn "~/.claude/hooks is not a symlink. Skipping."
else
  info "No hooks symlink found."
fi

# --- Remove hooks config from settings.json ---
if [ -f "$CLAUDE_SETTINGS" ] && command -v jq &>/dev/null; then
  DEPLOYNOPE_HOOK_REGEX='(^|/)\.claude/hooks/check-(git-commit|git-push|git-reset|gh-pr-create|gh-release|gh-api-protection|git-branch-delete|git-tag|git-merge)\.sh$'

  if jq -e --arg deploynopeHookRegex "$DEPLOYNOPE_HOOK_REGEX" \
    '
    [
      (.hooks.PreToolUse // [])[]? 
      | (.hooks // [])[]?
      | select((.type == "command") and ((.command // "") | test($deploynopeHookRegex)))
    ] | length > 0
    ' "$CLAUDE_SETTINGS" >/dev/null; then
    jq --arg deploynopeHookRegex "$DEPLOYNOPE_HOOK_REGEX" '
      def isDeploynopeCommandHook:
        (.type == "command")
        and ((.command // "") | test($deploynopeHookRegex));

      .hooks.PreToolUse = (
        (.hooks.PreToolUse // [])
        | map(
            if ((.hooks // null) | type) == "array" then
              .hooks |= map(select((isDeploynopeCommandHook) | not))
            else
              .
            end
          )
        | map(
            if ((.hooks // null) | type) == "array" then
              select((.hooks | length) > 0)
            else
              .
            end
          )
      )
      | if ((.hooks.PreToolUse // []) | length) == 0 then
          del(.hooks.PreToolUse)
        else
          .
        end
      | if (.hooks == {}) then
          del(.hooks)
        else
          .
        end
    ' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp"
    mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
    info "Removed DeployNOPE hook entries from $CLAUDE_SETTINGS (preserved unrelated hooks)."
  else
    info "No DeployNOPE hooks found in settings.json."
  fi
else
  info "No settings file to clean up."
fi

echo ""
info "DeployNOPE uninstalled."
echo "  Commands and hooks have been removed from user-level configuration."
echo "  The DeployNOPE repo itself has not been modified."
echo ""
