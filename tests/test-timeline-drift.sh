#!/bin/bash
# Tests for branch drift detection in the dashboard stage hook
# Verifies that drift data is correctly written to dashboard state
# when the branch is behind the production branch.
source "$(dirname "$0")/test-helpers.sh"

HOOK="update-dashboard-stage.sh"
HOOKS_DIR="$(cd "$(dirname "$0")/../.claude/hooks" && pwd)"

echo ""
printf "${CYAN}═══ Branch Drift Detection ═══${NC}\n"

# ── Setup ───────────────────────────────────────────────────────────────────

# Create a temp repo with a main branch that has commits ahead of a feature branch
setup_drift_repo() {
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR" || exit 1

  git init -q
  git checkout -q -b main

  # Create .deploynope.json
  cat > .deploynope.json <<'CONF'
{
  "owner": "TestOwner",
  "frontendRepo": "test-repo",
  "productionBranch": "main",
  "stagingBranch": "staging",
  "developmentBranch": "development"
}
CONF

  cat > package.json <<'PKG'
{ "name": "test-repo", "version": "1.0.0" }
PKG

  git add -A && git commit -q -m "init"

  # Create a bare remote and push
  REMOTE_DIR=$(mktemp -d)
  git init -q --bare "$REMOTE_DIR"
  git remote add origin "$REMOTE_DIR"
  git push -q origin main 2>/dev/null

  # Create feature branch from main
  git checkout -q -b feature/test-drift

  # Now go back to main and add commits (simulating other work merged)
  git checkout -q main
  echo "feature-one work" > feature1.txt
  git add feature1.txt && git commit -q -m "feat: feature one landed"
  echo "feature-one more work" >> feature1.txt
  git add feature1.txt && git commit -q -m "fix: feature one fix"
  git push -q origin main 2>/dev/null

  # Go back to the feature branch (now 2 commits behind main)
  git checkout -q feature/test-drift
  git fetch -q origin 2>/dev/null

  echo "$TEMP_DIR"
}

setup_no_drift_repo() {
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR" || exit 1

  git init -q
  git checkout -q -b main

  cat > .deploynope.json <<'CONF'
{
  "owner": "TestOwner",
  "frontendRepo": "test-repo",
  "productionBranch": "main",
  "stagingBranch": "staging",
  "developmentBranch": "development"
}
CONF

  git add -A && git commit -q -m "init"

  REMOTE_DIR=$(mktemp -d)
  git init -q --bare "$REMOTE_DIR"
  git remote add origin "$REMOTE_DIR"
  git push -q origin main 2>/dev/null

  # Feature branch created from latest main — no drift
  git checkout -q -b feature/up-to-date
  git fetch -q origin 2>/dev/null

  echo "$TEMP_DIR"
}

# Build the stop-event JSON input that the hook expects
make_stop_input() {
  local message="$1"
  local cwd="$2"
  local session_id="${3:-test-drift-$$}"
  jq -n \
    --arg msg "$message" \
    --arg cwd "$cwd" \
    --arg sid "$session_id" \
    '{
      last_assistant_message: $msg,
      cwd: $cwd,
      session_id: $sid
    }'
}

# ── Test: drift detected when branch is behind ─────────────────────────────

TEMP_DIR=$(setup_drift_repo)
STATE_DIR=$(mktemp -d)
STATE_FILE="$STATE_DIR/dashboard-state.json"
echo '{"version":1,"agents":{},"stagingClaim":null,"warnings":[],"activity":[]}' > "$STATE_FILE"

# Override HOME so the hook writes to our temp state file
export HOME_BACKUP="$HOME"
export HOME="$(dirname "$STATE_DIR")"
mkdir -p "$HOME/.deploynope"
cp "$STATE_FILE" "$HOME/.deploynope/dashboard-state.json"
STATE_FILE="$HOME/.deploynope/dashboard-state.json"

begin_test "drift detected — branch 2 commits behind main"
INPUT=$(make_stop_input "🤓 DeployNOPE 2.19.0 · Feature" "$TEMP_DIR" "drift-test-1")
echo "$INPUT" | "$HOOKS_DIR/$HOOK" 2>/dev/null

DRIFT_BEHIND=$(jq -r '.agents["drift-test-1"].deploynope.drift.behindBy // 0' "$STATE_FILE")
if [ "$DRIFT_BEHIND" = "2" ]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → behindBy=%s\n" "$TEST_NAME" "$DRIFT_BEHIND"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → expected behindBy=2, got %s\n" "$TEST_NAME" "$DRIFT_BEHIND"
fi

