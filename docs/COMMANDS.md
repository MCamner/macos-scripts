# mqlaunch — Command Reference

Complete command listing for `mqlaunch`. Run `mqlaunch help` for a quick index.

---

## Start

```bash
mqlaunch                    # open interactive menu
mqlaunch help               # command index (terminal)
mqlaunch commands           # same as help
mqlaunch demo               # guided interactive demo
mqlaunch palette            # fuzzy command search (fzf)
```

---

## Menus

```bash
mqlaunch system             # System menu
mqlaunch perf               # Performance menu
mqlaunch dev                # Dev menu
mqlaunch git                # Git menu
mqlaunch tools              # Tools menu
mqlaunch workflows          # Workflows menu
mqlaunch release            # Release menu
mqlaunch login              # Login / session menu
mqlaunch shortcuts          # macOS Shortcuts menu
mqlaunch theme              # Themes menu
```

---

## Workflows

```bash
mqlaunch workflows boot             # run project boot
mqlaunch workflows check            # run project check
mqlaunch workflows save             # save workspace snapshot
mqlaunch workflows restore          # restore workspace snapshot
```

---

## Session / login

```bash
mqlaunch login menu                 # session boot + full menu
mqlaunch login about                # session boot + about screen
mqlaunch login check                # session boot + self-check
```

---

## Shortcuts

```bash
mqlaunch shortcuts list             # list all shortcuts
mqlaunch shortcuts search <query>   # search shortcuts by name
mqlaunch shortcuts run <name>       # run a shortcut
mqlaunch shortcuts folders          # list shortcut folders
```

---

## Git

```bash
mqlaunch git                        # open git menu
```

Supported actions inside the menu: status, diff risk, commit suggestion,
safe push, pull with rebase, open on GitHub, change repo path.

---

## Release

```bash
mqlaunch release                    # open release menu
mqlaunch release-check              # run release readiness check
MQ_REPO_SIGNAL_FAIL_UNDER=16 mqlaunch release-check   # custom threshold
```

Auto Release flow (option 11 inside the menu):
1. Working tree check (commit or stash)
2. Changelog auto-generation from commits
3. Dry run
4. Live release (VERSION bump, tag, push)
5. GitHub release

---

## Doctor / health

```bash
mqlaunch doctor                     # interactive environment check
mqlaunch doctor --json              # machine-readable JSON report
mqlaunch selftest                   # smoke tests + shell lint
mqlaunch check                      # alias for selftest
```

JSON output shape:

```json
{
  "project": "macos-scripts",
  "version": "0.3.0",
  "status": "ok",
  "checks": [
    { "name": "git", "status": "ok" }
  ],
  "summary": { "ok": 8, "warn": 0, "fail": 0 }
}
```

Verify:

```bash
mqlaunch doctor --json | jq -e '.summary.fail == 0'
```

---

## AI assistant

```bash
mqlaunch ask "your question"                    # repo-aware AI answer
mqlaunch ask quick "your question"             # short answer, no context
mqlaunch atlas                                  # interactive AI REPL session
mqlaunch fix "error or task description"       # get copy-paste shell commands
mqlaunch review                                 # copy code review prompt to clipboard
mqlaunch ui                                     # copy UI prompt to clipboard
```

### Semantic Repository Memory (SRM)

```bash
mqlaunch srm inspect                                             # show indexed store info
mqlaunch srm ask "what repo is indexed here?"                   # query the store
SRM_VECTOR_STORE_ID=vs_xxx mqlaunch srm search "upload flow"   # query a specific store
```

---

## Security & ops

```bash
mqlaunch ghost          # network cloaking (MAC/DNS spoof)
mqlaunch pulse          # network latency + WiFi diagnostic
mqlaunch scan           # system + port scan
mqlaunch reap           # CPU/MEM process reaper
mqlaunch guard          # USB/Power perimeter watchdog
mqlaunch mc             # advanced system dashboard
```

---

## System

```bash
mqlaunch system                     # open System menu
mqlaunch system check               # system health check
mqlaunch system time                # show date and time
```

---

## Info

```bash
mqlaunch version                    # show version
mqlaunch about                      # about / status dashboard
mqlaunch notes                      # show CHANGELOG
mqlaunch repo                       # open repo root in Finder
mqlaunch guide                      # open terminal guide
```

---

## Utility

```bash
mqlaunch nickname-set "name"        # set name shown in menu headers
mqlaunch theme                      # open Themes menu
mqlaunch theme-macos                # apply macOS theme
mqlaunch theme-reset                # reset to default theme
mqlaunch bundle                     # create debug/support bundle
```

---

## Environment variables

| Variable | Purpose |
|---|---|
| `MACOS_SCRIPTS_HOME` | Override repo root (default: `~/macos-scripts`) |
| `MQ_RELEASE_REPO` | Default repo for release menu |
| `MQ_GIT_REPO` | Default repo for git menu |
| `MQ_REPO_SIGNAL_FAIL_UNDER` | Release gate threshold (default: 14) |
| `MQ_USE_DASHBOARD_HEADER` | Set to `1` to use dashboard header |
| `OPENAI_API_KEY` | Required for AI commands |
| `MQ_REPO_VECTOR_STORE_ID` | Vector store for `mqlaunch ask` |
| `SRM_VECTOR_STORE_ID` | Vector store for `mqlaunch srm` |

---

## Exit shortcuts

