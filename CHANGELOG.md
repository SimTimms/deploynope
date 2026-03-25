# Changelog

All notable changes to this project will be documented in this file.

## [2.21.0] - 2026-03-25

### Added
- Left accent bar on agent cards colored by stage (blue=feature, yellow=staging, red=production, green=active/complete, grey=idle)
- "Awaiting staging" stage detection for branches that have been pushed but not yet merged to staging
- Contextual status hints in agent meta row: "Pushed — awaiting staging", "Committed — not yet pushed", "Working locally", "Ready for cleanup", "No recent activity"

### Changed
- Agent cards now use transparent background with soft bottom dividers instead of bordered cards
- Progress bar uses subtle background instead of border
- Agent meta row shows actionable status instead of repeating the branch name when branch matches agent name

[2.21.0]: https://github.com/SimTimms/deploynope/compare/v2.20.0...v2.21.0

## [2.20.0] - 2026-03-25

### Added
- Branch drift detection: stage hook and scan check how far branches are behind/ahead of production
- Drift warning badges on agent cards (yellow 1-10 commits behind, red 11+, grey ahead count)
- Drift rules in deploy framework: informational at early stages, blocking at Staging Contention onwards
- Development bar in dashboard: separates development branches from agent cards, like staging
- "In development" progress bar with dimmed style for agents without active DeployNOPE
- Descriptive stage labels in timeline (e.g. "Working on feature branch" instead of "Feature")
- "Complete" terminal stage with modified-after-complete flag
- Scan button and `/api/scan` endpoint in dashboard
- Timeline progression tests (49 assertions covering all 18 stages)
- Branch drift detection tests (6 assertions)
- Visual timeline test with optional drift simulation

### Changed
- Branches with no unique commits no longer marked "safe to delete" — no banner shown instead
- Duplicate branch→target row hidden when branch and target are identical
- Progress bar only shows active pipeline stages when DeployNOPE is driving; otherwise shows "In development"
- Scan updates drift on hook-registered agents without overwriting their DeployNOPE data
- Non-linear stages (Rollback, Deploy) excluded from progress bar positioning

### Fixed
- Scan button missing from worktree dashboard builds

[2.20.0]: https://github.com/SimTimms/deploynope/compare/v2.19.0...v2.20.0

## [2.19.0] - 2026-03-24

### Added
- Dashboard: group agent cards by repository with dedicated repo headers
- Dashboard: per-repo staging environment bars showing claimed/available status with timeline
- Dashboard: progress bar timeline on all agent cards, inferred from branch context when no hook data
- Dashboard: finer-grained deployment stages in timeline (Changelog, Staging Contention, Staging Claim, Staging Reset)
- Dashboard: clickable PR banner showing awaiting-merge status with link to PR
- Dashboard: agent remove button with worktree cleanup and dirty-check confirmation modal
- Dashboard: worktree cleanup detection in scan — shows "safe to delete" / "review" banners
- PostToolUse hook to capture PR URLs from command output
- Render-time deduplication of agents by cwd to prevent duplicate cards
- Scan deduplication: skip repos already registered by hooks

### Fixed
- Scan no longer fabricates fake staging validation gate for branches on staging
- Stale threshold increased to 60 minutes, based on last action timestamp not scan time
- Reduced agent name font size for lighter visual weight

[2.19.0]: https://github.com/SimTimms/deploynope/compare/v2.18.0...v2.19.0

## [2.17.0] - 2026-03-23

### Added
- Real-time web dashboard for monitoring DeployNOPE activity across all agents and worktrees — run with `./dashboard/start.sh`
- All 9 hooks now write agent state to `~/.deploynope/dashboard-state.json` for dashboard tracking
- `dashboard_update` and `resolve_repo_name` helper functions in `hook-helpers.sh`

### Fixed
- Dashboard state updates run synchronously in hooks (background processes were killed on hook exit)
- Server watches state directory instead of file for macOS inode compatibility with atomic writes

[2.17.0]: https://github.com/SimTimms/deploynope/compare/v2.16.0...v2.17.0

## [2.16.0] - 2026-03-20

### Added
- Configurable reconciliation strategy (`merge`/`cherry-pick`/`ask`) for branch alignment during `/deploynope-reconcile` — analyses divergence and recommends a strategy based on commit count, direction, and history shape
- Configurable default base branch for new work (`defaultBaseBranch` in `/deploynope-configure`)

[2.16.0]: https://github.com/SimTimms/deploynope/compare/v2.15.0...v2.16.0

## [2.15.0] - 2026-03-17

### Fixed
- Hook command parsing: chained commands (`cd && git checkout && git merge`) now correctly detect the merge target and source branch
- Hook push guard: post-reset fast-forward pushes to production (e.g. release manifests) are prompted for approval instead of hard-blocked
- Hook merge guard: `origin/` prefix stripped when comparing merge source against production branch name