begin_test "drift base branch is 'main'"
DRIFT_BASE=$(jq -r '.agents["drift-test-1"].deploynope.drift.baseBranch // ""' "$STATE_FILE")
if [ "$DRIFT_BASE" = "main" ]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → baseBranch=%s\n" "$TEST_NAME" "$DRIFT_BASE"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → expected baseBranch=main, got %s\n" "$TEST_NAME" "$DRIFT_BASE"
fi

begin_test "drift lastChecked is set"
DRIFT_CHECKED=$(jq -r '.agents["drift-test-1"].deploynope.drift.lastChecked // ""' "$STATE_FILE")
if [ -n "$DRIFT_CHECKED" ]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → lastChecked=%s\n" "$TEST_NAME" "$DRIFT_CHECKED"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → lastChecked is empty\n" "$TEST_NAME"
fi

# Cleanup
teardown_temp_repo

# ── Test: no drift when branch is up to date ───────────────────────────────

TEMP_DIR=$(setup_no_drift_repo)
echo '{"version":1,"agents":{},"stagingClaim":null,"warnings":[],"activity":[]}' > "$STATE_FILE"

begin_test "no drift — branch is up to date with main"
INPUT=$(make_stop_input "🤓 DeployNOPE 2.19.0 · Feature" "$TEMP_DIR" "drift-test-2")
echo "$INPUT" | "$HOOKS_DIR/$HOOK" 2>/dev/null

DRIFT_BEHIND=$(jq -r '.agents["drift-test-2"].deploynope.drift.behindBy // 0' "$STATE_FILE")
if [ "$DRIFT_BEHIND" = "0" ]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → behindBy=%s\n" "$TEST_NAME" "$DRIFT_BEHIND"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → expected behindBy=0, got %s\n" "$TEST_NAME" "$DRIFT_BEHIND"
fi

# Cleanup
teardown_temp_repo

# ── Test: drift increases as main moves forward ───────────────────────────

TEMP_DIR=$(setup_drift_repo)
echo '{"version":1,"agents":{},"stagingClaim":null,"warnings":[],"activity":[]}' > "$STATE_FILE"

# Add more commits to main
cd "$TEMP_DIR" || exit 1
git checkout -q main
echo "another feature" > feature2.txt
git add feature2.txt && git commit -q -m "feat: feature two"
git push -q origin main 2>/dev/null
git checkout -q feature/test-drift
git fetch -q origin 2>/dev/null

begin_test "drift increases — branch now 3 commits behind"
INPUT=$(make_stop_input "⚠️ DeployNOPE 2.19.0 · Preflight" "$TEMP_DIR" "drift-test-3")
echo "$INPUT" | "$HOOKS_DIR/$HOOK" 2>/dev/null

DRIFT_BEHIND=$(jq -r '.agents["drift-test-3"].deploynope.drift.behindBy // 0' "$STATE_FILE")
if [ "$DRIFT_BEHIND" = "3" ]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → behindBy=%s\n" "$TEST_NAME" "$DRIFT_BEHIND"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → expected behindBy=3, got %s\n" "$TEST_NAME" "$DRIFT_BEHIND"
fi

# Cleanup
teardown_temp_repo

# ── Test: drift clears after merge ──────────────────────────────────────────

TEMP_DIR=$(setup_drift_repo)
echo '{"version":1,"agents":{},"stagingClaim":null,"warnings":[],"activity":[]}' > "$STATE_FILE"

cd "$TEMP_DIR" || exit 1
# Merge main into the feature branch to resolve drift
git merge -q origin/main --no-edit 2>/dev/null

begin_test "drift clears — branch merged with main"
INPUT=$(make_stop_input "🤓 DeployNOPE 2.19.0 · Feature" "$TEMP_DIR" "drift-test-4")
echo "$INPUT" | "$HOOKS_DIR/$HOOK" 2>/dev/null

DRIFT_BEHIND=$(jq -r '.agents["drift-test-4"].deploynope.drift.behindBy // 0' "$STATE_FILE")
if [ "$DRIFT_BEHIND" = "0" ]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC} %s → behindBy=%s\n" "$TEST_NAME" "$DRIFT_BEHIND"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${NC} %s → expected behindBy=0, got %s\n" "$TEST_NAME" "$DRIFT_BEHIND"
fi

# Cleanup
teardown_temp_repo
export HOME="$HOME_BACKUP"

# ── Summary ─────────────────────────────────────────────────────────────────

print_summary
