#!/bin/bash
# Tests for dashboard timeline stage progression
# Verifies that every stage maps to the correct index and progress
# moves forward monotonically through the pipeline.
source "$(dirname "$0")/test-helpers.sh"

echo ""
printf "${CYAN}═══ Timeline Stage Progression ═══${NC}\n"

# ── Test: every stage in stageOrder maps to a valid stepIndex ────────────────

STAGE_ORDER=(
  "New Work"
  "Configure"
  "Verify Rules"
  "Feature"
  "Changelog"
  "Preflight"
  "Stale Check"
  "Deploy Status"
  "Staging Contention"
  "Staging Claim"
  "Staging Reset"
  "Staging Validation"
  "Production"
  "Release"
  "Release Manifest"
  "Post-Deploy"
  "Reconcile"
  "Complete"
)

TOTAL_STAGES=${#STAGE_ORDER[@]}

# Use Node.js to evaluate the same matching logic from dashboard/index.html
# This mirrors the exact JavaScript from the dashboard
match_stage() {
  local current_stage="$1"
  node -e "
    var stageOrder = [
      'New Work', 'Configure', 'Verify Rules', 'Feature',
      'Changelog', 'Preflight', 'Stale Check', 'Deploy Status',
      'Staging Contention', 'Staging Claim', 'Staging Reset', 'Staging Validation',
      'Production', 'Release', 'Release Manifest',
      'Post-Deploy', 'Reconcile', 'Complete'
    ];
    var nonLinearStages = { 'rollback': true, 'deploy': true };
    var currentStage = process.argv[1];
    var stepIndex = -1;
    if (nonLinearStages[currentStage.toLowerCase()]) {
      stepIndex = -1;
    } else {
      for (var si = 0; si < stageOrder.length; si++) {
        if (stageOrder[si].toLowerCase() === currentStage.toLowerCase()) { stepIndex = si; break; }
      }
      if (stepIndex === -1) {
        for (var si = 0; si < stageOrder.length; si++) {
          if (currentStage.toLowerCase().indexOf(stageOrder[si].toLowerCase()) !== -1 ||
              stageOrder[si].toLowerCase().indexOf(currentStage.toLowerCase()) !== -1) { stepIndex = si; break; }
        }
      }
    }
    if (stepIndex >= 0) {
      var stepNum = stepIndex + 1;
      var pct = Math.round((stepNum / stageOrder.length) * 100);
      console.log(stepIndex + ':' + pct);
    } else {
      console.log('-1:0');
    }
  " "$current_stage"
}

# ── Test: each stage resolves to a valid index ──────────────────────────────

PREV_INDEX=-1
PREV_PCT=0

for i in "${!STAGE_ORDER[@]}"; do
  STAGE="${STAGE_ORDER[$i]}"
  RESULT=$(match_stage "$STAGE")
  INDEX=$(echo "$RESULT" | cut -d: -f1)
  PCT=$(echo "$RESULT" | cut -d: -f2)

  begin_test "stage '$STAGE' resolves to index $i"
  if [ "$INDEX" = "$i" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  ${GREEN}PASS${NC} %s → index %s, %s%%\n" "$TEST_NAME" "$INDEX" "$PCT"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  ${RED}FAIL${NC} %s → expected index %s, got %s\n" "$TEST_NAME" "$i" "$INDEX"
  fi

  # ── Test: progress moves forward ──────────────────────────────────────────

  begin_test "stage '$STAGE' progress ($PCT%) > previous ($PREV_PCT%)"
  if [ "$PCT" -gt "$PREV_PCT" ] || [ "$i" -eq 0 ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  ${GREEN}PASS${NC} %s\n" "$TEST_NAME"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  ${RED}FAIL${NC} %s → progress did not increase\n" "$TEST_NAME"
  fi

  PREV_INDEX=$INDEX
  PREV_PCT=$PCT
done

# ── Test: final stage is 100% ───────────────────────────────────────────────

begin_test "final stage 'Complete' reaches 100%"
RESULT=$(match_stage "Complete")
PCT=$(echo "$RESULT" | cut -d: -f2)
if [ "$PCT" = "100" ]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → %s%%\n" "$TEST_NAME" "$PCT"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → expected 100%%, got %s%%\n" "$TEST_NAME" "$PCT"
fi

# ── Test: first stage is > 0% ──────────────────────────────────────────────

begin_test "first stage 'New Work' has non-zero progress"
RESULT=$(match_stage "New Work")
PCT=$(echo "$RESULT" | cut -d: -f2)
if [ "$PCT" -gt 0 ]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → %s%%\n" "$TEST_NAME" "$PCT"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → expected > 0%%, got %s%%\n" "$TEST_NAME" "$PCT"
fi

# ── Test: non-linear stages return -1 (no progress bar) ────────────────────

for NL_STAGE in "Rollback" "Deploy" "rollback" "deploy"; do
  begin_test "non-linear stage '$NL_STAGE' returns index -1"
  RESULT=$(match_stage "$NL_STAGE")
  INDEX=$(echo "$RESULT" | cut -d: -f1)
  if [ "$INDEX" = "-1" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  ${GREEN}PASS${NC} %s → index %s\n" "$TEST_NAME" "$INDEX"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  ${RED}FAIL${NC} %s → expected -1, got %s\n" "$TEST_NAME" "$INDEX"
  fi
done

# ── Test: case-insensitive matching ─────────────────────────────────────────

for CASE_STAGE in "new work" "FEATURE" "staging contention" "COMPLETE"; do
  begin_test "case-insensitive match '$CASE_STAGE'"
  RESULT=$(match_stage "$CASE_STAGE")
  INDEX=$(echo "$RESULT" | cut -d: -f1)
  if [ "$INDEX" -ge 0 ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  ${GREEN}PASS${NC} %s → index %s\n" "$TEST_NAME" "$INDEX"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  ${RED}FAIL${NC} %s → got -1 (no match)\n" "$TEST_NAME"
  fi
done

# ── Test: substring matching for extended stage names ───────────────────────

for SUB_STAGE in "Post-Deploy Check" "Release Manifest Generation"; do
  begin_test "substring match '$SUB_STAGE'"
  RESULT=$(match_stage "$SUB_STAGE")
  INDEX=$(echo "$RESULT" | cut -d: -f1)
  if [ "$INDEX" -ge 0 ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  ${GREEN}PASS${NC} %s → index %s\n" "$TEST_NAME" "$INDEX"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  ${RED}FAIL${NC} %s → got -1 (no match)\n" "$TEST_NAME"
  fi
done

# ── Test: unknown stage returns -1 ──────────────────────────────────────────

begin_test "unknown stage 'Banana' returns -1"
RESULT=$(match_stage "Banana")
INDEX=$(echo "$RESULT" | cut -d: -f1)
if [ "$INDEX" = "-1" ]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → index %s\n" "$TEST_NAME" "$INDEX"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → expected -1, got %s\n" "$TEST_NAME" "$INDEX"
fi

# ── Summary ─────────────────────────────────────────────────────────────────

print_summary
