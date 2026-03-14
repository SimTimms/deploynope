# Changelog

All notable changes to this project will be documented in this file.

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
