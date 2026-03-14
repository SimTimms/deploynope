#!/bin/bash
# Tests for check-gh-pr-create.sh
source "$(dirname "$0")/test-helpers.sh"

HOOK="check-gh-pr-create.sh"

echo ""
printf "${CYAN}═══ check-gh-pr-create.sh ═══${NC}\n"

TEMP_DIR=$(setup_temp_repo)

# ── BLOCK: PRs to production ─────────────────────────────────────────────────

begin_test "PR to main → deny"
OUTPUT=$(run_hook "$HOOK" 'gh pr create --base main --title "feature"')
assert_decision "$OUTPUT" "deny"

begin_test "PR to main reason mentions BLOCKED"
OUTPUT=$(run_hook "$HOOK" 'gh pr create --base main --title "feature"')
assert_reason_contains "$OUTPUT" "BLOCKED"

begin_test "PR to master → deny"
OUTPUT=$(run_hook "$HOOK" 'gh pr create --base master --title "feature"')
assert_decision "$OUTPUT" "deny"

begin_test "PR with no --base (defaults to prod) → deny"
OUTPUT=$(run_hook "$HOOK" 'gh pr create --title "feature"')
assert_decision "$OUTPUT" "deny"

# ── BLOCK: PRs to staging ────────────────────────────────────────────────────

begin_test "PR to staging → deny"
OUTPUT=$(run_hook "$HOOK" 'gh pr create --base staging --title "feature"')
assert_decision "$OUTPUT" "deny"

begin_test "PR to staging reason mentions not updated via PRs"
OUTPUT=$(run_hook "$HOOK" 'gh pr create --base staging --title "feature"')
assert_reason_contains "$OUTPUT" "not updated via PRs"

# ── BLOCK: PRs to development ────────────────────────────────────────────────

begin_test "PR to development → deny"
OUTPUT=$(run_hook "$HOOK" 'gh pr create --base development --title "feature"')
assert_decision "$OUTPUT" "deny"

begin_test "PR to develop → deny"
OUTPUT=$(run_hook "$HOOK" 'gh pr create --base develop --title "feature"')
assert_decision "$OUTPUT" "deny"

begin_test "PR to dev → deny"
OUTPUT=$(run_hook "$HOOK" 'gh pr create --base dev --title "feature"')
assert_decision "$OUTPUT" "deny"

# ── ALLOW: PRs to release branches → ask ─────────────────────────────────────

begin_test "PR to release branch → ask"
OUTPUT=$(run_hook "$HOOK" 'gh pr create --base 1.5.0 --title feature')
assert_decision "$OUTPUT" "ask"

begin_test "PR to release/v2.0 → ask"
OUTPUT=$(run_hook "$HOOK" 'gh pr create --base release/v2.0 --title hotfix')
assert_decision "$OUTPUT" "ask"

begin_test "release PR reason includes source and target"
cd "$TEMP_DIR" && git checkout -q -b feature/my-feature
OUTPUT=$(run_hook "$HOOK" 'gh pr create --base 1.5.0 --title my-feature')
assert_reason_contains "$OUTPUT" "Target: 1.5.0"
cd "$TEMP_DIR" && git checkout -q main

# ── With cd prefix ───────────────────────────────────────────────────────────

begin_test "PR to main with cd prefix → deny"
OUTPUT=$(run_hook "$HOOK" 'cd /tmp && gh pr create --base main --title "sneak"')
assert_decision "$OUTPUT" "deny"

begin_test "PR to release with && chain → ask"
OUTPUT=$(run_hook "$HOOK" 'echo ok && gh pr create --base 1.5.0 --title ok')
assert_decision "$OUTPUT" "ask"

# ── Should NOT intercept ─────────────────────────────────────────────────────

begin_test "gh pr list (not create)"
OUTPUT=$(run_hook "$HOOK" 'gh pr list')
assert_decision "$OUTPUT" "passthrough"

begin_test "gh pr view"
OUTPUT=$(run_hook "$HOOK" 'gh pr view 123')
assert_decision "$OUTPUT" "passthrough"

begin_test "non-gh command"
OUTPUT=$(run_hook "$HOOK" 'git status')
assert_decision "$OUTPUT" "passthrough"

teardown_temp_repo
print_summary
