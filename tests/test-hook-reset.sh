#!/bin/bash
# Tests for check-git-reset.sh
source "$(dirname "$0")/test-helpers.sh"

HOOK="check-git-reset.sh"

echo ""
printf "${CYAN}═══ check-git-reset.sh ═══${NC}\n"

TEMP_DIR=$(setup_temp_repo)

# ── Production branch reset guards ────────────────────────────────────────────

begin_test "reset --hard on main without state file → deny"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_decision "$OUTPUT" "deny"

begin_test "production deny reason mentions BLOCKED"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_reason_contains "$OUTPUT" "BLOCKED"

begin_test "production deny reason mentions unlock state file"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_reason_contains "$OUTPUT" ".deploynope-protection-unlocked"

begin_test "production deny reason mentions deploy workflow"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_reason_contains "$OUTPUT" "/deploynope-deploy"

cd "$TEMP_DIR" && echo "2026-03-14T10:00:00Z" > .deploynope-protection-unlocked

begin_test "reset --hard on main with state file → ask"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_decision "$OUTPUT" "ask"

begin_test "production ask reason mentions verified unlocked"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_reason_contains "$OUTPUT" "verified unlocked"

begin_test "production ask reason includes reset target"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_reason_contains "$OUTPUT" "Reset target: origin/staging"

# ── Staging reset → ask ──────────────────────────────────────────────────────

begin_test "reset --hard on staging → ask with STAGING severity"
cd "$TEMP_DIR" && git checkout -q staging
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/main')
assert_decision "$OUTPUT" "ask"

begin_test "staging reset reason mentions STAGING BRANCH"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/main')
assert_reason_contains "$OUTPUT" "STAGING BRANCH"

cd "$TEMP_DIR" && git checkout -q main

begin_test "reset --hard on feature branch → ask with WARNING"
cd "$TEMP_DIR" && git checkout -q -b feature/test
OUTPUT=$(run_hook "$HOOK" 'git reset --hard HEAD~1')
assert_decision "$OUTPUT" "ask"

begin_test "feature branch reset reason mentions WARNING"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard HEAD~1')
assert_reason_contains "$OUTPUT" "WARNING"
cd "$TEMP_DIR" && git checkout -q main

begin_test "reset --hard with cd prefix on feature branch"
cd "$TEMP_DIR" && git checkout -q -b feature/cd-test
OUTPUT=$(run_hook "$HOOK" 'cd /tmp && git reset --hard HEAD')
assert_decision "$OUTPUT" "ask"
cd "$TEMP_DIR" && git checkout -q main

# ── Should NOT intercept ─────────────────────────────────────────────────────

begin_test "git reset --soft (not --hard)"
OUTPUT=$(run_hook "$HOOK" 'git reset --soft HEAD~1')
assert_decision "$OUTPUT" "passthrough"

begin_test "git reset without flags"
OUTPUT=$(run_hook "$HOOK" 'git reset HEAD file.txt')
assert_decision "$OUTPUT" "passthrough"

begin_test "non-git command"
OUTPUT=$(run_hook "$HOOK" 'echo reset --hard')
assert_decision "$OUTPUT" "passthrough"

teardown_temp_repo
print_summary
