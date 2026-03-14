#!/bin/bash
# Tests for check-git-branch-delete.sh
source "$(dirname "$0")/test-helpers.sh"

HOOK="check-git-branch-delete.sh"

echo ""
printf "${CYAN}═══ check-git-branch-delete.sh ═══${NC}\n"

TEMP_DIR=$(setup_temp_repo)

# ── Local branch deletion ────────────────────────────────────────────────────

begin_test "git branch -d → ask"
OUTPUT=$(run_hook "$HOOK" 'git branch -d feature/old')
assert_decision "$OUTPUT" "ask"

begin_test "git branch -D (force) → ask"
OUTPUT=$(run_hook "$HOOK" 'git branch -D feature/old')
assert_decision "$OUTPUT" "ask"

begin_test "branch name extracted"
OUTPUT=$(run_hook "$HOOK" 'git branch -d feature/old')
assert_reason_contains "$OUTPUT" "feature/old"

# ── Remote branch deletion ───────────────────────────────────────────────────

begin_test "git push origin --delete → ask"
OUTPUT=$(run_hook "$HOOK" 'git push origin --delete feature/old')
assert_decision "$OUTPUT" "ask"

begin_test "remote delete reason mentions remote"
OUTPUT=$(run_hook "$HOOK" 'git push origin --delete feature/old')
assert_reason_contains "$OUTPUT" "remote"

begin_test "colon syntax (git push origin :branch) → ask"
OUTPUT=$(run_hook "$HOOK" 'git push origin :feature/old')
assert_decision "$OUTPUT" "ask"

# ── With prefixes ────────────────────────────────────────────────────────────

begin_test "branch delete with cd prefix"
OUTPUT=$(run_hook "$HOOK" 'cd /tmp && git branch -d feature/old')
assert_decision "$OUTPUT" "ask"

begin_test "remote delete with && chain"
OUTPUT=$(run_hook "$HOOK" 'echo ok && git push origin --delete feature/old')
assert_decision "$OUTPUT" "ask"

# ── Should NOT intercept ─────────────────────────────────────────────────────

begin_test "git branch (list, no -d)"
OUTPUT=$(run_hook "$HOOK" 'git branch')
assert_decision "$OUTPUT" "passthrough"

begin_test "git branch -a (list all)"
OUTPUT=$(run_hook "$HOOK" 'git branch -a')
assert_decision "$OUTPUT" "passthrough"

begin_test "git checkout -b (create, not delete)"
OUTPUT=$(run_hook "$HOOK" 'git checkout -b feature/new')
assert_decision "$OUTPUT" "passthrough"

begin_test "non-git command"
OUTPUT=$(run_hook "$HOOK" 'rm -rf node_modules')
assert_decision "$OUTPUT" "passthrough"

teardown_temp_repo
print_summary
