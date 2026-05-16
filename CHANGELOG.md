# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

## [0.3.5] - 2026-05-16

### Added

- Added `mqlaunch hal timeline` bridge command.
- Documented HAL Timeline UI in README and command reference.

## [0.3.4] - 2026-05-16

### Added

- Added `mqlaunch hal session`, `mqlaunch hal last`, `mqlaunch hal remember`, and `mqlaunch hal memory-path` bridge commands.
- Added HAL Session Memory section to README and command reference.

## [0.3.3] - 2026-05-16

### Added

- Added `mqlaunch hal fix-doctor` bridge command for HAL Fix Planner.
- Documented HAL Fix Planner in README and command reference.

## [0.3.2] - 2026-05-16

### Added

- Added `mqlaunch hal doctor` — delegates to `mq-hal doctor-summary` for local doctor JSON summaries and safe next-step recommendations.
- Added HAL Doctor Summary docs to README and `docs/COMMANDS.md`.

## [0.3.1] - 2026-05-16

### Added

- Added `mqlaunch hal` bridge — local Ollama-powered safe command router via [mq-hal](https://github.com/MCamner/mq-hal).
- Added `hal)` route in `dispatch_cli_command` and `run_arg_command`.
- Added `terminal/bridges/hal-bridge.sh` with `mq_hal_run()`.
- Added HAL bridge docs to README and `docs/COMMANDS.md`.

### Fixed

- Fixed `mqlaunch hal` routing — `dispatch_cli_command` catch-all was intercepting `hal` before `run_arg_command` could handle it.
- Removed stale `hal` alias from `apps|hal|guide-ai` case; old terminal guide still reachable via `guide-ai`.

## [0.3.0] - 2026-05-16

### Fixed

- Fixed `mqlaunch doctor --json` arg passthrough — `dispatch_cli_command` was calling `doctor.sh` without forwarding flags, silently dropping `--json` and returning ANSI output instead of JSON.
- Fixed `doctor --json` summary counts — subshell `$(...)` calls lost counter updates; replaced with in-process string accumulation.
- Fixed `read_menu_choice` prompt rendering — `vared` (ZSH ZLE) was clearing below-cursor content on init, erasing bottom separator and hint. Replaced with plain `read`.
- Fixed `read-only variable: status` ZSH error in release menu — renamed conflicting locals to `files_status` / `exit_code`.
- Fixed mq-help-menu.sh function name collisions — guarded standalone `print_header`/`print_footer`/`row` etc. so they only activate outside mqlaunch context.
- Fixed `x` and `exit` not working as back/quit in all 13 submenus.

### Added

- Added `doctor --json` full output: `project`, `version`, `status`, `checks[]`, `summary{}` per spec.
- Added `docs/COMMANDS.md` — complete command reference for all mqlaunch commands, menus, env vars, and exit shortcuts.
- Added `x` / `exit` as back shortcut in all submenu prompts.
- Added prompt hint text: `>> option, mqlaunch command, shell command, or x to exit`.
- Added VERIFY section to Tools menu (doctor, doctor --json, selftest, smoke test).

## [0.2.4] - 2026-05-15

### Fixed

- Fixed Document Functions submenu prompt missing separator lines — pre-draws full separator block before input using cursor repositioning, matching all other menu prompts.
- Fixed subprocess menus (git, release, themes, shortcuts, login) converted to in-process sourced modules — eliminates exiting mqlaunch on return.
- Removed stale Git Menu option from dev menu and renumbered options 10–14.

### Added

- Added submenu prompt separator template to `.claude/templates/` for future reference.
- Updated `tools/scripts/README.md` with status table entries for brew-check, port-scan, focus, env-snap, and cleanup scripts.

## [0.2.3] - 2026-05-12

### Added

- Added `mq-repo-signal-check.sh` — wrapper that runs `repo-signal publish-checklist . --fail-under 14` as a release gate.
- Added repo-signal check to `mq-release-check.sh` — blocks release if publish checklist score is below threshold.
- Added option 12 (Repo Signal Check) to `mqlaunch` release menu.
- Added `MQ_REPO_SIGNAL_FAIL_UNDER` env var to configure publish checklist threshold without hardcoding.
- Added `ROADMAP.md`, `.github/ISSUE_TEMPLATE/bug_report.md`, and security note to README so `macos-scripts` scores 16/16.

## [0.2.2] - 2026-05-10

### Changed

* update shell scripts
* add: auto-update wiki Command-Reference on release
* add: wiki Command-Reference generator
* update shell scripts
* update shell scripts
* update shell scripts
* fix: separator lines match panel width and use white color
* fix: match prompt separator width to actual panel width
* refactor: extract themes menu to separate script
* fix: themes menu header matches tools menu — dashboard then panel
* fix: use clear_screen instead of print_header in themes menu
* fix: remove duplicate host row and add themes label in themes menu prompt
* fix: consistent surface style for themes menu, rename option 7
* fix: remove redundant push in auto_release (release.sh already pushes)
* feat: add Auto comment option to Document Functions menu
* update project files
* update project files
* update project files
* update shell scripts
* update project files
* update project files
* update shell scripts
* update project files
* update project files
* update shell scripts
* update project files
* update project files
* update project files
* update project files

---

## [0.2.0] - 2026-05-06

### Changed

* Improve demo mode — pause_enter between steps, add AI and release commands
* Fix all 16 markdownlint errors in README.md
* Update README — add AI/Atlas/nickname/release sections, fix lint
* gitlaunch: replace 9. EXIT with b. BACK
* Git menu: remove option 9 (git log), b/9 both map to Back
* Auto-generate changelog section from git commits before dry run
* update documentation
* Prompt to open CHANGELOG before dry run if version section is missing
* Add nickname support — shown in header, set via mqlaunch nickname-set
* Intercept atlas at entry point before dispatch reaches ai-mode.sh
* Fix atlas routing — source ai-prompts directly in mqlaunch.sh
* Add Atlas REPL — interactive AI session with mq atlas
* Add git push --tags between live release and GitHub release in auto_release
* Add Auto Release (option 11) to release menu
* Fix ask usage hint to English on main menu
* Add mqlaunch chat — conversational AI mode with memory
* Show ask usage hint on main menu start page
* Add AI section to command index and help text
* Use read_main_choice in help menu for consistent prompt style
* Add pause_enter after ask in REPL so answer stays visible
* Fix ask routing in REPL — zsh no-split bug
* Fix ask.sh truncating multiline responses
* update shell scripts
* update shell scripts
* Fix cmd variable name in unknown command fallback
* update project files
* Route unknown commands to /ask in command-mode layer
* Improve mqlaunch ask UX and fallback
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts

---

## [0.1.8] - 2026-05-05

### Added

* Slash commands `/doctor`, `/scan`, `/atlas`, `/release-check` wired into main menu dispatch
* `pause_enter` after slash command output so menu does not redraw before user reads result
* gitlaunch prompt with separator lines and direct 1-9 key input (no arrow keys)
* Missing helper functions (`print_section`, `pass`, `fail`, `warn`) in release check script

### Changed

* Slash command dispatch no longer falls through to shell runner on recognized commands
* `/ask` now passes question text through to `mq_ai_prompt_ask`
* Prompt separator width pinned to same value used when drawing the box above it
* Added breathing room (blank rows) around Command Surface figures
* `release-check` displayed as `/release-check` in main menu for consistency
* `check_changelog_matches_commits` now runs before "Status: release-check complete" line

### Fixed

* `/ui`, `/doctor` and other slash commands doing nothing when typed in main menu
* `/atlas` routing to `safe_run_ai atlas` instead of missing `atlas.sh`
* `mq_ai_prompt_review` and `mq_ai_prompt_ui` falling through to shell on missing helper

---

## [0.1.7] - 2026-04-29

### Added

* AI skill prompt commands (`/review`, `/ui`, `/ask`) in mqlaunch main menu
* Release check command (`/release-check`) integrated into mqlaunch
* Repo question prompt command (`/ask`)
* Doctor checks improved and integrated into release check

### Changed

* Document release check workflow
* Show new commands in main menu panel

---

## [0.1.6] - 2026-04-23

### Added

* Add changelog template initialization for new releases

### Changed

* Improve release workflow validation
* Refine release script behavior for smoother version preparation

### Fixed

* Prevent release attempts from proceeding without a matching changelog entry

---

## [0.1.5] - 2026-04-22

### Changed

* Fix release dry-run flow
* Update shell scripts and wrapper behavior
* Refine release process for consistent versioning

---

## [0.1.4] - 2026-04-13

### Changed

* Clarify README structure
* Improve repo presentation
* Strengthen quick start and demo flow

---

## [0.1.3] - 2026-04-11

### Changed

* Improve release script with dry-run support and rollback handling
* Enhance release workflow safety and validation

---

## [0.1.2] - 2026-04-11

### Added

* Initial release automation script (`tools/release.sh`)

### Changed

* Improve version badge handling in README
* Refine release preparation workflow

---

## [0.1.1] - 2026-04-11

### Added

* About and status dashboard in `mqlaunch`
* Release notes and changelog command

### Changed

* Align README, help, command index, and menu labels

---

## [0.1.0] - Initial release

### Added

* Base structure for macos-scripts
* Initial mqlaunch functionality
* Core terminal workflows
