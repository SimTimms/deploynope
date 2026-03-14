#!/bin/bash
# DeployNOPE Test Helpers
# Shared functions for hook unit tests

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
HOOKS_DIR="$PROJECT_DIR/.claude/hooks"

# Counters
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
TEST_NAME=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Temp repo setup ──────────────────────────────────────────────────────────

setup_temp_repo() {
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR" || exit 1

  git init -q
  git checkout -q -b main

  # Create .deploynope.json
  cat > .deploynope.json <<'CONF'
{
  "owner": "TestOwner",
  "backendRepo": null,
  "frontendRepo": "test-repo",
  "productionBranch": "main",
  "stagingBranch": "staging",
  "developmentBranch": "development",
  "deploymentCutoffTime": "14:00",
  "frontend": { "npmInstallCommand": "npm install" },
  "backend": { "npmInstallCommand": null }
}
CONF

  # Create package.json
  cat > package.json <<'PKG'
{ "name": "test-repo", "version": "1.0.0" }
PKG

  git add -A && git commit -q -m "init"

  # Create a bare remote and push
  REMOTE_DIR=$(mktemp -d)
  git init -q --bare "$REMOTE_DIR"
  git remote add origin "$REMOTE_DIR"
  git push -q origin main 2>/dev/null

  # Create staging branch on remote
  git checkout -q -b staging
  git push -q origin staging 2>/dev/null
  git checkout -q main

  # Create development branch on remote
  git checkout -q -b development
  git push -q origin development 2>/dev/null
  git checkout -q main

  # Fetch so origin/* refs exist
  git fetch -q origin

  echo "$TEMP_DIR"
}

setup_temp_repo_no_staging() {
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR" || exit 1

  git init -q
  git checkout -q -b main

  cat > .deploynope.json <<'CONF'
{
  "owner": "TestOwner",
  "frontendRepo": "test-repo",
  "productionBranch": "main",
  "stagingBranch": "staging",
  "developmentBranch": "development"
}
CONF

  cat > package.json <<'PKG'
{ "name": "test-repo", "version": "1.0.0" }
PKG

  git add -A && git commit -q -m "init"

  REMOTE_DIR=$(mktemp -d)
  git init -q --bare "$REMOTE_DIR"
  git remote add origin "$REMOTE_DIR"
  git push -q origin main 2>/dev/null
  git fetch -q origin

  echo "$TEMP_DIR"
}

teardown_temp_repo() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
  if [ -n "$REMOTE_DIR" ] && [ -d "$REMOTE_DIR" ]; then
    rm -rf "$REMOTE_DIR"
  fi
}

# ── JSON input builder ───────────────────────────────────────────────────────

# Build the JSON input that Claude Code hooks receive on stdin
make_hook_input() {
  local command="$1"
  local cwd="${2:-$TEMP_DIR}"
  jq -n --arg cmd "$command" --arg cwd "$cwd" \
    '{"tool_name":"Bash","tool_input":{"command":$cmd},"cwd":$cwd}'
}

# ── Hook runner ──────────────────────────────────────────────────────────────

# Run a hook with given command, return its stdout
run_hook() {
  local hook_script="$1"
  local command="$2"
  local cwd="${3:-$TEMP_DIR}"
  make_hook_input "$command" "$cwd" | "$HOOKS_DIR/$hook_script"
}

# ── Assertions ───────────────────────────────────────────────────────────────

begin_test() {
  TEST_NAME="$1"
}

assert_decision() {
  local output="$1"
  local expected="$2"

  if [ "$expected" = "passthrough" ]; then
    if [ -z "$output" ]; then
      PASS_COUNT=$((PASS_COUNT + 1))
      printf "  ${GREEN}PASS${NC} %s → passthrough\n" "$TEST_NAME"
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      local actual=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision // "error"')
      printf "  ${RED}FAIL${NC} %s → expected passthrough, got '%s'\n" "$TEST_NAME" "$actual"
    fi
    return
  fi

  local actual=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision // "empty"')
  if [ "$actual" = "$expected" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  ${GREEN}PASS${NC} %s → %s\n" "$TEST_NAME" "$expected"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  ${RED}FAIL${NC} %s → expected '%s', got '%s'\n" "$TEST_NAME" "$expected" "$actual"
  fi
}

assert_reason_contains() {
  local output="$1"
  local substring="$2"
  local reason=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')

  if echo "$reason" | grep -qF "$substring"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  ${GREEN}PASS${NC} %s → reason contains '%s'\n" "$TEST_NAME" "$substring"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  ${RED}FAIL${NC} %s → reason missing '%s'\n" "$TEST_NAME" "$substring"
    printf "         Actual reason: %s\n" "$reason"
  fi
}

# ── Summary ──────────────────────────────────────────────────────────────────

print_summary() {
  local total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
  echo ""
  printf "${CYAN}── Summary ──${NC}\n"
  printf "  Total:   %d\n" "$total"
  printf "  ${GREEN}Passed:  %d${NC}\n" "$PASS_COUNT"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    printf "  ${RED}Failed:  %d${NC}\n" "$FAIL_COUNT"
  else
    printf "  Failed:  0\n"
  fi
  if [ "$SKIP_COUNT" -gt 0 ]; then
    printf "  ${YELLOW}Skipped: %d${NC}\n" "$SKIP_COUNT"
  fi
  echo ""

  if [ "$FAIL_COUNT" -gt 0 ]; then
    return 1
  fi
  return 0
}
