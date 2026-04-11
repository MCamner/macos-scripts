# Changelog

All notable changes to this project will be documented in this file.

## [0.1.2]

### Changed
- Make release script executable.
- Update version badge and release flow improvements.

## [0.1.1] - 2026-04-11

### Added
- About / Status dashboard
- Command index
- Self-check and debug bundle commands
- Release notes command
- Main menu workflows expansion

### Changed
- Improved help and command alignment
- Fixed Tweaks integration in mqlaunch
- Unified terminal guide path references

### Fixed
- Prevented menu exits on self-check, bundle, and notes
- Fixed zsh reserved variable issue with `status`
- Excluded local bundles and backup launcher files from version control

## [0.1.0] - 2026-04-10

### Added
- Modular `mqlaunch-v1` structure
- Performance module with:
  - overview
  - health score
  - CPU / memory views
  - disk usage
  - network overview
  - battery status
  - performance snapshots
  - quick watch
- Dev module with:
  - repo health
  - git status / pull / push
  - commit history
  - branch overview
  - repo navigation
- Tools module with:
  - tools root navigation
  - scripts / CLI access
  - terminal guide access
  - tools tree
  - README discovery
- Bridge layer from legacy launcher to v1 modules
- Smoke tests for legacy + v1 launcher flow
- Install-time self-check integration
- README demo section and GIF support

### Changed
- Main menu updated with WORKFLOWS section
- Legacy TOOLS section renamed to QUICK ACTIONS
- Shared v1 UI helpers consolidated in `terminal/mqlaunch-v1/lib/ui.sh`

### Notes
- Legacy launcher still exists as compatibility layer
- v1 modules are now the preferred path for core workflows
