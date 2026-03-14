#!/bin/bash
# Tests for check-git-commit.sh
source "$(dirname "$0")/test-helpers.sh"

HOOK="check-git-commit.sh"

echo ""
printf "${CYAN}═══ check-git-commit.sh ═══${NC}\n"

TEMP_DIR=$(setup_temp_repo)

# ── Should intercept ─────────────────────────────────────────────────────────

begin_test "basic git commit"
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

begin_test "echo git commit (false positive fixed)"
OUTPUT=$(run_hook "$HOOK" 'echo git commit')
assert_decision "$OUTPUT" "passthrough"

# ── Bypass attempts ──────────────────────────────────────────────────────────

begin_test "commit hidden after multiple &&"
OUTPUT=$(run_hook "$HOOK" 'cd /tmp && echo hi && git commit --allow-empty -m sneak')
assert_decision "$OUTPUT" "ask"

# ── JSON safety: quotes in commands must produce valid JSON ──────────────────

begin_test "commit with quoted message produces valid JSON"
OUTPUT=$(run_hook "$HOOK" 'git commit -m "quoted message"')
assert_decision "$OUTPUT" "ask"

begin_test "commit with special chars in message"
OUTPUT=$(run_hook "$HOOK" 'git commit -m "fix: handle \"edge case\" with backslash"')
assert_decision "$OUTPUT" "ask"

teardown_temp_repo
print_summary
