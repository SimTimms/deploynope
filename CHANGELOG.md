# Changelog

All notable changes to this project will be documented in this file.

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
