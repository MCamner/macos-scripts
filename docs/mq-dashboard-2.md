# MQ Dashboard 2.0 — MQ Stack Control Center

A keyboard-only terminal control center for the whole MQ stack, started with
`mqlaunch dashboard`. It is a presentation layer: every value comes from an
existing MQ command, a local file or a localhost endpoint. Existing `mqlaunch`,
`mongoTerminal`, scripts and menus are unchanged.

It runs on the built-in macOS `/usr/bin/python3` (3.9) with the standard-library
`curses`. Nothing to install: it works after a normal `git pull` of
`macos-scripts`.

## Usage

```sh
mqlaunch dashboard          # interactive, needs a TTY of at least 60x20
mqlaunch dashboard --json   # collect every source once, print JSON, exit
```

Direct start, bypassing `mqlaunch`:

```sh
/usr/bin/python3 terminal/dashboard/mq_dashboard.py
```

Without a TTY and without `--json` it exits 2 with a hint.

## Layout

* **Full with header** (120x46 or larger), the reference layout: an MQ logo
  header with host, user, repository path and local IP, plus stack status,
  uptime, last check, colour depth and the macos-scripts version; seven Stack
  Health cards; a 3x2 panel grid (Repositories, MCP Services, AI Models,
  Evidence & Learning, Recent Results, GitHub & Releases) with column tables;
  ten numbered Quick Action tiles; key footer.
* **Full** (120x36 up to 45 rows): the same cards and panels under a one-line
  header, with Quick Actions as wrapped text lines.
* **Compact** (60x20 up to full size): the same cards and panels stacked in one
  scrollable column. No panel or function is removed; long values wrap.
* Below 60x20 the dashboard asks for a larger window.

Colours follow the terminal's 256-colour palette on the terminal's own
background (the dashboard paints none); normal text uses the terminal's
foreground colour:
cyan frames and headings, blue selection, green PASS, yellow WARN/STALE,
red FAIL, light blue informational states, grey secondary text.
`NO_COLOR` gives a monochrome fallback.

Icons are single-cell Unicode symbols (▤ ⎇ ◈ ◎ ◆ ⚙ ✓ ✗ ●), which render in
ordinary monospace fonts such as JetBrains Mono or SF Mono. Emoji and Nerd
Font glyphs are deliberately not used: they are two cells wide or need a
patched font, and either breaks column alignment. A test holds every glyph
to single width.

The IP and user shown in the header are read for the screen only. Evidence
exports leave the whole `host` source out.

## Keys

| Key | Action |
| --- | --- |
| ↑ ↓ | previous / next row, scroll; on Home move between panel rows |
| ← → | previous / next tab; on Home move panel focus |
| Enter | open the focused panel, or run the row's action (always asks first) |
| Esc / Backspace | back one level (filter → details → section → Home) |
| Tab / Shift-Tab | switch focus between panels, or between table and details |
| 1–9, 0 | quick actions as numbered on Home: 1 Doctor, 2 Repositories, 3 MCP Services, 4 AI Models, 5 Evidence, 6 Memory, 7 GitHub, 8 Security, 9 Repair Planner, 0 Automation |
| Home | back to Home from anywhere |
| R | refresh every source |
| / | Home: open the first matching section; section: filter rows |
| P | cycle the History period (24h, 7d, 30d, all) |
| M | open `mongoTerminal`; the dashboard resumes when it exits |
| H | help |
| Q | quit |

Mouse input is disabled.

## Sections and data sources

| Section | Tabs | Sources |
| --- | --- | --- |
| Repositories | Overview, Provenance | `mq-agent stack status --json`, `mq-agent stack provenance --json` |
| MCP Services | Overview, Services, Logs, Tool Surface, Compatibility, Diagnostics | `launchctl print`, `lsof`, `ps`, LaunchAgent plists, `mq-agent mcp status --json`, service log tails |
| AI Models | Overview, Ollama Models, Running Models, OpenAI, Routing, Diagnostics | Ollama HTTP API (`/api/version`, `/api/tags`, `/api/ps`), `mq-agent models current --json`, `mqlaunch auth status --json`, `sysctl`, `vm_stat` |
| Evidence & Learning | Overview, Routing, Hybrid Retrieval, Memory, History, Export | `mq-agent route readiness/divergence/history --json`, `mq-agent feedback report/candidates --json`, `mq-agent memory review-status`, `mq-agent obsidian inbox list --json` |
| Repair Planner | Overview, Issues, Analysis, Fix Plan, History, Settings | derived from every source above plus `mqlaunch doctor --fix-plan --json` and `mq-agent stack compatibility --json` |
| GitHub & Releases | Overview, Pull Requests, CI Checks, Releases, Compatibility, History | `gh pr list`, `gh release list`, stack verification scopes, `mq-agent stack compatibility --json` |
| Automation | Overview, Jobs, History, Failures | `~/Library/LaunchAgents/se.mq.*.plist`, `launchctl print`, `~/mq-evidence/` snapshots and error log |
| Help | Keys, Status, Sources, Safety | per-source status, timing and error |

