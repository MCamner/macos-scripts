# Roadmap

Current version: 0.5.0

## Design boundary

mqlaunch and macos-scripts own the **human terminal entrypoint** — menus,
shortcuts, and launchers. They do not own cognition, review logic, or
semantic memory. Those belong to mq-mcp (central AI cognition runtime).

```text
mqlaunch shows menu → delegates → mq-agent orchestrates → mq-mcp executes
```

mqlaunch must not:
- implement its own review logic
- duplicate mq-mcp tool calls directly
- embed semantic memory logic in shell scripts

---

## v0.5.0 — mq-mcp review routing

Goal: make mq-mcp review and architecture workflows reachable from
mqlaunch without embedding any cognition in the shell layer.

- [x] `mqlaunch review` — delegates to `mq-agent review` (calls
  `review_file` / `review_diff` via MCPBridge)
- [x] `mqlaunch architecture` — calls `mq-agent` → `list_architecture_decisions`
  or `detect_architecture_drift`
- [x] `mqlaunch risk-review` — delegates to `mq-agent review --risk` when
  mq-mcp ≥ v1.5.0 (risk layer)
- [x] `mqlaunch repo-health` — delegates to `mq-agent` → `repo_signal_analyze`
  + `validate_orchestration_contract`
- [x] `mqlaunch mcp-status` — shows mq-mcp version, tool count, contract
  freshness via `mq-agent mcp status`
- [x] Update docs: all new commands documented in `docs/COMMANDS.md`
- [x] Boundary test: verify none of the new commands embed review or
  semantic logic — they must only forward to mq-agent

---

## Near-term (unscheduled)

- workflow validation / health checks
- release gate integration (repo-signal publish checklist)
- plugin-style extensions
- remote execution support
- improved onboarding

## Completed

- mqlaunch command surface
- terminal release check workflow
- doctor / system check
- secrets scan via gitleaks
