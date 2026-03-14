#!/bin/bash
# Tests for check-git-push.sh
source "$(dirname "$0")/test-helpers.sh"

HOOK="check-git-push.sh"

echo ""
printf "${CYAN}═══ check-git-push.sh ═══${NC}\n"

TEMP_DIR=$(setup_temp_repo)

# ── Hard block: push to production with staging present ──────────────────────

begin_test "direct push to main (staging exists) → deny"
OUTPUT=$(run_hook "$HOOK" 'git push origin main')
assert_decision "$OUTPUT" "deny"

begin_test "deny reason mentions BLOCKED"
OUTPUT=$(run_hook "$HOOK" 'git push origin main')
assert_reason_contains "$OUTPUT" "BLOCKED"

begin_test "push from main branch (staging exists) → deny"
OUTPUT=$(run_hook "$HOOK" 'git push')
assert_decision "$OUTPUT" "deny"

begin_test "push with cd prefix to main → deny"
OUTPUT=$(run_hook "$HOOK" 'cd /tmp && git push origin main')
assert_decision "$OUTPUT" "deny"

# ── Force-with-lease to production → ask (controlled reset) ─────────────────

begin_test "force-with-lease push to main → ask (reset step)"
OUTPUT=$(run_hook "$HOOK" 'git push --force-with-lease origin main')
assert_decision "$OUTPUT" "ask"

begin_test "force-with-lease reason mentions PRODUCTION RESET"
OUTPUT=$(run_hook "$HOOK" 'git push --force-with-lease origin main')
assert_reason_contains "$OUTPUT" "PRODUCTION RESET"

# ── Push to non-production branch → ask ─────────────────────────────────────

begin_test "push to feature branch → ask"
# Switch to a feature branch first
cd "$TEMP_DIR" && git checkout -q -b feature/test
OUTPUT=$(run_hook "$HOOK" 'git push origin feature/test')
assert_decision "$OUTPUT" "ask"

begin_test "push reason includes branch info"
OUTPUT=$(run_hook "$HOOK" 'git push origin feature/test')
assert_reason_contains "$OUTPUT" "Branch: feature/test"

cd "$TEMP_DIR" && git checkout -q main

# ── Push to production WITHOUT staging → ask with warning ────────────────────

teardown_temp_repo
TEMP_DIR=$(setup_temp_repo_no_staging)

begin_test "push to main (no staging) → ask with warning"
OUTPUT=$(run_hook "$HOOK" 'git push origin main')
assert_decision "$OUTPUT" "ask"

begin_test "no-staging reason mentions NO STAGING"
OUTPUT=$(run_hook "$HOOK" 'git push origin main')
assert_reason_contains "$OUTPUT" "NO STAGING"

# ── Should NOT intercept ─────────────────────────────────────────────────────

begin_test "git pull (not push)"
OUTPUT=$(run_hook "$HOOK" 'git pull origin main')
assert_decision "$OUTPUT" "passthrough"

begin_test "git status"
OUTPUT=$(run_hook "$HOOK" 'git status')
assert_decision "$OUTPUT" "passthrough"

begin_test "npm run push (not git)"
OUTPUT=$(run_hook "$HOOK" 'npm run push')
assert_decision "$OUTPUT" "passthrough"

teardown_temp_repo
print_summary
