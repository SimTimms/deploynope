#!/bin/bash
# Tests for check-gh-api-protection.sh
source "$(dirname "$0")/test-helpers.sh"

HOOK="check-gh-api-protection.sh"

echo ""
printf "${CYAN}═══ check-gh-api-protection.sh ═══${NC}\n"

TEMP_DIR=$(setup_temp_repo)

# ── Should intercept: PUT to protection endpoint ─────────────────────────────

begin_test "PUT to protection endpoint → ask"
OUTPUT=$(run_hook "$HOOK" 'gh api repos/Owner/repo/branches/main/protection -X PUT -f allow_force_pushes=true')
assert_decision "$OUTPUT" "ask"

begin_test "reason mentions BRANCH PROTECTION MODIFICATION"
OUTPUT=$(run_hook "$HOOK" 'gh api repos/Owner/repo/branches/main/protection -X PUT -f allow_force_pushes=true')
assert_reason_contains "$OUTPUT" "BRANCH PROTECTION MODIFICATION"

begin_test "disable force-push → ask"
OUTPUT=$(run_hook "$HOOK" 'gh api repos/Owner/repo/branches/main/protection -X PUT -f allow_force_pushes=false')
assert_decision "$OUTPUT" "ask"

begin_test "reason mentions security-critical"
OUTPUT=$(run_hook "$HOOK" 'gh api repos/Owner/repo/branches/main/protection -X PUT -f allow_force_pushes=false')
assert_reason_contains "$OUTPUT" "security-critical"

# ── Should NOT intercept: GET protection (read-only) ─────────────────────────

begin_test "GET protection → passthrough"
OUTPUT=$(run_hook "$HOOK" 'gh api repos/Owner/repo/branches/main/protection')
assert_decision "$OUTPUT" "passthrough"

# ── Should NOT intercept: non-protection API ─────────────────────────────────

begin_test "gh api to non-protection endpoint → passthrough"
OUTPUT=$(run_hook "$HOOK" 'gh api repos/Owner/repo/pulls -X PUT')
assert_decision "$OUTPUT" "passthrough"

# ── Should NOT intercept: non-gh commands ────────────────────────────────────

begin_test "curl to API (not gh) → passthrough"
OUTPUT=$(run_hook "$HOOK" 'curl https://api.github.com/repos/Owner/repo/branches/main/protection')
assert_decision "$OUTPUT" "passthrough"

teardown_temp_repo
print_summary
