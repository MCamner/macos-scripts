# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

## [1.0.1] - 2026-07-16

### Added

* `mq_debug` — a diagnostic logger in `mq-ui.sh`, silent unless `MQ_DEBUG` is
  set, writing to stderr and always returning 0. Use it as `… || mq_debug "why"`
  to make an unexpected best-effort failure observable instead of swallowing it
  with `2>/dev/null || true`. Adopted at the git-screen `cd` guard and the
  Obsidian menu's optional-lib loader; broader adoption is incremental.
* `scripts/check-skills.sh` — validates skill frontmatter, cross-references,
  referenced paths, and the generated SKILLS.md table; wired into the Quality
  workflow. `--fix` regenerates the table.
* Evals sections (should/should-not trigger) in every skill.

### Changed

* ROADMAP now tracks the `mqobsidian` v0.1.0 single-source-of-truth foundation
  as an upstream dependency, while keeping `mqlaunch` read-only or
  delegate-only for truth, inbox, ranking, and promotion surfaces.
* Documented the canonical mqobsidian view-manifest keys consumed by `mqlaunch`
  and marked that roadmap deliverable done.
* Added a smoke test that locks the MQ Obsidian menu out of memory promotion or
  rejection routes, preserving the review-gated ownership boundary.
* Verified the review command delegation boundary through
  `tests/mq-agent-routing-smoke.sh` and marked the roadmap item done.
* Added direct `mqlaunch obsidian status`, `mqlaunch obsidian inbox`, and
  `mqlaunch obsidian views` routes for read-only mqobsidian status/navigation.
* Added `mqlaunch obsidian promote` as a thin delegate to
  `mq-agent obsidian promote`, keeping scoring and memory writes out of
  mqlaunch.
* Added a release-check gate for the local mqobsidian view-manifest consumer
  contract, blocking malformed or drifted `views.json` before release.
* Added delegate-only `mqlaunch stack status` / `mqlaunch stack ...` routing to
  `mq-agent stack`, keeping canonical truth parsing outside mqlaunch.
* Monolith de-layering (Step 11a): five concerns moved verbatim out of
  `terminal/launchers/mqlaunch.sh` into dedicated libraries sourced back into
  the launcher's scope — the network concern (status/diagnostics/connectivity,
  17 functions → `mqlaunch/lib/network.sh`), the fzf interactive pickers
  (git log/branch, kill process/port, run snippet, recent files, 6 functions →
  `mqlaunch/lib/fzf-pickers.sh`), diagnostics (version reporting, self-check,
  debug bundle, release notes, plus the system check, 6 functions →
  `mqlaunch/lib/diagnostics.sh`), the git & release menu launchers
  (2 functions → `mqlaunch/lib/git-menus.sh`), and the GitHub repo picker
  (1 function → `mqlaunch/lib/repo-picker.sh`). No behavior change; the launcher
  drops ~720 lines and each concern now has a named owner. Guarded by
  `tests/monolith-delayer-smoke.sh`, a table-driven check that fails if any
  extracted function is redefined in the monolith or a lib source is dropped.
* `print_header` now has a single owner: `ui/terminal-ui/mq-ui.sh`. The launcher
  no longer overrides it; instead it opts the main loop into the dashboard-v7.1
  header via `MQ_USE_DASHBOARD_HEADER=1`. **Behavior change:** the main-loop
  header now renders through mq-ui's *cached* dashboard path (bounded by
  `MQ_DASHBOARD_CACHE_TTL`, default 5s, and invalidated by the git/release
  flows) instead of re-forking the dashboard script uncached on every screen.
  This removes a hidden fork in render behavior and aligns the main loop with
  the cache and invalidation model the rest of the runtime already used; it also
  avoids a dashboard re-fork per screen render. Escape hatch: set
  `MQ_DASHBOARD_CACHE_TTL=0` for an uncached, per-screen header while
  investigating. The dead `DASHBOARD_V71` launcher variable (only the removed
  override used it) is gone.
