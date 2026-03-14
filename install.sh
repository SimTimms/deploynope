#!/bin/bash
# DeployNOPE Global Installer
# Installs commands and hooks at the user level so they fire in every Claude Code session.

set -euo pipefail

# --- Paths ---
DEPLOYNOPE_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_HOOKS_DIR="$CLAUDE_DIR/hooks"
CLAUDE_COMMANDS_DIR="$CLAUDE_DIR/commands"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

info()  { printf "${GREEN}[+]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$1"; }
error() { printf "${RED}[x]${NC} %s\n" "$1"; }

# --- Step 1: Check dependencies ---
if ! command -v jq &>/dev/null; then
  error "jq is required but not installed."
  echo "  Install it with: brew install jq (macOS) or apt-get install jq (Linux)"
  exit 1
fi

# --- Step 2: Create ~/.claude/ if needed ---
mkdir -p "$CLAUDE_DIR"

# --- Step 3: Symlink commands ---
mkdir -p "$CLAUDE_COMMANDS_DIR"
COMMAND_COUNT=0
for f in "$DEPLOYNOPE_DIR/.claude/commands"/*.md; do
  [ -f "$f" ] || continue
  ln -sf "$f" "$CLAUDE_COMMANDS_DIR/$(basename "$f")"
  COMMAND_COUNT=$((COMMAND_COUNT + 1))
done
info "Symlinked $COMMAND_COUNT commands to $CLAUDE_COMMANDS_DIR/"

# --- Step 4: Symlink hooks directory ---
if [ -e "$CLAUDE_HOOKS_DIR" ]; then
  if [ -L "$CLAUDE_HOOKS_DIR" ]; then
    EXISTING_TARGET="$(readlink "$CLAUDE_HOOKS_DIR")"
    if [ "$EXISTING_TARGET" = "$DEPLOYNOPE_DIR/.claude/hooks" ]; then
      info "Hooks symlink already in place."
    else
      warn "~/.claude/hooks is a symlink pointing to: $EXISTING_TARGET"
      warn "Expected: $DEPLOYNOPE_DIR/.claude/hooks"
      echo "  Remove it manually and re-run this installer if you want to replace it."
      exit 1
    fi
  else
    error "~/.claude/hooks/ is a real directory (not a symlink)."
    echo "  DeployNOPE cannot replace it automatically — it may contain your own hooks."
    echo "  To proceed, move or remove it first, then re-run this installer."
    exit 1
  fi
else
  ln -sf "$DEPLOYNOPE_DIR/.claude/hooks" "$CLAUDE_HOOKS_DIR"
  info "Symlinked hooks directory: $CLAUDE_HOOKS_DIR -> $DEPLOYNOPE_DIR/.claude/hooks"
fi

# --- Step 5: Merge hook config into ~/.claude/settings.json ---

# Build the hooks JSON with absolute paths
HOOKS_JSON=$(cat <<ENDJSON
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {"type": "command", "command": "$HOME/.claude/hooks/check-git-commit.sh", "timeout": 10},
        {"type": "command", "command": "$HOME/.claude/hooks/check-git-push.sh", "timeout": 15},
        {"type": "command", "command": "$HOME/.claude/hooks/check-git-reset.sh", "timeout": 15},
        {"type": "command", "command": "$HOME/.claude/hooks/check-gh-pr-create.sh", "timeout": 10},
        {"type": "command", "command": "$HOME/.claude/hooks/check-gh-release.sh", "timeout": 10},
        {"type": "command", "command": "$HOME/.claude/hooks/check-gh-api-protection.sh", "timeout": 10},
        {"type": "command", "command": "$HOME/.claude/hooks/check-git-branch-delete.sh", "timeout": 10},
        {"type": "command", "command": "$HOME/.claude/hooks/check-git-tag.sh", "timeout": 10},
        {"type": "command", "command": "$HOME/.claude/hooks/check-git-merge.sh", "timeout": 10}
      ]
    }
  ]
}
ENDJSON
)

if [ ! -f "$CLAUDE_SETTINGS" ]; then
  # No settings file — create one with just hooks
  jq -n --argjson hooks "$HOOKS_JSON" '{hooks: $hooks}' > "$CLAUDE_SETTINGS"
  info "Created $CLAUDE_SETTINGS with hook configuration."
else
  # Back up existing settings before modifying
  cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup"
  info "Backed up existing settings to $CLAUDE_SETTINGS.backup"

  # Settings file exists — merge hooks in
  EXISTING=$(cat "$CLAUDE_SETTINGS")

  if echo "$EXISTING" | jq -e '.hooks' &>/dev/null; then
    # Hooks key already exists — check if DeployNOPE hooks are present
    if echo "$EXISTING" | grep -q 'check-git-commit.sh'; then
      # DeployNOPE hooks already present — replace them (idempotent update)
      echo "$EXISTING" | jq --argjson hooks "$HOOKS_JSON" '.hooks = $hooks' > "$CLAUDE_SETTINGS.tmp"
      mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
      info "Updated existing DeployNOPE hooks in $CLAUDE_SETTINGS."
    else
      # Other hooks exist — append DeployNOPE's PreToolUse matcher
      warn "Existing hooks found in settings.json that are not from DeployNOPE."
      echo "  Appending DeployNOPE hooks alongside existing hooks."
      DEPLOYNOPE_MATCHER=$(echo "$HOOKS_JSON" | jq '.PreToolUse[0]')
      echo "$EXISTING" | jq --argjson matcher "$DEPLOYNOPE_MATCHER" \
        '.hooks.PreToolUse = (.hooks.PreToolUse // []) + [$matcher]' > "$CLAUDE_SETTINGS.tmp"
      mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
      info "Appended DeployNOPE hooks to $CLAUDE_SETTINGS."
    fi
  else
    # No hooks key — add it
    echo "$EXISTING" | jq --argjson hooks "$HOOKS_JSON" '. + {hooks: $hooks}' > "$CLAUDE_SETTINGS.tmp"
    mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
    info "Added hook configuration to $CLAUDE_SETTINGS."
  fi
fi

# --- Step 6: Verify ---
ERRORS=0

if [ ! -L "$CLAUDE_HOOKS_DIR" ] && [ ! -d "$CLAUDE_HOOKS_DIR" ]; then
  error "Hooks directory not found at $CLAUDE_HOOKS_DIR"
  ERRORS=$((ERRORS + 1))
fi

if ! jq . "$CLAUDE_SETTINGS" &>/dev/null; then
  error "Settings file is not valid JSON: $CLAUDE_SETTINGS"
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
  error "Installation completed with $ERRORS error(s). Please check the output above."
  exit 1
fi

# --- Done ---
echo ""
info "DeployNOPE installed globally."
echo ""
echo "  Commands:  $CLAUDE_COMMANDS_DIR/ ($COMMAND_COUNT symlinks)"
echo "  Hooks:     $CLAUDE_HOOKS_DIR -> $DEPLOYNOPE_DIR/.claude/hooks/"
echo "  Settings:  $CLAUDE_SETTINGS (hooks merged)"
if [ -f "$CLAUDE_SETTINGS.backup" ]; then
echo "  Backup:    $CLAUDE_SETTINGS.backup"
fi
echo ""
echo "  Hooks will fire in every Claude Code session."
echo "  Run /deploynope-configure in each project to set up project-specific settings."
echo ""
