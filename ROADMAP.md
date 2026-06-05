# Roadmap

Current version: 0.5.1

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
  and `validate_orchestration_contract`
- [x] `mqlaunch mcp-status` — shows mq-mcp version, tool count, contract
  freshness via `mq-agent mcp status`
- [x] Update docs: all new commands documented in `docs/COMMANDS.md`
- [x] Boundary test: verify none of the new commands embed review or
  semantic logic — they must only forward to mq-agent

---

## v0.5.1 — workflow validation release gate — Done

Goal: make workflow command-surface validation part of the release gate, so
mqlaunch docs, routing and workflow scripts stay aligned before release.

- [x] `mqlaunch workflows validate` documented in README and `docs/COMMANDS.md`
- [x] workflow validation smoke coverage verifies docs, menu and launcher routing
- [x] `mqlaunch release-check` runs `automation/workflows/validate.sh`
- [x] release metadata synced to `0.5.1`

---

## Maintenance / future ideas

The scheduled v0.5.x roadmap is complete. These ideas are intentionally
unscheduled until there is a concrete implementation target:

- plugin-style extensions
- remote execution support
- improved onboarding

## Completed

- mqlaunch command surface
- terminal release check workflow
- doctor / system check
- workflow validation / health checks
- secrets scan via gitleaks