* `semantic-memory-maintainer` renamed to `vector-store-maintainer` to avoid
  routing collision with mq-mcp's skill of the same name.
* `command-template-library` skill moved to mq-ums, where the contracts and
  generator it documents live.
* The mqlaunch menu/GUI construction standard now has a single owner
  (`mqlaunch-command-surface`); `terminal-ui-polisher` references it instead of
  duplicating it. Stack surfaces (agent menu 17–18, `mq b2 stack`) documented.
* `release-readiness` rebuilt around `mqlaunch release-check`, the stack
  contract gate, and smoke tests. `docs-maintainer` no longer routes to the
  non-existent `repo-product-auditor`.

### Fixed

* The HAL command surface (`hal …` in the REPL and main menu) no longer runs
  user input through `eval`. Requests are tokenized into argv with `read -ra`,
  so `*`, `;`, `|`, and `$(…)` in a request stay literal instead of being
  expanded or executed. Behavior change: a quoted multi-word argument
  (`hal remember "buy milk"`) is now split on whitespace rather than kept
  together by the shell — quote it at the HAL level if grouping is needed.

### Removed

* Dead `run_git_screen` in `terminal/launchers/mqlaunch.sh` — it had no live
  caller in the launcher graph (the live copy lives in
  `tools/scripts/mqlaunch_desktop.sh`). Surfaced while de-layering the git
  concern (Step 11a); removed as a standalone cleanup rather than folded into a
  refactor.

## [1.0.0] - 2026-06-10

### Added

* **B2 Stack Cockpit** (`mq b2 stack`) — aggregated dashboard: repo health,
  B2 prompts, roadmap drift, last run, validation health, Obsidian sync status.
* **v0.7.0 mq-agent bridge** — `mq b2 review-last`, `--review` on compose,
  `route --compose --review` full pipeline. Thin subprocess bridge to mq-agent.
* **v0.8.0 review contract** — `review_contract.py`: capture `--json` from
  mq-agent, B2-style severity rendering, BLOCKER exit gate. `--risk` flag added.
* **v0.9.0 repo-signal integration** — `mq b2 repo-status`, `--export`,
  `mq b2 roadmap-drift`, repo health warning in route pipeline.
* 89 passing tests total across b2_tui test suite.

## [0.6.0] - 2026-06-09

### Added

* **B2 Atlas Prompt OS TUI** — full terminal interface for structured prompt
  work (`mq b2`). Phases 0–12 complete: CLI commands (list, show, compose, run,
  route, validate, config, history, export-last, open-last), textual TUI with
  two-panel browser + preview pane, rule-based task router, Obsidian run writer,
  JSONL history, 40 passing tests. Accessible via Dev menu → `a`.
* Added `docs/B2_TUI.md` — full B2 TUI reference.
* Added `mq b2` section to `docs/COMMANDS.md`.

### Changed

* Polished the Dev menu with clearer groups and safer script fallbacks.
* Bumped version to 0.6.0 — B2 Atlas Prompt OS TUI MVP.

## [0.5.1] - 2026-06-03

### Added

* Added `mqlaunch workflows validate` for workflow command-surface health checks.
* Added workflow validation to `mqlaunch release-check`.
* Added `document-functions.sh --quality` to flag generic function comments.
* Added a Document Functions menu entry for comment quality checks.

### Changed

* Synced README, ROADMAP and release metadata for `0.5.1`.
* Tightened the Ollama document-review prompt to return fewer, higher-signal
  comment suggestions without full diffs by default.

## [0.5.0] - 2026-06-02

### Added

* Added mq-agent review, risk-review, architecture, repo-health and mcp-status routing from mqlaunch.
* Added MQ ecosystem repo status, roadmap, skills and diff-summary commands.
* Added command-template-library skill.

### Changed

