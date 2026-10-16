# MQ Dashboard 2.0 — keyboard-only MVP

The new optional terminal interface is reached through `mqlaunch dashboard`.
It is additive: existing `mqlaunch`, `mongoTerminal`, scripts, and menus remain available.
Requires the built-in macOS `/usr/bin/python3` with `curses` (no Python package install).

## Usage

```sh
mqlaunch dashboard
mqlaunch dashboard --json
```

Keys: Up/Down select modules, Enter open, Left/Right change tabs, Esc home,
1–9/0 select a module, R refresh, H help, Q quit.
Mouse input is disabled. Use an interactive terminal at least 65×14 characters.

## Real data and safe boundaries

- Repositories: `mq-agent stack status --json`, including each status and exact HEAD.
- Routing: `mq-agent route readiness --json` with the active applied docs-review evidence gates.
- MCP: `launchctl print` plus `lsof` for the established user services on 8765/8766.
- AI: `ollama list` lists installed models (not an inference readiness claim).
- GitHub: `gh auth status` only; no credential material is shown.
- Automation history: read-only snapshot filenames in `~/mq-evidence/`.

Unknown, missing or timed-out metrics show **UNAVAILABLE**, never green by default.
Hybrid Retrieval, Memory, Repair Planner, and Export are explicit read-only
placeholders until their typed data adapters and approval-gated workflows exist.
No mutation, restarts, installation, or automatic promotion are performed.
Command execution uses argument lists without a shell and bounded timeouts.
If your active MCP repo differs from `~/mq-mcp`, set
`MQ_STACK_MCP_REPO_PATH=~/mq-mcp-main` before launching.

## Design ownership

`macos-scripts` owns the display and keyboard navigation;
`mq-agent` remains authoritative for evidence, GitHub verification and routing gates.
`mq-mcp`, `mq-hal`, `repo-signal` and `mqobsidian` retain their own contracts.
No separate dashboard updater or global mutable status cache is introduced.
