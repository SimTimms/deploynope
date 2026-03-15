# Changelog

All notable changes to this project will be documented in this file.

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
