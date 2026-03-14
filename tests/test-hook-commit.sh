#!/bin/bash
# Tests for check-git-commit.sh
source "$(dirname "$0")/test-helpers.sh"

HOOK="check-git-commit.sh"

echo ""
printf "${CYAN}═══ check-git-commit.sh ═══${NC}\n"

TEMP_DIR=$(setup_temp_repo)

# ── Should intercept ─────────────────────────────────────────────────────────

begin_test "basic git commit (no quotes in message)"
OUTPUT=$(run_hook "$HOOK" 'git commit --allow-empty -m test')
assert_decision "$OUTPUT" "ask"

begin_test "commit with cd prefix"
OUTPUT=$(run_hook "$HOOK" 'cd /tmp && git commit --allow-empty -m test')
assert_decision "$OUTPUT" "ask"

begin_test "commit with && chain"
OUTPUT=$(run_hook "$HOOK" 'git add . && git commit --allow-empty -m test')
assert_decision "$OUTPUT" "ask"

begin_test "commit with pipe prefix"
OUTPUT=$(run_hook "$HOOK" 'echo foo || git commit --allow-empty -m test')
assert_decision "$OUTPUT" "ask"

begin_test "commit with semicolon prefix"
OUTPUT=$(run_hook "$HOOK" 'echo foo; git commit --allow-empty -m test')
assert_decision "$OUTPUT" "ask"

begin_test "reason includes [DeployNOPE]"
OUTPUT=$(run_hook "$HOOK" 'git commit --allow-empty -m test')
assert_reason_contains "$OUTPUT" "[DeployNOPE]"

begin_test "reason includes branch name"
OUTPUT=$(run_hook "$HOOK" 'git commit --allow-empty -m test')
assert_reason_contains "$OUTPUT" "Branch: main"

# ── Should NOT intercept ─────────────────────────────────────────────────────

begin_test "git status (no commit)"
OUTPUT=$(run_hook "$HOOK" 'git status')
assert_decision "$OUTPUT" "passthrough"

begin_test "git log with commit in output"
OUTPUT=$(run_hook "$HOOK" 'git log --oneline')
assert_decision "$OUTPUT" "passthrough"

begin_test "npm command (no git)"
OUTPUT=$(run_hook "$HOOK" 'npm install')
assert_decision "$OUTPUT" "passthrough"

begin_test "BUG: echo git commit is intercepted (false positive)"
OUTPUT=$(run_hook "$HOOK" 'echo git commit')
# The regex matches "git commit" even inside echo arguments.
# This is a known false positive — documenting it here.
assert_decision "$OUTPUT" "ask"

# ── Bypass attempts ──────────────────────────────────────────────────────────

begin_test "commit hidden after multiple &&"
OUTPUT=$(run_hook "$HOOK" 'cd /tmp && echo hi && git commit --allow-empty -m sneak')
assert_decision "$OUTPUT" "ask"

# ── Known bug: quotes in command break JSON output ───────────────────────────

begin_test "BUG: commit with quoted message produces invalid JSON"
OUTPUT=$(run_hook "$HOOK" 'git commit -m "quoted message"')
# The hook embeds $COMMAND unescaped in a heredoc, so quotes break the JSON.
# This test documents the bug — it should FAIL until the hooks are fixed.
PARSED=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null || echo "parse_error")
if [ "$PARSED" = "parse_error" ]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → confirmed bug (invalid JSON)\n" "$TEST_NAME"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → bug appears fixed (got valid JSON)\n" "$TEST_NAME"
fi

teardown_temp_repo
print_summary
