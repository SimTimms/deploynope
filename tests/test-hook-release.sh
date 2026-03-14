#!/bin/bash
# Tests for check-gh-release.sh
source "$(dirname "$0")/test-helpers.sh"

HOOK="check-gh-release.sh"

echo ""
printf "${CYAN}═══ check-gh-release.sh ═══${NC}\n"

TEMP_DIR=$(setup_temp_repo)

# ── Should intercept ─────────────────────────────────────────────────────────

begin_test "gh release create → ask"
OUTPUT=$(run_hook "$HOOK" 'gh release create v1.5.0')
assert_decision "$OUTPUT" "ask"

begin_test "reason includes tag"
OUTPUT=$(run_hook "$HOOK" 'gh release create v1.5.0')
assert_reason_contains "$OUTPUT" "Tag: v1.5.0"

begin_test "reason reminds about BOTH repos"
OUTPUT=$(run_hook "$HOOK" 'gh release create v1.5.0')
assert_reason_contains "$OUTPUT" "BOTH repos"

begin_test "release with --repo flag"
OUTPUT=$(run_hook "$HOOK" 'gh release create v1.5.0 --repo Owner/backend')
assert_decision "$OUTPUT" "ask"

begin_test "repo flag extracted in reason"
OUTPUT=$(run_hook "$HOOK" 'gh release create v1.5.0 --repo Owner/backend')
assert_reason_contains "$OUTPUT" "Owner/backend"

begin_test "release with cd prefix"
OUTPUT=$(run_hook "$HOOK" 'cd /tmp && gh release create v1.5.0')
assert_decision "$OUTPUT" "ask"

# ── Should NOT intercept ─────────────────────────────────────────────────────

begin_test "gh release list (not create)"
OUTPUT=$(run_hook "$HOOK" 'gh release list')
assert_decision "$OUTPUT" "passthrough"

begin_test "gh release view"
OUTPUT=$(run_hook "$HOOK" 'gh release view v1.4.0')
assert_decision "$OUTPUT" "passthrough"

begin_test "non-gh command"
OUTPUT=$(run_hook "$HOOK" 'git tag v1.5.0')
assert_decision "$OUTPUT" "passthrough"

teardown_temp_repo
print_summary