* Improved README onboarding with requirements, usage examples, docs map, roadmap context and contribution guidance.
* Updated Git menu AI COMMIT flow so it returns to the Git menu instead of the start menu.
* Preserved mq-agent bridge loading when running mq-mcp review from the Tools menu.

### Fixed

* Fixed protected-branch push handling by routing main/master pushes through PR branches.
* Fixed auto comment flow so existing comments are preserved.
* Fixed mq-agent bridge loading in `run_mq_mcp_review`.

## [0.4.12] - 2026-05-23

### Added

* `.github/workflows/quality.yml` — CI shell syntax check: `bash -n` on `install.sh`, `release.sh`, and all `.sh` files; `shellcheck` (warn-only).
* `scripts/install-smoke.sh` — local install smoke test covering `install.sh --dry-run`, `release.sh` syntax, all `.sh` bash -n, `mqlaunch doctor --json`, and `mqlaunch selftest`.
* `terminal/menus/mq-agent-menu.sh` — mq-agent submenu with ten commands across repo analysis, AI, and environment groups.
* `Proof` section in README listing what is verified: dry-run, release validation, JSON health report, selftest, publish gate, HAL read-only commands, and CI syntax coverage.

### Changed

* README version badge bumped to `0.4.12`.
* Main menu panel: added `g. Agent` quick access slot.
* `mqlaunch.sh`: sources `mq-agent-menu.sh` when present.
* `mq-main-menu.sh`: routes `g`/`G` and text aliases (`agent`, `score`, `signal`, `audit`, `doctor`) to mq-agent menu.

## [0.4.11] - 2026-05-20

### Changed

* Reworked `docs/index.html` into a clearer GitHub Pages project front door.
* Added a visible Install, Run, Explore flow for first-time users.
* Added a screenshots section covering HAL, main menu, performance, and release workflows.
* Added a docs map linking the case study, HAL page, command reference, and terminal guide.
* Updated the GitHub Pages sitemap for the refreshed front door and HAL page.

### Added

* Added Pages index smoke test coverage.

## [0.4.10] - 2026-05-20

### Added

* Added `docs/screenshots/hal-menu.png` as a rendered HAL menu screenshot.
* Added the HAL screenshot to `docs/hal.html`.
* Added a stronger HAL preview card on the GitHub Pages index.
* Added HAL screenshot smoke test coverage.

## [0.4.9] - 2026-05-19

### Added

* Added `docs/hal.html` as a GitHub Pages overview for the MQLaunch HAL command surface.
* Linked the HAL overview from existing Pages docs.
* Added HAL Pages smoke test.
* Linked HAL overview from README and command reference.

## [0.4.8] - 2026-05-19

### Added

* Added `docs/hal-gallery.md` as a visual reference for the MQLaunch HAL menu.
* Added `docs/hal-menu-preview.txt` with a plain text menu preview.
* Added HAL gallery smoke test.
* Linked HAL gallery docs from README and command reference.

## [0.4.7] - 2026-05-19

### Added

* Added `docs/hal-command-surface.md` for the full MQLaunch HAL command surface.
* Added smoke test for HAL command surface documentation.
* Added HAL menu layout smoke test.
* Added HAL file formatting smoke test.
* Linked HAL command surface docs from README and command reference.

## [0.4.6] - 2026-05-18

### Added

* Added Ollama review as option 7 in the Document Functions menu.
* Added local review-only helper for comments, docstrings, and function descriptions.
* Added documentation for Ollama Document Review.

### Changed

* Aligned Ollama review default model with installed `qwen3:4b-instruct` tag.

### Safety

* Ollama review is review-only and does not modify files automatically.

### Fixed

* Fixed `mq-release-check.sh` opening ChatGPT browser when called non-interactively (e.g. from `mq-hal release-brief`). AI prompt calls (`mq_ai_prompt_review`, `mq_ai_prompt_ui`) are now guarded with `[[ -t 1 ]]` — skipped when stdout is not a TTY.

## [0.4.5] - 2026-05-17

### Fixed

