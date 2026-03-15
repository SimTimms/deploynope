#!/bin/bash
# Tests for check-git-merge.sh
source "$(dirname "$0")/test-helpers.sh"

HOOK="check-git-merge.sh"

echo ""
printf "${CYAN}═══ check-git-merge.sh ═══${NC}\n"

TEMP_DIR=$(setup_temp_repo)

# ── BLOCK: merging non-production into development ───────────────────────────

begin_test "merge feature into development → deny"
cd "$TEMP_DIR" && git checkout -q development
OUTPUT=$(run_hook "$HOOK" 'git merge feature/test')
assert_decision "$OUTPUT" "deny"

begin_test "deny reason mentions drift"
OUTPUT=$(run_hook "$HOOK" 'git merge feature/test')
assert_reason_contains "$OUTPUT" "drift"

begin_test "merge release branch into development → deny"
OUTPUT=$(run_hook "$HOOK" 'git merge 1.5.0')
assert_decision "$OUTPUT" "deny"

# ── ALLOW: merging production into development → ask ─────────────────────────

begin_test "merge main into development → ask (post-deploy step)"
OUTPUT=$(run_hook "$HOOK" 'git merge main')
assert_decision "$OUTPUT" "ask"

begin_test "merge master into development → deny (master is not the configured prod branch)"
# With productionBranch=main in config, 'master' is NOT the production branch.
# Only the configured production branch is allowed to merge into development.
OUTPUT=$(run_hook "$HOOK" 'git merge master')
assert_decision "$OUTPUT" "deny"

cd "$TEMP_DIR" && git checkout -q main

# ── Merges into production branch → deny (hard block) ────────────────────────

begin_test "merge into main → deny (direct merge to production blocked)"
OUTPUT=$(run_hook "$HOOK" 'git merge staging')
assert_decision "$OUTPUT" "deny"

begin_test "production merge reason mentions BLOCKED"
OUTPUT=$(run_hook "$HOOK" 'git merge staging')
assert_reason_contains "$OUTPUT" "BLOCKED"

begin_test "production merge reason mentions staging reset"
OUTPUT=$(run_hook "$HOOK" 'git merge staging')
assert_reason_contains "$OUTPUT" "staging reset"

begin_test "merge any branch into main → deny"
OUTPUT=$(run_hook "$HOOK" 'git merge feature/something')
assert_decision "$OUTPUT" "deny"

# ── Merges into staging → ask with staging warning ───────────────────────────

begin_test "merge into staging → ask with staging warning"
cd "$TEMP_DIR" && git checkout -q staging
OUTPUT=$(run_hook "$HOOK" 'git merge 1.5.0')
assert_decision "$OUTPUT" "ask"

begin_test "staging merge reason mentions contention"
OUTPUT=$(run_hook "$HOOK" 'git merge 1.5.0')
assert_reason_contains "$OUTPUT" "contention"

cd "$TEMP_DIR" && git checkout -q main

# ── Normal merges → ask ──────────────────────────────────────────────────────

begin_test "merge on feature branch → ask"
cd "$TEMP_DIR" && git checkout -q -b feature/merge-test
OUTPUT=$(run_hook "$HOOK" 'git merge main')
assert_decision "$OUTPUT" "ask"
cd "$TEMP_DIR" && git checkout -q main

# ── merge --abort → passthrough ──────────────────────────────────────────────

begin_test "merge --abort → passthrough"
OUTPUT=$(run_hook "$HOOK" 'git merge --abort')
assert_decision "$OUTPUT" "passthrough"

# ── With prefixes ────────────────────────────────────────────────────────────

begin_test "merge with cd prefix"
cd "$TEMP_DIR" && git checkout -q development
OUTPUT=$(run_hook "$HOOK" 'cd /tmp && git merge feature/x')
assert_decision "$OUTPUT" "deny"
cd "$TEMP_DIR" && git checkout -q main

# ── Should NOT intercept ─────────────────────────────────────────────────────

begin_test "git status (not merge)"
OUTPUT=$(run_hook "$HOOK" 'git status')
assert_decision "$OUTPUT" "passthrough"

begin_test "non-git command"
OUTPUT=$(run_hook "$HOOK" 'npm install')
assert_decision "$OUTPUT" "passthrough"

teardown_temp_repo
print_summary