Sources are collected in parallel when the dashboard starts and on R; panels
fill in as results arrive and show LOADING until then. Help > Sources shows the
exact command, duration and error for each one.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| PASS | measured now and within freshness limits |
| WARN | measured, needs attention |
| FAIL | measured failure |
| STALE | was green, but the evidence is older than its freshness window |
| UNVERIFIED | no evidence either way |
| UNTESTED | available but not exercised (OpenAI before an explicit test) |
| UNAVAILABLE | the source failed or does not exist |
| LOADING | the source is still running |

Rules the views enforce, each covered by `tests/test_mq_dashboard.py`:

* Missing data never shows PASS. With no data, every card is UNAVAILABLE and
  Repair Planner lists every source as UNVERIFIED.
* An installed Ollama model is not a running model: `/api/tags` and `/api/ps`
  are shown separately. The dashboard never runs `ollama list`, which would start
  the server.
* Green CI checks on stale evidence show STALE, not PASS. CI evidence proves the
  commit on GitHub, not this machine's install; Repositories > Provenance shows
  the local layers.
* OpenAI stays UNTESTED until the operator runs the explicit test.
* The Security card counts dangerous MCP tools, permission-class violations
  reported by mq-mcp's orchestration contract, and an auth mismatch between the
  process environment and the Keychain. It is not a full security audit.

## Repair Planner

The planner follows DETECT → ANALYZE → FIX PLAN → PREVIEW → OPERATOR APPROVAL
→ APPLY → VALIDATE → RECORD EVIDENCE, but the dashboard stops at PREVIEW:

* Issues are derived from doctor actions, unverified or dirty repositories,
  provenance disagreements, stopped services, failed scheduled jobs, routing
  and feedback health, contract failures, a stale inbox, an unreachable Ollama
  API and unavailable sources.
* Each issue carries its evidence source, a root-cause analysis, the affected
  components, a proposed command, risk, reversibility and a verify command.
* Enter on a Fix Plan row copies the command to the clipboard after a `y`. You
  run it in your own terminal, then press R to validate.
* Automatic repair is disabled in code. Changing that is a reviewed PR, not a
  setting.

## Safety boundaries

* Commands run as argument lists with no shell and bounded timeouts.
* Three operator actions exist, each behind a `y` confirmation: the OpenAI API
  test (one request through `mqlaunch auth test openai --json`), evidence export
  to `~/mq-evidence/dashboard-export/` (JSON `mq.dashboard-export.v1` plus
  Markdown, hostname excluded), and clipboard copy of a proposed command.
* No restarts, installs, promotions or repairs are executed.
* API keys are never read or shown. Log tails, errors, LaunchAgent commands and
  exports are passed through a redaction filter for credential-shaped values.

## Code layout

| File | Role |
| --- | --- |
| `terminal/dashboard/dashboard_sources.py` | read-only collectors, parallel `Collector`, confirmed actions |
| `terminal/dashboard/dashboard_views.py` | pure view builders: cards, panels, tables, issue detection |
| `terminal/dashboard/mq_dashboard.py` | curses drawing, layout, keys, entry point |
| `tests/test_mq_dashboard.py` | truth rules, sources, layout at four sizes, key flows, 3.9 syntax guard |

If the active MCP checkout differs from `~/mq-mcp`, set
`MQ_STACK_MCP_REPO_PATH` before launching; `mq-agent` reads it. `MQ_AGENT_DIR`
and `MQ_AGENT_BIN` override where `mq-agent` is found.

## Known limits

* Hybrid Retrieval shows what `mq.feedback-report.v1` measures. Precision,
  channel coverage and contradiction rate are not in that report and show
  UNAVAILABLE.
* OpenAI integrations have no registry source and show UNAVAILABLE.
* Repair history has no evidence log yet; the tab lists evidence exports.
* `mq-agent memory review-status` has no JSON mode, so the Memory tab shows its
  text output and parses only the tier counts for the overview.
