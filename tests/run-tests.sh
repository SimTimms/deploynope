#!/bin/bash
# DeployNOPE Test Suite Runner
# Runs all hook unit tests and reports aggregate results.
#
# Usage:
#   ./tests/run-tests.sh              # run all tests
#   ./tests/run-tests.sh push merge   # run only push and merge tests

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
printf "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}\n"
printf "${BOLD}${CYAN}║     DeployNOPE Hook Test Suite       ║${NC}\n"
printf "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}\n"

# Check dependencies
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed. Install with: brew install jq"
  exit 1
fi

# Collect test files
if [ $# -gt 0 ]; then
  TEST_FILES=()
  for arg in "$@"; do
    matched=("$TESTS_DIR"/test-hook-*"$arg"*.sh)
    if [ -f "${matched[0]}" ]; then
      TEST_FILES+=("${matched[0]}")
    else
      echo "WARNING: No test file matching '$arg'"
    fi
  done
else
  TEST_FILES=("$TESTS_DIR"/test-hook-*.sh)
fi

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_SUITES=()

for test_file in "${TEST_FILES[@]}"; do
  # Run each test file and capture output + exit code
  OUTPUT=$(bash "$test_file" 2>&1) || true
  echo "$OUTPUT"

  # Parse pass/fail counts from the summary line
  PASS=$(echo "$OUTPUT" | grep -oE 'Passed:\s+[0-9]+' | grep -oE '[0-9]+' || echo "0")
  FAIL=$(echo "$OUTPUT" | grep -oE 'Failed:\s+[0-9]+' | grep -oE '[0-9]+' || echo "0")

  TOTAL_PASS=$((TOTAL_PASS + PASS))
  TOTAL_FAIL=$((TOTAL_FAIL + FAIL))

  if [ "$FAIL" -gt 0 ]; then
    SUITE_NAME=$(basename "$test_file" .sh)
    FAILED_SUITES+=("$SUITE_NAME")
  fi
done

# ── Aggregate Report ─────────────────────────────────────────────────────────

TOTAL=$((TOTAL_PASS + TOTAL_FAIL))

echo ""
printf "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}\n"
printf "${BOLD}${CYAN}║        AGGREGATE RESULTS             ║${NC}\n"
printf "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}\n"
echo ""
printf "  Total assertions:  %d\n" "$TOTAL"
printf "  ${GREEN}Passed:            %d${NC}\n" "$TOTAL_PASS"

if [ "$TOTAL_FAIL" -gt 0 ]; then
  printf "  ${RED}Failed:            %d${NC}\n" "$TOTAL_FAIL"
  echo ""
  printf "  ${RED}Failed suites:${NC}\n"
  for suite in "${FAILED_SUITES[@]}"; do
    printf "    - %s\n" "$suite"
  done
  echo ""
  printf "${RED}${BOLD}TESTS FAILED${NC}\n"
  exit 1
else
  printf "  Failed:            0\n"
  echo ""
  printf "${GREEN}${BOLD}ALL TESTS PASSED${NC}\n"
  exit 0
fi
