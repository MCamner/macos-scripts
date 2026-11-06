# HAL Gallery

Visual reference for the `mqlaunch hal` command surface.

This page is documentation only. Runtime logic lives in `mq-hal`.

---

## HAL Menu Preview

Rendered from `render_hal_panel` in `terminal/menus/mq-hal-menu.sh`.
`tests/hal-gallery-smoke.sh` fails if this block drifts from the menu.

```text
┌─ MQ HAL ─────────────────────────────────────────────────────────────────────────────────┐
│ Mode: HAL   Git: Clean                                                                   │
│                                                                                          │
│ OBSERVE                                                                                  │
│ 1. Brief                                     2. Repo status                              │
│ 3. Release readiness                         4. CI status                                │
│                                                                                          │
│ INTELLIGENCE                                                                             │
│ 5. Intelligence                                                                          │
│                                                                                          │
│ HEALTH                                                                                   │
│ 6. Doctor                                    7. Fix plan                                 │
│                                                                                          │
│ MEMORY                                                                                   │
│ 8. Memory                                                                                │
│                                                                                          │
│ DEBUG / ADVANCED                                                                         │
│ 9. Diagnostics                               10. Prompt                                  │
│                                                                                          │
│ b. Back                                      x. Exit launcher                            │
│ Shell needs an explicit prefix:  ! ls -la                                                │
└──────────────────────────────────────────────────────────────────────────────────────────┘
hal>
```

Type `a` in the menu for the quality audit and `h` for help.

---

## Command Groups

Grouped as in the menu. Submenu choices are listed in the order they appear.

### Observe

```bash
mqlaunch hal brief
mqlaunch hal repo-status
mqlaunch hal release-brief
mqlaunch hal ci
```

### Intelligence

Choice 5 opens a submenu: routing, provenance, cloud code plan, compatibility.
Cloud code plan sends the repo and goal to OpenAI.

```bash
mqlaunch hal route
mqlaunch hal provenance
mqlaunch hal compatibility
mqlaunch hal code-plan --provider openai --repo macos-scripts "add a dry-run flag"
```

### Health

```bash
mqlaunch hal doctor
mqlaunch hal fix-doctor
```

`fix-doctor` prints suggested commands. It does not run them.

### Memory

```bash
mqlaunch hal session
mqlaunch hal last
mqlaunch hal remember "release looked good"
mqlaunch hal memory-path
```

### Debug / Advanced

Diagnostics (choice 9) and Prompt (choice 10) are submenus.

```bash
mqlaunch hal timeline
mqlaunch hal timeline --details
mqlaunch hal context
mqlaunch hal audit
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
