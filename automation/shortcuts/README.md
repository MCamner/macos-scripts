# MQShortcuts

`mqshortcuts.sh` is a fast terminal wrapper around the macOS `shortcuts` CLI.

It is meant for quick everyday actions:

- list available shortcuts
- search by name
- run a shortcut from Terminal
- open a shortcut directly in the Shortcuts app

## Location

```text
automation/shortcuts/mqshortcuts.sh
```

## Why It Exists

The native `shortcuts` CLI is already useful, but it is easier to reach for a small wrapper with clean commands and examples.

`mqshortcuts` makes it faster to:

- inspect your shortcut library
- run common automations without leaving Terminal
- search inside folders
- connect Apple Shortcuts with `macos-scripts` workflows

## Commands

```text
list [folder]              List shortcuts, optionally in a folder
folders                    List shortcut folders
search <query> [folder]    Search shortcuts by name
run <name> [input-path]    Run a shortcut, optionally with input
view <name>                Open a shortcut in the Shortcuts app
help                       Show help
```

## Examples

List all shortcuts:

```bash
bash automation/shortcuts/mqshortcuts.sh list
```

List folders:

```bash
bash automation/shortcuts/mqshortcuts.sh folders
```

Search all shortcuts:

```bash
bash automation/shortcuts/mqshortcuts.sh search clip
```

Search inside a folder:

```bash
bash automation/shortcuts/mqshortcuts.sh search clip Work
```

Run a shortcut:

```bash
bash automation/shortcuts/mqshortcuts.sh run "Daily Briefing"
```

Run a shortcut with file input:

```bash
bash automation/shortcuts/mqshortcuts.sh run "Resize Image" ~/Desktop/pic.png
```

Open a shortcut in the Shortcuts app:

```bash
bash automation/shortcuts/mqshortcuts.sh view "Daily Briefing"
```

## Notes

- requires the macOS `shortcuts` command-line tool
- uses `rg` for search if available, otherwise falls back to `grep`
- works well as a base for future `mqlaunch` integration

## Typical Use Cases

- run personal automations faster
- connect file workflows with Shortcuts
- inspect your shortcut library from Terminal
- bridge GUI automation and shell workflows