[2.15.0]: https://github.com/SimTimms/deploynope/compare/v2.14.0...v2.15.0

## [2.14.0] - 2026-03-16

### Changed
- Hardened branch protection and aligned docs with config-driven branch model

[2.14.0]: https://github.com/SimTimms/deploynope/compare/v2.13.0...v2.14.0

## [2.13.0] - 2026-03-16

### Added
- `/deploynope-reconcile` command — audits and remediates manual releases done outside DeployNOPE, with auto-detection, 8 alignment checks, and numbered remediation offers

[2.13.0]: https://github.com/SimTimms/deploynope/compare/v2.12.0...v2.13.0

## [2.12.0] - 2026-03-15

### Fixed
- Branch architecture diagram commit dots now align with flow arrow connection points

[2.12.0]: https://github.com/SimTimms/deploynope/compare/v2.11.0...v2.12.0

## [2.11.0] - 2026-03-15

### Added
- Optional branch protection setup (§21) in `/deploynope-configure` — detects current GitHub protection state, shows comparison table, and lets the user opt in, skip, or customise

### Fixed
- Hardcoded `origin/master` in staging contention polling now uses config-driven `origin/<production-branch>..origin/<staging-branch>`
- Production branch default in configure changed from hardcoded `master` to auto-detected (prefers `main`, falls back to `master`)

[2.11.0]: https://github.com/SimTimms/deploynope/compare/v2.10.0...v2.11.0

## [2.10.0] - 2026-03-15

### Changed
- Framework visibility tags now include context (release version or branch name) and severity emojis: `🤓` normal, `⚠️` caution, `🚨` alert
- Tag format changed from `🤓 DeployNOPE @ Stage` to `<emoji> DeployNOPE <context> · Stage` across all 11 command files, CLAUDE.md, and README

### Removed
- Sidecar console log (`.deploynope/console.log` + `tail -f`) — every write required a Bash permission prompt that cluttered the main chat
- `/deploynope-console` command deprecated (sidecar removed)

[2.10.0]: https://github.com/SimTimms/deploynope/compare/v2.9.0...v2.10.0

## [2.9.0] - 2026-03-15

### Added
- DeployNOPE sidecar console: monitor deployment guardrails in a separate terminal pane via `tail -f .deploynope/console.log`
- New `/deploynope-console` command to re-print the monitor setup banner anytime
- Sidecar logging rule in Framework Visibility: all `🤓 DeployNOPE` messages are now also written to `.deploynope/console.log`
- Console banner automatically shown after branch creation in `/deploynope-new-work`

[2.9.0]: https://github.com/SimTimms/deploynope/compare/v2.7.0...v2.9.0

## [2.7.0] - 2026-03-15

### Fixed
- Direct `git merge` into production branch now returns `deny` instead of `ask`, enforcing the staging reset flow
- Push refspec parsing (`HEAD:main`, `feature:main`) now correctly detects production-targeting pushes and blocks them
- Branch protection stale-warning no longer false-positives on fresh unlocks (state file write moved after stale check)

[2.7.0]: https://github.com/SimTimms/deploynope/compare/v2.6.0...v2.7.0

## [2.6.0] - 2026-03-15

### Fixed
- Move demo pages from worktree path to `docs/` at repo root for GitHub Pages compatibility

[2.6.0]: https://github.com/SimTimms/deploynope/compare/v2.5.0...v2.6.0

## [2.5.0] - 2026-03-14

### Added
- Interactive HTML demo pages for all DeployNOPE features (7 pages + index)
- Staging contention polling option in deployment workflow

### Fixed
- Preserve non-DeployNOPE hooks during install and uninstall

### Changed
- Branch references made configuration-driven across all commands
- Reset-hook test expectations aligned with production lock state

[2.5.0]: https://github.com/SimTimms/deploynope/compare/v2.4.0...v2.5.0

## [2.3.0] - 2026-03-14

### Added
- Staging contention polling: when staging is claimed, offers to poll every minute until released and auto-resume deployment
- Automatic cron job cleanup when staging clears or user cancels the wait

[2.3.0]: https://github.com/SimTimms/deploynope/compare/v2.2.0...v2.3.0

## [2.2.0] - 2026-03-14

### Changed
- Moved changelog step from post-deploy (on master) to pre-staging (on release branch)
- Changelog now goes through staging validation like any other code change
- Only the release manifest remains as a post-deploy commit to master
- Updated all three deployment checklists and process overview table

[2.2.0]: https://github.com/SimTimms/deploynope/compare/v1.12.0...v2.2.0

## [1.12.0] - 2026-03-14

### Added
- Mandatory branch sync step after manifest/changelog commits
- Automatic post-deploy checks at end of every deployment
- Changelog automation when enabled in config

### Changed
- Replaced README version history with link to GitHub Releases
- Reordered all three deployment checklists with correct step sequence

[1.12.0]: https://github.com/SimTimms/deploynope/compare/v2.0.0...v1.12.0
