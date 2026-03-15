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

# ── JSON safety: quoted JSON in command must produce valid output ─────────────

begin_test "PUT with quoted JSON body produces valid JSON"
OUTPUT=$(run_hook "$HOOK" 'gh api repos/Owner/repo/branches/main/protection -X PUT --input - <<EOF
{"allow_force_pushes": true}
EOF')
assert_decision "$OUTPUT" "ask"

# ── Stale unlock warning ──────────────────────────────────────────────────────

begin_test "fresh enable (no prior state file) → no stale warning"
rm -f "$TEMP_DIR/.deploynope-protection-unlocked" 2>/dev/null
OUTPUT=$(run_hook "$HOOK" 'gh api repos/Owner/repo/branches/main/protection -X PUT -f allow_force_pushes=true')
REASON=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')
if echo "$REASON" | grep -q "previous protection unlock"; then
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → stale warning present on fresh enable\n" "$TEST_NAME"
else
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → no stale warning on fresh enable\n" "$TEST_NAME"
fi

begin_test "second enable (state file exists) → stale warning present"
# State file was written by the previous test's hook run
OUTPUT=$(run_hook "$HOOK" 'gh api repos/Owner/repo/branches/main/protection -X PUT -f allow_force_pushes=true')
assert_reason_contains "$OUTPUT" "previous protection unlock"

begin_test "disable clears state file"
run_hook "$HOOK" 'gh api repos/Owner/repo/branches/main/protection -X PUT -f allow_force_pushes=false' > /dev/null
if [ -f "$TEMP_DIR/.deploynope-protection-unlocked" ]; then
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → state file still exists after disable\n" "$TEST_NAME"
else
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → state file removed\n" "$TEST_NAME"
fi

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