In any submenu prompt, type:

- `b` or `x` or `exit` — go back / exit the submenu
- A number — select that menu option
- A mqlaunch command — run it directly (e.g. `doctor`)

---

## HAL Command Surface

Full HAL bridge/menu reference:

```text
docs/hal-command-surface.md
```

Includes command groups, backend mapping, safety model, and release checklist.

---

## HAL Gallery

Visual HAL menu reference:

```text
docs/hal-gallery.md
docs/hal-menu-preview.txt
```

Includes the grouped HAL menu layout, command groups, and layout contract.

---

## HAL Pages

Visual HAL overview page:

```text
docs/hal.html
docs/screenshots/hal-menu.png
```

Shows the grouped HAL command surface for GitHub Pages, including a rendered HAL menu screenshot.

---

## HAL bridge

### HAL Menu

```bash
mqlaunch hal
```

Opens the interactive MQ HAL menu.

The menu is a thin command surface over `mq-hal`. It does not contain HAL logic.

Menu actions include:

```bash
mqlaunch hal doctor
mqlaunch hal fix-doctor
mqlaunch hal timeline
mqlaunch hal session
mqlaunch hal last
mqlaunch hal remember "note"
mqlaunch hal repos
```

### HAL Audit

```bash
mqlaunch hal audit
mqlaunch hal audit --json
mqlaunch hal audit --repo macos-scripts
```

Publish quality and README quality audit powered by `mq-hal` and `repo-signal`. Runs `repo-signal publish-checklist` and `repo-signal readme-score`, derives overall status (`ready` / `needs_review` / `not_ready`), and prints actionable recommendations. Requires `repo-signal` installed; falls back gracefully if unavailable.

### HAL Release Brief

```bash
mqlaunch hal release-brief
mqlaunch hal release-brief --json
mqlaunch hal release-brief --repo macos-scripts
mqlaunch hal release-brief --skip-gh
mqlaunch hal release-brief --skip-doctor
mqlaunch hal release-brief --skip-release-check
```

Read-only release readiness brief powered by `mq-hal`. Checks VERSION, CHANGELOG, README version reference, git state, CI status, latest GitHub release, doctor summary, and release-check.

### HAL Repo Status

```bash
mqlaunch hal repo-status
mqlaunch hal repo-status --json
mqlaunch hal repo-status --repo macos-scripts
```

Shows read-only git repository status: branch, dirty/clean state, changed file preview, recent commits, and latest tags. Delegates to `mq-hal repo-status`.

### HAL CI Status

```bash
mqlaunch hal ci
mqlaunch hal ci --json
mqlaunch hal ci --repo macos-scripts
mqlaunch hal ci --limit 10
```

Shows read-only GitHub Actions CI status via `gh run list`. Reports overall green/red/running state and recent run details. Delegates to `mq-hal ci`.

### HAL Brief

```bash
mqlaunch hal brief
mqlaunch hal brief --json
mqlaunch hal brief --no-gh
mqlaunch hal brief --repo macos-scripts
```

Shows a compact repo status brief. Collects git state, GitHub Actions CI runs, latest release tag, and the last HAL Session Memory note. Fully deterministic — no Ollama required.

### HAL direct commands

```bash
mqlaunch hal "your request"
mqlaunch hal repos
mqlaunch hal raw "your request"
mqlaunch hal cd repo-signal
```

Local Ollama-powered safe command router via [mq-hal](https://github.com/MCamner/mq-hal).

The model returns a JSON intent. The `mq-hal` router maps that intent to
explicitly allowed actions: `git status`, `git log`, repo switching, and
selected `mqlaunch` subcommands.

| Subcommand | Description |
|---|---|
| `hal "prompt"` | Natural language → execute action |
| `hal repos` | List configured repos |
| `hal raw "prompt"` | Show raw JSON intent from model |
| `hal cd <repo>` | Print repo path (use with `mqhcd`) |

Requirements: `~/mq-hal/bin/mq-hal`, Ollama running, `qwen3:4b-instruct` pulled.
Override model: `OLLAMA_MODEL=qwen3:4b mqlaunch hal "..."`.

### HAL Doctor Summary

```bash
mqlaunch hal doctor
mqlaunch hal doctor --no-ai
mqlaunch hal doctor --json
```

Runs `mqlaunch doctor --json`, parses the result through `mq-hal`, and prints a concise health summary with safe next commands. Falls back to deterministic local analysis when Ollama is unavailable.

### HAL Fix Planner

```bash
mqlaunch hal fix-doctor
mqlaunch hal fix-doctor --no-ai
mqlaunch hal fix-doctor --json
```

Creates a safe, copy-paste fix plan from HAL Doctor Summary. Executes nothing — only prints recommended inspection and verification commands for manual review.

### HAL Session Memory

```bash
mqlaunch hal session
mqlaunch hal last
mqlaunch hal remember "release looked good"
mqlaunch hal memory-path
```

Shows and stores local HAL memory in `~/.mq-hal/session.jsonl`. Session Memory records doctor summaries, fix plans, and manual notes automatically. Stays local — nothing is sent externally.

### HAL Timeline UI

```bash
mqlaunch hal timeline
mqlaunch hal timeline --details
mqlaunch hal timeline --repo macos-scripts
mqlaunch hal timeline --type doctor_summary
mqlaunch hal timeline --json
```

Shows local HAL Session Memory as a compact terminal timeline table.
