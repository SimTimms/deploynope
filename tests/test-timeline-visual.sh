#!/bin/bash
# Visual timeline progression test
# Creates a test agent on the dashboard and walks it through every stage
# so you can watch the progress bar move from 0% to 100% in real time.
#
# Usage:
#   ./tests/test-timeline-visual.sh          # 2s per stage (default)
#   ./tests/test-timeline-visual.sh 0.5      # 0.5s per stage (fast)
#   ./tests/test-timeline-visual.sh 5        # 5s per stage (slow)
#   ./tests/test-timeline-visual.sh 1 7      # 1s per stage, simulate 7 commits behind main
#
# Prerequisites: dashboard server running on localhost:9876

DELAY="${1:-2}"
DRIFT="${2:-0}"  # simulate N commits behind main
STATE_DIR="$HOME/.deploynope"
STATE_FILE="$STATE_DIR/dashboard-state.json"
AGENT_ID="timeline-test-$$"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

STAGES=(
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

TOTAL=${#STAGES[@]}

# ── Preflight checks ───────────────────────────────────────────────────────

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required. Install with: brew install jq"
  exit 1
fi

mkdir -p "$STATE_DIR"
if [ ! -f "$STATE_FILE" ]; then
  echo '{"version":1,"agents":{},"stagingClaim":null,"warnings":[],"activity":[]}' > "$STATE_FILE"
fi

# Check if dashboard is running
if curl -s -o /dev/null -w "%{http_code}" http://localhost:9876/api/state 2>/dev/null | grep -q "200"; then
  printf "${GREEN}Dashboard detected at localhost:9876${NC}\n"
else
  printf "${YELLOW}Dashboard not detected at localhost:9876 — state file will still update${NC}\n"
fi

echo ""
printf "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${NC}\n"
if [ "$DRIFT" -gt 0 ] 2>/dev/null; then
  printf "${BOLD}${CYAN}║ Timeline Visual — %2d stages, %ss, drift=%s  ║${NC}\n" "$TOTAL" "$DELAY" "$DRIFT"
else
  printf "${BOLD}${CYAN}║   Timeline Visual Test — %2d stages, %ss delay  ║${NC}\n" "$TOTAL" "$DELAY"
fi
printf "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${NC}\n"
printf "  Agent ID: ${BOLD}%s${NC}\n" "$AGENT_ID"
echo ""

# ── Inject test agent ───────────────────────────────────────────────────────

inject_stage() {
  local stage="$1"
  local step="$2"
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq \
    --arg id "$AGENT_ID" \
    --arg now "$now" \
    --arg stage "$stage" \
    --arg step "$step" \
    --argjson drift "$DRIFT" \
    '
    .agents[$id] = (.agents[$id] // {}) * {
      id: $id,
      cwd: "/tmp/timeline-visual-test",
      branch: "timeline-test",
      repo: "deploynope (visual test)",
      lastSeenAt: $now,
      startedAt: ((.agents[$id].startedAt) // $now),
      deploynope: {
        active: true,
        severity: "🤓",
        context: "visual-test",
        stage: $stage,
        completedAt: (
          if ($stage | ascii_downcase) == "complete"
          then $now
          else null
          end
        ),
        modifiedAfterComplete: false,
        gate: (
          if ($stage | ascii_downcase | test("validation|sign.?off|awaiting|gate"))
          then { waiting: true, label: ($stage + " — sign-off required"), since: $now }
          else null
          end
        ),
        drift: (
          if $drift > 0
          then { behindBy: $drift, baseBranch: "main", lastChecked: $now }
          else { behindBy: 0, baseBranch: "main", lastChecked: $now }
          end
        )
      }
    }
    ' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# ── Walk through every stage ────────────────────────────────────────────────

for i in "${!STAGES[@]}"; do
  STAGE="${STAGES[$i]}"
  STEP=$((i + 1))
  PCT=$(( (STEP * 100) / TOTAL ))

  # Build a visual progress bar
  BAR_WIDTH=30
  FILLED=$(( (PCT * BAR_WIDTH) / 100 ))
  EMPTY=$(( BAR_WIDTH - FILLED ))
  BAR=$(printf '%0.s█' $(seq 1 $FILLED 2>/dev/null) || true)
  BAR+=$(printf '%0.s░' $(seq 1 $EMPTY 2>/dev/null) || true)

  printf "  ${GREEN}%2d/%d${NC}  ${BAR}  ${BOLD}%3d%%${NC}  %s\n" "$STEP" "$TOTAL" "$PCT" "$STAGE"

  inject_stage "$STAGE" "$STEP"
  sleep "$DELAY"
done

echo ""
printf "${GREEN}${BOLD}✓ Timeline walked to 100%%${NC}\n"
echo ""

# ── Cleanup ─────────────────────────────────────────────────────────────────

printf "Remove test agent from dashboard? [Y/n] "
read -r REPLY
if [ "$REPLY" != "n" ] && [ "$REPLY" != "N" ]; then
  jq --arg id "$AGENT_ID" 'del(.agents[$id])' "$STATE_FILE" > "$STATE_FILE.tmp" \
    && mv "$STATE_FILE.tmp" "$STATE_FILE"
  printf "${CYAN}Test agent removed.${NC}\n"
else
  printf "${YELLOW}Test agent left in dashboard — remove manually or re-run.${NC}\n"
fi
