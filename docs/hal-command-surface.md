# MQLaunch HAL Command Surface

This document describes the `mqlaunch hal` command surface.

`mqlaunch` owns the terminal UX.
`mq-hal` owns HAL logic.

The bridge lives here:

```text
terminal/bridges/hal-bridge.sh
```

The interactive HAL menu lives here:

```text
terminal/menus/mq-hal-menu.sh
```

---

## Core Rule

The HAL menu must preserve the MQLaunch surface layout.

Expected layout primitives:

```text
surface_panel_header
surface_row
surface_split_row
surface_bottom
read_main_choice "hal"
```

Do not replace the HAL menu with custom `printf` layout unless intentionally redesigning all MQLaunch menus.

---

## Command Groups

### Observe

Read-only status and quality commands.

```bash
mqlaunch hal brief
mqlaunch hal audit
mqlaunch hal release-brief
mqlaunch hal repo-status
mqlaunch hal ci
mqlaunch hal doctor
mqlaunch hal timeline
mqlaunch hal timeline --details
```

### Plan

Commands that produce safe next-step plans.

```bash
mqlaunch hal fix-doctor
```

### Memory

Commands that read or write local HAL memory.

```bash
mqlaunch hal session
mqlaunch hal last
mqlaunch hal remember "note"
mqlaunch hal memory-path
```

### Debug

Commands for routing/debugging.

```bash
mqlaunch hal repos
mqlaunch hal cd macos-scripts
mqlaunch hal raw "kor doctor"
mqlaunch hal "visa git status"
```

---

## Command Reference

| Command | Backend | Type | Purpose |
|---|---|---|---|
| `mqlaunch hal` | `mq-hal-menu.sh` | menu | Opens interactive HAL menu |
| `mqlaunch hal brief` | `mq-hal brief` | read-only | Compact repo status snapshot |
| `mqlaunch hal audit` | `mq-hal audit` | read-only | Publish/readme quality audit via repo-signal |
| `mqlaunch hal release-brief` | `mq-hal release-brief` | read-only | Release readiness summary |
| `mqlaunch hal repo-status` | `mq-hal repo-status` | read-only | Git repo status, commits, tags |
| `mqlaunch hal ci` | `mq-hal ci` | read-only | GitHub Actions status |
| `mqlaunch hal doctor` | `mq-hal doctor-summary` | read-only | Doctor summary |
| `mqlaunch hal fix-doctor` | `mq-hal fix-doctor` | planning | Safe manual fix plan |
| `mqlaunch hal timeline` | `mq-hal timeline` | read-only | Local HAL memory timeline |
| `mqlaunch hal session` | `mq-hal session` | read-only | Local HAL session memory |
| `mqlaunch hal last` | `mq-hal last` | read-only | Latest memory item |
| `mqlaunch hal remember "note"` | `mq-hal remember "note"` | memory-write | Saves local note |
| `mqlaunch hal repos` | `mq-hal --list-repos` | read-only | Lists configured repos |
| `mqlaunch hal cd <repo>` | `mq-hal --cd <repo>` | read-only | Prints repo path |
| `mqlaunch hal raw "prompt"` | `mq-hal --raw-intent "prompt"` | debug | Shows parsed JSON intent |
| `mqlaunch hal "prompt"` | `mq-hal "prompt"` | routed | Free HAL prompt |

---

## Safety Model

HAL commands should follow this rule:

```text
observe first
plan second
manual execution last
```

Allowed behavior:

```text
read status
summarize output
show recommendations
print safe commands
write local notes only when explicitly requested
```

Disallowed behavior:

```text
auto-delete
auto-reset
auto-commit
auto-push
auto-release
auto-submit
run arbitrary shell from model output
```

---

## Release Checklist

Before releasing HAL changes in `macos-scripts`:

```bash
bash -n terminal/bridges/hal-bridge.sh
bash -n terminal/menus/mq-hal-menu.sh
bash -n terminal/launchers/mqlaunch-command-mode.sh
zsh -n terminal/launchers/mqlaunch.sh

./tests/hal-menu-smoke.sh
./tests/hal-menu-layout-smoke.sh
./tests/hal-command-surface-smoke.sh

mqlaunch hal help
mqlaunch hal audit --sample
mqlaunch hal brief --sample
mqlaunch hal release-brief --sample
mqlaunch hal repo-status --sample
mqlaunch hal ci --sample

mqlaunch selftest
mqlaunch doctor --json | jq .
mqlaunch release-check
```

---

## Definition Of Done

A HAL bridge/menu change is complete when:

```text
bridge route exists
menu item exists if interactive
layout smoke test passes
command surface docs updated
README references command surface
COMMANDS.md references command surface
VERSION and CHANGELOG updated
CI is green
release notes exist
```
