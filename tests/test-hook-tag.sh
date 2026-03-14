#!/bin/bash
# Tests for check-git-tag.sh
source "$(dirname "$0")/test-helpers.sh"

HOOK="check-git-tag.sh"

echo ""
printf "${CYAN}═══ check-git-tag.sh ═══${NC}\n"

TEMP_DIR=$(setup_temp_repo)

# ── Should intercept: tag creation ───────────────────────────────────────────

begin_test "git tag v1.5.0 → ask"
OUTPUT=$(run_hook "$HOOK" 'git tag v1.5.0')
assert_decision "$OUTPUT" "ask"

begin_test "git tag staging/active (claim) → ask"
OUTPUT=$(run_hook "$HOOK" 'git tag staging/active')
assert_decision "$OUTPUT" "ask"

begin_test "staging claim reason mentions CLAIMS staging"
OUTPUT=$(run_hook "$HOOK" 'git tag staging/active')
assert_reason_contains "$OUTPUT" "CLAIMS staging"

# ── Should intercept: tag deletion ───────────────────────────────────────────

begin_test "git tag -d staging/active (clear) → ask"
OUTPUT=$(run_hook "$HOOK" 'git tag -d staging/active')
assert_decision "$OUTPUT" "ask"

begin_test "staging clear reason mentions CLEARS"
OUTPUT=$(run_hook "$HOOK" 'git tag -d staging/active')
assert_reason_contains "$OUTPUT" "CLEARS"

begin_test "tag create with cd prefix"
OUTPUT=$(run_hook "$HOOK" 'cd /tmp && git tag v2.0.0')
assert_decision "$OUTPUT" "ask"

# ── Should NOT intercept: read-only tag operations ───────────────────────────

begin_test "git tag -l (list) → passthrough"
OUTPUT=$(run_hook "$HOOK" 'git tag -l')
assert_decision "$OUTPUT" "passthrough"

begin_test "git tag -l staging/active → passthrough"
OUTPUT=$(run_hook "$HOOK" 'git tag -l "staging/active"')
assert_decision "$OUTPUT" "passthrough"

begin_test "git tag (bare list) → passthrough"
OUTPUT=$(run_hook "$HOOK" 'git tag')
assert_decision "$OUTPUT" "passthrough"

begin_test "git tag -n (show messages) → passthrough"
OUTPUT=$(run_hook "$HOOK" 'git tag -n')
assert_decision "$OUTPUT" "passthrough"

# ── Should NOT intercept: non-tag commands ───────────────────────────────────

begin_test "git push (not tag)"
OUTPUT=$(run_hook "$HOOK" 'git push origin v1.5.0')
assert_decision "$OUTPUT" "passthrough"

begin_test "non-git command"
OUTPUT=$(run_hook "$HOOK" 'npm version patch')
assert_decision "$OUTPUT" "passthrough"

teardown_temp_repo
print_summary
