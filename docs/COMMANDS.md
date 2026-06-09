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
mqlaunch workflows validate         # validate workflow files, docs and routing
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

AI commit and safe push avoid direct pushes to protected branches such as
`main` and `master`. When branch protection requires a pull request, mqlaunch
offers to create a `mq/...` PR branch and push that branch instead.

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
mqlaunch workflows validate         # workflow command-surface health check
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

## MQ ecosystem skills and repos

```bash
mqlaunch skills audit                 # list local skills, indexes and roadmap gaps
mqlaunch skills validate              # validate SKILL.md frontmatter and indexes
mqlaunch skills validate --ecosystem  # validate cross-repo skill uniqueness and roadmap hints
mqlaunch skills new my-skill --repo mq-mcp --description "Use when ..."
mqlaunch repos list                   # list known local MQ repos
mqlaunch repos status                 # show branch/upstream/origin/dirty state per repo
mqlaunch repos roadmaps               # list roadmap files per repo
mqlaunch repos skills                 # summarize skill counts per repo
mqlaunch repos diff-summary           # show git change summary per repo
mqlaunch repos diff-summary --modified    # show only modified/staged files
mqlaunch repos diff-summary --untracked   # show only untracked files
```

These commands are read-only except `skills new`, which creates a local
`skills/<name>/SKILL.md` scaffold in the requested repo.

---

## AI assistant

```bash
mqlaunch ask "your question"                    # repo-aware AI answer
mqlaunch ask quick "your question"             # short answer, no context
mqlaunch atlas                                  # interactive AI REPL session
mqlaunch fix "error or task description"       # get copy-paste shell commands
mqlaunch review                                 # review current diff via mq-agent -> mq-mcp
mqlaunch review file <path> security           # review one file in security mode
mqlaunch review repo architecture              # review repo in architecture mode
mqlaunch risk-review                            # risk review current diff via mq-agent
mqlaunch architecture                           # show mq-mcp architecture decisions
mqlaunch repo-health                            # repo-signal + orchestration contract health
mqlaunch mcp-status                             # mq-mcp status, tool count, contract health
mqlaunch ui                                     # copy UI prompt to clipboard
```

`mqlaunch` only delegates these review and architecture commands. Review
logic, severity labels, semantic memory, and risk routing stay in `mq-mcp`;
`mq-agent` is the orchestration layer between mqlaunch and mq-mcp.

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

* `b` or `x` or `exit` — go back / exit the submenu
* A number — select that menu option
* A mqlaunch command — run it directly (e.g. `doctor`)

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

---

## B2 Atlas Prompt OS

```bash
mq b2                   # open interactive TUI
mq b2 list              # list all prompts by category
mq b2 categories        # list categories with counts
mq b2 show 02.11        # show a single prompt
mq b2 compose 02.11 "design TUI architecture"
mq b2 run 02.11         # interactive compose
mq b2 route "bygga blueprint för nytt API"
mq b2 validate          # check all prompt files
mq b2 config            # show path configuration
mq b2 history           # show last 10 runs
mq b2 history last      # most recent run
mq b2 history export    # write history to Obsidian
mq b2 export-last       # path to last run file
mq b2 open-last         # open last run in editor
mq b2 review-last                       # review last run with mq-agent
mq b2 review-last --architecture        # architecture review mode
mq b2 review-last --security            # security review mode
mq b2 compose 02.11 "task" --review     # compose + review in one step
mq b2 route "ta fram blueprint" --compose               # route + compose (non-interactive)
mq b2 route "ta fram blueprint" --compose --review      # route + compose + review in one step
mq b2 route "ta fram blueprint" --compose --review --architecture
```

See [docs/B2_TUI.md](B2_TUI.md) for full reference.