* Fixed `mqlaunch hal release-brief` (and any `mqlaunch <cmd>` typed from inside the menu prompt) routing to AI — `dispatch_cli_command` now handles `area="mqlaunch"` by stripping the prefix and re-dispatching, so typing the full `mqlaunch hal <sub>` form inside the menu works the same as typing `hal <sub>`.

## [0.4.4] - 2026-05-17

### Fixed

* Restored `mq_hal_run()` alias in bridge — mqlaunch calls `mq_hal_run` but the function was renamed to `mq_hal_main` in a prior refactor, causing all `mqlaunch hal <command>` calls to route to AI instead of the bridge.

## [0.4.3] - 2026-05-17

### Fixed

* HAL menu restored to the correct mqlaunch surface pattern: `surface_panel_header`, `surface_split_row`, `surface_bottom`, and `read_main_choice "hal"`.
* Menu now renders identically to other mqlaunch submenus (panel box + pinned prompt).
* `_hal_pause_enter` helper added for standalone-safe pause.

## [0.4.2] - 2026-05-17

### Fixed

* HAL menu now uses `print_header` when called from within mqlaunch, matching the style of all other submenus. Falls back to a plain standalone header when run directly.

## [0.4.1] - 2026-05-17

### Changed

* Rewrote HAL menu as self-contained (`mq-hal-menu.sh` no longer depends on `surface_*`, `print_header`, or `read_main_choice`).
* Reordered OBSERVE: Audit is now item 2 (between Brief and Release Brief).
* Expanded `tests/hal-menu-smoke.sh` from 6 to 8 checks — now verifies audit and release-brief routes and menu labels.

## [0.4.0] - 2026-05-17

### Added

* Added `mqlaunch hal audit` bridge command (publish quality + README score via `repo-signal`).
* Added Audit as item 8 in HAL menu OBSERVE section (total 16 items).
* Documented HAL Audit in `docs/COMMANDS.md` and README quick-reference.

## [0.3.9] - 2026-05-17

### Added

* Added `mqlaunch hal release-brief` bridge command.
* Added `release-brief` to HAL bridge usage text.
* Updated HAL menu OBSERVE section: Release Brief is now item 2; total 15 items.
* Documented HAL Release Brief in `docs/COMMANDS.md`.
* Added `brief`, `release-brief`, `repo-status`, and `ci` to README quick-reference.

## [0.3.8] - 2026-05-17

### Added

* Added `mqlaunch hal repo-status` bridge command.
* Added `mqlaunch hal ci` bridge command.
* Updated HAL menu OBSERVE section: added Repo Status (2) and CI Status (3); items renumbered to 14.
* Documented HAL Repo Status and CI Status in `docs/COMMANDS.md`.

## [0.3.7] - 2026-05-17

### Added

* Added `mqlaunch hal brief` bridge command.
* Rewrote HAL bridge (`hal-bridge.sh`) with `mq_hal_main` entry point, robust help text, and cleaner subcommand routing.
* Rewrote HAL menu (`mq-hal-menu.sh`) as a standalone grouped menu (Observe, Plan, Memory, Debug) with box-drawn prompts; no `surface_*` dependency.
* Updated smoke test (`tests/hal-menu-smoke.sh`) to 5 checks including brief coverage.
* Added HAL Brief section to `docs/COMMANDS.md`.

## [0.3.6] - 2026-05-16

### Added

* Added interactive `mqlaunch hal` menu (`terminal/menus/mq-hal-menu.sh`).
* Added HAL menu smoke test (`tests/hal-menu-smoke.sh`).
* Documented HAL menu in README and `docs/COMMANDS.md`.

## [0.3.5] - 2026-05-16

### Added

* Added `mqlaunch hal timeline` bridge command.
* Documented HAL Timeline UI in README and command reference.

## [0.3.4] - 2026-05-16

### Added

* Added `mqlaunch hal session`, `mqlaunch hal last`, `mqlaunch hal remember`, and `mqlaunch hal memory-path` bridge commands.
* Added HAL Session Memory section to README and command reference.

