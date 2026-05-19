# HAL Gallery

Visual reference for the `mqlaunch hal` command surface.

This page is documentation only. Runtime logic lives in `mq-hal`.

---

## HAL Menu Preview

```text
╔════════════════════════════════════════════════════════════╗
║ MQ HAL                                                     ║
║ Local command intelligence · Ollama · mq-hal · memory      ║
╚════════════════════════════════════════════════════════════╝

OBSERVE
────────────────────────────────────────────────────────────
  1) Brief                  2) Audit
  3) Release Brief          4) Repo Status
  5) CI Status              6) Doctor Summary
  7) Timeline               8) Timeline + details

PLAN
────────────────────────────────────────────────────────────
  9) Fix Doctor Plan

MEMORY
────────────────────────────────────────────────────────────
 10) Session Memory        11) Last Memory Item
 12) Remember Note

DEBUG
────────────────────────────────────────────────────────────
 13) Repos                 14) Raw Intent
 15) Free Prompt           16) Memory Path

  b) Back                  x) Exit launcher
```

---

## Command Groups

### Observe

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

```bash
mqlaunch hal fix-doctor
```

### Memory

```bash
mqlaunch hal session
mqlaunch hal last
mqlaunch hal remember "release looked good"
mqlaunch hal memory-path
```

### Debug

```bash
mqlaunch hal repos
mqlaunch hal raw "kor doctor"
mqlaunch hal cd macos-scripts
mqlaunch hal "visa git status"
```

---

## Layout Contract

The menu must keep the MQLaunch surface layout:

```text
surface_panel_header
surface_row
surface_split_row
surface_bottom
read_main_choice "hal"
```

Do not replace the menu with a custom standalone layout unless all MQLaunch menus are intentionally redesigned.

---

## Related Docs

* [HAL Command Surface](hal-command-surface.md)
* [Command Reference](COMMANDS.md)
