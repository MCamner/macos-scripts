# mqlaunch Command Surface

Use the local `mqlaunch-command-surface` skill before changing mqlaunch
commands, menus, aliases, HAL routing, help text, or CLI/TUI command behavior.

Primary skill file:

```text
skills/mqlaunch-command-surface/SKILL.md
```

First read that file completely and follow its workflow.

Default inspection pass:

```bash
git status --short
sed -n '1,220p' skills/mqlaunch-command-surface/SKILL.md
sed -n '1,220p' docs/COMMANDS.md
sed -n '1,260p' terminal/launchers/mqlaunch-command-mode.sh
sed -n '1,220p' terminal/launchers/mqlaunch.sh
```

For menu work, inspect the relevant menu module under:

```text
terminal/menus/
```

Use these references for the current menu architecture:

```text
terminal/menus/mq-hal-menu.sh
ui/terminal-ui/mq-ui.sh
terminal/menus/README.md
terminal/launchers/README.md
```

Core rules:

* Keep direct CLI commands and interactive menu routes consistent.
* Keep user-facing commands discoverable from help, docs, or menus.
* Use the existing `surface_*` terminal UI helpers for new menu panels.
* Keep business logic in tools, bridges, or command handlers; menus should route and present.
* Update docs and smoke tests when command behavior changes.

Preferred checks, scoped to the files changed:

```bash
bash -n terminal/launchers/mqlaunch-command-mode.sh
bash -n terminal/launchers/mqlaunch.sh
bash -n terminal/menus/<changed-menu>.sh
./tests/hal-command-surface-smoke.sh
./tests/hal-menu-smoke.sh
./tests/hal-menu-layout-smoke.sh
```

User request:

```text
$ARGUMENTS
```

After inspecting, do the smallest grounded action that keeps mqlaunch coherent.
Report command/menu surfaces touched, docs updated, checks run, and anything left
unverified.