## [0.3.3] - 2026-05-16

### Added

* Added `mqlaunch hal fix-doctor` bridge command for HAL Fix Planner.
* Documented HAL Fix Planner in README and command reference.

## [0.3.2] - 2026-05-16

### Added

* Added `mqlaunch hal doctor` — delegates to `mq-hal doctor-summary` for local doctor JSON summaries and safe next-step recommendations.
* Added HAL Doctor Summary docs to README and `docs/COMMANDS.md`.

## [0.3.1] - 2026-05-16

### Added

* Added `mqlaunch hal` bridge — local Ollama-powered safe command router via [mq-hal](https://github.com/MCamner/mq-hal).
* Added `hal)` route in `dispatch_cli_command` and `run_arg_command`.
* Added `terminal/bridges/hal-bridge.sh` with `mq_hal_run()`.
* Added HAL bridge docs to README and `docs/COMMANDS.md`.

### Fixed

* Fixed `mqlaunch hal` routing — `dispatch_cli_command` catch-all was intercepting `hal` before `run_arg_command` could handle it.
* Removed stale `hal` alias from `apps|hal|guide-ai` case; old terminal guide still reachable via `guide-ai`.

## [0.3.0] - 2026-05-16

### Fixed

* Fixed `mqlaunch doctor --json` arg passthrough — `dispatch_cli_command` was calling `doctor.sh` without forwarding flags, silently dropping `--json` and returning ANSI output instead of JSON.
* Fixed `doctor --json` summary counts — subshell `$(...)` calls lost counter updates; replaced with in-process string accumulation.
* Fixed `read_menu_choice` prompt rendering — `vared` (ZSH ZLE) was clearing below-cursor content on init, erasing bottom separator and hint. Replaced with plain `read`.
* Fixed `read-only variable: status` ZSH error in release menu — renamed conflicting locals to `files_status` / `exit_code`.
* Fixed mq-help-menu.sh function name collisions — guarded standalone `print_header`/`print_footer`/`row` etc. so they only activate outside mqlaunch context.
* Fixed `x` and `exit` not working as back/quit in all 13 submenus.

### Added

* Added `doctor --json` full output: `project`, `version`, `status`, `checks[]`, `summary{}` per spec.
* Added `docs/COMMANDS.md` — complete command reference for all mqlaunch commands, menus, env vars, and exit shortcuts.
* Added `x` / `exit` as back shortcut in all submenu prompts.
* Added prompt hint text: `>> option, mqlaunch command, shell command, or x to exit`.
* Added VERIFY section to Tools menu (doctor, doctor --json, selftest, smoke test).

## [0.2.4] - 2026-05-15

### Fixed

* Fixed Document Functions submenu prompt missing separator lines — pre-draws full separator block before input using cursor repositioning, matching all other menu prompts.
* Fixed subprocess menus (git, release, themes, shortcuts, login) converted to in-process sourced modules — eliminates exiting mqlaunch on return.
* Removed stale Git Menu option from dev menu and renumbered options 10–14.

### Added

* Added submenu prompt separator template to `.claude/templates/` for future reference.
* Updated `tools/scripts/README.md` with status table entries for brew-check, port-scan, focus, env-snap, and cleanup scripts.

## [0.2.3] - 2026-05-12

### Added

* Added `mq-repo-signal-check.sh` — wrapper that runs `repo-signal publish-checklist . --fail-under 14` as a release gate.
* Added repo-signal check to `mq-release-check.sh` — blocks release if publish checklist score is below threshold.
* Added option 12 (Repo Signal Check) to `mqlaunch` release menu.
* Added `MQ_REPO_SIGNAL_FAIL_UNDER` env var to configure publish checklist threshold without hardcoding.
* Added `ROADMAP.md`, `.github/ISSUE_TEMPLATE/bug_report.md`, and security note to README so `macos-scripts` scores 16/16.

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
