#!/bin/bash
# Tests for check-git-reset.sh
source "$(dirname "$0")/test-helpers.sh"

HOOK="check-git-reset.sh"

echo ""
printf "${CYAN}═══ check-git-reset.sh ═══${NC}\n"

TEMP_DIR=$(setup_temp_repo)

# ── Production reset WITHOUT protection unlock → deny ────────────────────────

begin_test "reset --hard on main (no protection file) → deny"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_decision "$OUTPUT" "deny"

begin_test "deny reason mentions BLOCKED"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_reason_contains "$OUTPUT" "BLOCKED"

begin_test "deny reason mentions protection unlock"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_reason_contains "$OUTPUT" "branch protection to be unlocked"

# ── Production reset WITH protection unlock → ask ────────────────────────────

begin_test "reset --hard on main (protection unlocked) → ask"
echo "2026-03-14T12:00:00Z" > "$TEMP_DIR/.deploynope-protection-unlocked"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_decision "$OUTPUT" "ask"

begin_test "production reset reason mentions PRODUCTION RESET"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_reason_contains "$OUTPUT" "PRODUCTION RESET"
rm -f "$TEMP_DIR/.deploynope-protection-unlocked"

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

begin_test "reason includes reset target (with protection unlocked)"
echo "2026-03-14T12:00:00Z" > "$TEMP_DIR/.deploynope-protection-unlocked"
OUTPUT=$(run_hook "$HOOK" 'git reset --hard origin/staging')
assert_reason_contains "$OUTPUT" "Reset target: origin/staging"
rm -f "$TEMP_DIR/.deploynope-protection-unlocked"

# ── JSON safety: quoted commands produce valid JSON ──────────────────────────

begin_test "reset with quoted target produces valid JSON"
cd "$TEMP_DIR" && git checkout -q -b feature/json-test
OUTPUT=$(run_hook "$HOOK" 'git reset --hard "origin/main"')
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
