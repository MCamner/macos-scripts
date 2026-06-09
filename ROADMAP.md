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

* implement its own review logic
* duplicate mq-mcp tool calls directly
* embed semantic memory logic in shell scripts

---

## v0.5.0 — mq-mcp review routing

Goal: make mq-mcp review and architecture workflows reachable from
mqlaunch without embedding any cognition in the shell layer.

* [x] `mqlaunch review` — delegates to `mq-agent review` (calls
  `review_file` / `review_diff` via MCPBridge)
* [x] `mqlaunch architecture` — calls `mq-agent` → `list_architecture_decisions`
  or `detect_architecture_drift`
* [x] `mqlaunch risk-review` — delegates to `mq-agent review --risk` when
  mq-mcp ≥ v1.5.0 (risk layer)
* [x] `mqlaunch repo-health` — delegates to `mq-agent` → `repo_signal_analyze`
  and `validate_orchestration_contract`
* [x] `mqlaunch mcp-status` — shows mq-mcp version, tool count, contract
  freshness via `mq-agent mcp status`
* [x] Update docs: all new commands documented in `docs/COMMANDS.md`
* [x] Boundary test: verify none of the new commands embed review or
  semantic logic — they must only forward to mq-agent

---

## v0.5.1 — workflow validation release gate — Done

Goal: make workflow command-surface validation part of the release gate, so
mqlaunch docs, routing and workflow scripts stay aligned before release.

* [x] `mqlaunch workflows validate` documented in README and `docs/COMMANDS.md`
* [x] workflow validation smoke coverage verifies docs, menu and launcher routing
* [x] `mqlaunch release-check` runs `automation/workflows/validate.sh`
* [x] release metadata synced to `0.5.1`

---

## Near-term (unscheduled)

* plugin-style extensions
* remote execution support
* improved onboarding

## Completed

* mqlaunch command surface
* terminal release check workflow
* doctor / system check
* workflow validation / health checks
* secrets scan via gitleaks

---

## B2 TUI / mqlaunch Roadmap

## Current focus

Bygga in **B2 TUI MVP** i `macos-scripts` som en del av `mqlaunch`.

Målet är att `mqlaunch` ska bli terminalingången för B2 / Atlas Prompt OS:

```bash
mq b2
mq b2 list
mq b2 show 02.11
mq b2 route "ta fram blueprint för terminal TUI"
mq b2 compose 02.11 "ta fram blueprint för terminal TUI"
mq b2 validate
mq b2 history
```

---

## Strategic intent

`macos-scripts` ska vara mitt lokala terminal- och launcher-repo.

B2 TUI ska göra det möjligt att:

* läsa B2 Prompt OS-projekt från lokal källa
* visa projekt i terminalen
* söka bland projekt
* välja rätt B2-projekt för en uppgift
* komponera färdiga prompts
* spara körhistorik
* exportera körningar till Obsidian
* senare kopplas mot `mq-agent`, `mq-mcp`, `repo-signal` och `mq-hal`

---

## Design principle

Bygg **CLI-first, TUI-second**.

Rätt ordning:

```text
core logic
→ CLI commands
→ tests
→ history
→ Obsidian export
→ terminal TUI
→ mq-agent bridge
```

TUI:t ska inte bli smart först.
Det ska bli stabilt först.

---

## Repository placement

B2 TUI ska ligga under `mqlaunch`:

```text
macos-scripts/
├─ terminal/launchers/mqlaunch.sh
├─ mqlaunch/
│  ├─ commands/
│  │  └─ b2.sh
│  └─ b2_tui/
│     ├─ __init__.py
│     ├─ main.py
│     ├─ config.py
│     ├─ models.py
│     ├─ core/
│     │  ├─ project_loader.py
│     │  ├─ router.py
│     │  ├─ prompt_composer.py
│     │  ├─ validator.py
│     │  └─ history.py
│     ├─ adapters/
│     │  └─ obsidian_writer.py
│     ├─ tui/
│     │  ├─ app.py
│     │  └─ screens.py
│     └─ tests/
│        ├─ test_project_loader.py
│        ├─ test_router.py
│        ├─ test_prompt_composer.py
│        ├─ test_validator.py
│        ├─ test_history.py
│        └─ test_obsidian_writer.py
```

---

## B2 TUI MVP

## MVP scope

### In scope

* [x] Load B2 project files
* [x] Parse `PROJECT_INDEX.md`
* [x] Parse `B2_ALL_PROMPT_PROJECTS.md` (ersatt av PROJECT_INDEX.md — ingen separat fil i vaulten)
* [x] Support optional `registry/projects.json` (WARN i validate om saknas)
* [x] List all B2 projects
* [x] List all B2 categories
* [x] Show single project by ID
* [x] Route a task to best B2 project
* [x] Compose prompt from selected project + user input
* [x] Save run history
* [x] Export prompt runs to Obsidian
* [x] Expose commands through `mq b2`
* [x] Add tests

### Out of scope for MVP

* [ ] No automatic OpenAI API execution
* [ ] No GitHub write actions
* [ ] No automatic commits
* [ ] No agentic execution
* [ ] No complex memory engine
* [ ] No RAG/vector database
* [ ] No modification of B2 source files

MVP ska vara **read-only mot B2-källor**.

---

## Phase 0 — Foundation

### Goal

Skapa stabil grundstruktur i `macos-scripts`.

### Tasks

* [x] Skapa branch:

```bash
git checkout -b feat/b2-tui-mvp
```

* [x] Skapa katalogstruktur:

```bash
mkdir -p mqlaunch/b2_tui/{core,adapters,tui,tests}
touch mqlaunch/b2_tui/__init__.py
touch mqlaunch/b2_tui/main.py
touch mqlaunch/b2_tui/config.py
touch mqlaunch/b2_tui/models.py
touch mqlaunch/b2_tui/core/{project_loader.py,router.py,prompt_composer.py,validator.py,history.py}
touch mqlaunch/b2_tui/adapters/obsidian_writer.py
touch mqlaunch/b2_tui/tui/{app.py,screens.py}
touch mqlaunch/b2_tui/tests/{test_project_loader.py,test_router.py,test_prompt_composer.py,test_validator.py,test_history.py,test_obsidian_writer.py}
```

* [x] Lägg till minimal `main.py`
* [x] Lägg till `config.py`
* [x] Lägg till `models.py`
* [x] Lägg till första unit test
* [x] Säkerställ att modulen startar utan importfel

### Done when

```bash
python -m mqlaunch.b2_tui.main --help
```

fungerar utan crash.

---

## Phase 1 — Config

### Goal

Samla alla lokala sökvägar på ett ställe.

### Expected paths

```text
B2 source:
~/mqobsidian/Prompt-OS/B2-Atlas-Prompt-OS

Obsidian stack:
~/mqobsidian/mq-stack

Runs:
~/mqobsidian/mq-stack/runs

Roadmaps:
~/mqobsidian/mq-stack/roadmaps
```

### Tasks

* [x] Skapa `B2Config`
* [x] Lägg in default paths
* [ ] Stöd environment overrides senare
* [x] Validera att paths finns
* [x] Ge tydliga felmeddelanden om paths saknas

### Done when

```bash
python -m mqlaunch.b2_tui.main config
```

visar:

```text
B2 source path: OK
Obsidian stack path: OK
History path: OK
```

---

## Phase 2 — Project Loader

### Goal

Läsa in B2-projekten från markdown och normalisera dem.

### Sources

* `PROJECT_INDEX.md`
* `B2_ALL_PROMPT_PROJECTS.md`
* optional: `registry/projects.json`

### Internal model

```python
@dataclass
class B2Project:
    id: str
    name: str
    category: str
    status: str | None
    role: str | None
    prompt: str
    source_file: str
```

### Tasks

* [x] Läs `PROJECT_INDEX.md`
* [x] Extrahera kategorier
* [ ] Läs `B2_ALL_PROMPT_PROJECTS.md` (filen finns ej — ersatt av PROJECT_INDEX.md)
* [x] Extrahera projekt-ID
* [x] Extrahera projektnamn
* [x] Extrahera status (mq_stack-annotation)
* [ ] Extrahera roll (separat fält)
* [x] Extrahera prompttext
* [x] Normalisera till `B2Project`
* [x] Hantera saknade fält utan crash

### Commands

```bash
mq b2 list
mq b2 categories
mq b2 show 02.11
```

### Done when

* [x] `mq b2 categories` visar 8 kategorier
* [x] `mq b2 list` visar alla importerade B2-projekt
* [x] `mq b2 show 02.11` visar `Integration Architecture Blueprint`
* [x] Saknad registry-fil ger warning, inte crash

---

## Phase 3 — Validator

### Goal

Snabbt kunna kontrollera att B2 TUI kan köras på aktuell maskin.

### Validator checks

* [x] B2 source path exists
* [x] `PROJECT_INDEX.md` exists
* [ ] `B2_ALL_PROMPT_PROJECTS.md` exists (filen finns ej)
* [x] Categories can be parsed
* [x] Projects can be parsed
* [ ] Project IDs are unique
* [x] Prompts are not empty
* [ ] Obsidian stack path exists
* [ ] Runs path exists or can be created
* [ ] History file is writable
* [x] mqlaunch wrapper exists

### Command

```bash
mq b2 validate
```

### Expected output

```text
B2 TUI Validation

OK    B2 source path
OK    PROJECT_INDEX.md
OK    B2_ALL_PROMPT_PROJECTS.md
OK    categories found: 8
OK    projects found: 43
OK    unique project ids
OK    Obsidian stack path
OK    history writable
WARN  registry/projects.json not found locally

Status: usable
```

### Done when

* [x] validator ger OK/WARN/FAIL
* [x] exit code fungerar
* [x] felmeddelanden är begripliga
* [x] validator kan köras i test/CI

---

## Phase 4 — CLI command surface

### Goal

Göra B2 TUI användbar innan riktig TUI finns.

### Commands

```bash
mq b2
mq b2 list
mq b2 categories
mq b2 show 02.11
mq b2 validate
mq b2 route "..."
mq b2 compose 02.11 "..."
mq b2 history
mq b2 history last
mq b2 export-last
```

### Tasks

* [x] Bygg `argparse` eller `typer` command parser
* [x] Koppla `list`
* [x] Koppla `categories`
* [x] Koppla `show`
* [x] Koppla `validate`
* [x] Koppla `route`
* [x] Koppla `compose`
* [x] Koppla `history`
* [x] Lägg help-text

### Done when

```bash
mq b2 --help
```

visar alla MVP-kommandon.

---

## Phase 5 — Rule-Based Router

### Goal

Kunna routa uppgifter till bästa B2-projekt.

### Router rules v0.1

| Trigger | Primary project |
| --- | --- |
| `blueprint`, `arkitektur`, `integrera`, `integration` | `02.11` |
| `HLD`, `high-level`, `målarkitektur` | `02.02` |
| `LLD`, `low-level`, `implementation`, `kodnära` | `02.03` |
| `review`, `granska`, `risk`, `kritik` | `02.10` |
| `TUI`, `verktyg`, `interactive`, `MVP` | `05.03` |
| `drift`, `support`, `RACI`, `runbook` | `02.09` |
| `research`, `rapport`, `marknad` | `04.01` |
| `problem`, `komplext`, `resonera` | `01.07` |
| `förklara`, `lära`, `förstå` | `06.01` |
| `karriär`, `jobb`, `roll` | `08.03` |

### Support project logic

Examples:

```text
roadmap + obsidian + stack
→ primary: 02.11
→ support: 02.03, 02.09, 01.07

terminal + TUI + MVP
→ primary: 05.03
→ support: 02.03, 02.11

review + architecture
→ primary: 02.10
→ support: 02.11
```

### Command

```bash
mq b2 route "ta fram blueprint för terminal TUI"
```

### Expected output

```text
Primary:
02.11 Integration Architecture Blueprint

Support:
02.03 Low-Level Implementation Design
05.03 Interactive Tool Builder

Reason:
Task contains blueprint + terminal TUI + implementation signals.
```

### Done when

* [x] router väljer primary project
* [x] router kan lägga till support projects
* [x] router visar kort reason
* [x] router fungerar utan AI/API
* [x] router testas med minst 15 cases

---

## Phase 6 — Prompt Composer

### Goal

Bygga färdig prompt från B2-projekt + user task.

### Command

```bash
mq b2 compose 02.11 "ta fram blueprint för terminal TUI"
```

### Output format

```markdown
# B2 Prompt Run

## Project

02.11 Integration Architecture Blueprint

## User input

ta fram blueprint för terminal TUI

## Composed prompt

[PROJECT PROMPT TEXT]

## Task

ta fram blueprint för terminal TUI
```

### Tasks

* [x] Hämta projekt via ID
* [x] Läs prompttext
* [x] Kombinera med user input
* [x] Skapa markdown-output
* [x] Spara output till `mq-stack/runs`
* [x] Returnera filepath
* [ ] Lägg stöd för multi-project compose senare

### Done when

* [x] `mq b2 compose 02.11 "..."` sparar `.md` i Obsidian runs
* [x] prompttext är komplett
* [x] task hamnar sist
* [x] tom user input nekas med tydligt fel

---

## Phase 7 — History

### Goal

Spara varje route och compose.

### Storage

Börja med JSONL:

```text
~/mqobsidian/mq-stack/runs/b2-history.jsonl
```

### History item

```json
{
  "timestamp": "2026-06-09T20:00:00+02:00",
  "command": "compose",
  "task": "ta fram blueprint för terminal TUI",
  "projects": ["02.11"],
  "output_file": "/Users/mansys/mqobsidian/mq-stack/runs/2026-06-09-b2-run.md",
  "status": "completed"
}
```

### Commands

```bash
mq b2 history
mq b2 history last
mq b2 history show 5
```

### Done when

* [x] route sparas i history
* [x] compose sparas i history
* [x] senaste körning kan visas
* [x] trasig history-fil kraschar inte appen
* [x] history kan exporteras som markdown

---

## Phase 8 — Obsidian writer

### Goal

B2 TUI ska kunna skriva utdata till `mq-stack`.

### Output locations

```text
~/mqobsidian/mq-stack/runs/
~/mqobsidian/mq-stack/logs/
~/mqobsidian/mq-stack/roadmaps/
```

### Tasks

* [x] Skapa runs-folder om den saknas
* [x] Skapa filnamn från timestamp + task slug
* [x] Skriv composed prompt
* [x] Skriv route summary
* [ ] Uppdatera optional `logs/b2-tui-history.md`
* [x] Säkerställ markdownlint-vänligt format

### Commands

```bash
mq b2 export-last
mq b2 open-last
```

### Done when

* [x] output syns i Obsidian
* [x] interna länkar fungerar
* [x] markdown har rena code fences
* [x] inga trasiga tabeller
* [x] `open-last` öppnar senaste filen i editor/terminal

---

## Phase 9 — mqlaunch integration

### Goal

B2 TUI ska kännas native i `mqlaunch`.

### Wrapper

`mqlaunch/commands/b2.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

python -m mqlaunch.b2_tui.main "$@"
```

### Main launcher routing

Lägg till i `mqlaunch`:

```bash
case "$1" in
  b2)
    shift
    mqlaunch/commands/b2.sh "$@"
    ;;
esac
```

### Commands to verify

```bash
mq b2 validate
mq b2 list
mq b2 show 02.11
mq b2 route "ta fram blueprint för terminal TUI"
mq b2 compose 02.11 "ta fram blueprint för terminal TUI"
mq b2 history
```

### Done when

* [x] `mq b2` fungerar från vanlig terminal
* [x] inga relativa path-problem
* [x] fungerar från annan katalog än repo-roten
* [x] fel visas snyggt
* [ ] wrapper är dokumenterad

---

## Phase 10 — Terminal TUI skeleton

### Goal

Bygga första visuella terminalgränssnittet när CLI fungerar.

### Recommended library

Use `textual`.

### Screens

* Dashboard
* Project Browser
* Project Detail
* Prompt Preview
* Route Result
* History

### Keyboard shortcuts

| Key | Action |
| --- | --- |
| `j/k` | navigate |
| `/` | search |
| `Enter` | open |
| `r` | route task |
| `c` | compose |
| `h` | history |
| `v` | validate |
| `q` | quit |

### First layout

```text
┌──────────────────────────────────────────────┐
│ B2 TUI MVP                                   │
├────────────────────┬─────────────────────────┤
│ Categories          │ Projects                │
│                    │                         │
│ 01 Core             │ 02.11 Integration...    │
│ 02 Architecture     │ 02.10 Architecture...   │
│ 05 Content          │ 05.03 Interactive...    │
├────────────────────┴─────────────────────────┤
│ Preview / Help                               │
└──────────────────────────────────────────────┘
```

### Done when

* [x] `mq b2` öppnar TUI
* [x] projekt visas
* [x] search fungerar
* [x] project preview fungerar
* [x] compose kan triggas från TUI
* [x] quit fungerar rent

---

## Phase 11 — Tests

### Goal

Säkra kärnlogiken innan vidare integration.

### Required tests

```text
mqlaunch/b2_tui/tests/
├─ test_config.py
├─ test_project_loader.py
├─ test_router.py
├─ test_prompt_composer.py
├─ test_validator.py
├─ test_history.py
└─ test_obsidian_writer.py
```

### Minimum test cases

* [ ] config loads default paths
* [ ] missing source path returns clear error
* [ ] project loader finds categories
* [ ] project loader finds project IDs
* [ ] show project by ID works
* [ ] router maps blueprint task to `02.11`
* [ ] router maps TUI task to `05.03`
* [ ] composer includes prompt and user input
* [ ] history writes JSONL
* [ ] validator returns OK/WARN/FAIL
* [ ] obsidian writer uses tempdir in tests
* [ ] no test writes to real vault

### Commands

```bash
pytest mqlaunch/b2_tui/tests
```

### Done when

* [x] all tests pass
* [x] tests do not depend on real Obsidian path
* [x] tests use fixtures/tempdir
* [x] CI can run tests

---

## Phase 12 — Docs

### Goal

Dokumentera så att framtida jag fattar systemet snabbt.

### Files to update

* [x] `README.md`
* [x] `ROADMAP.md`
* [x] `CHANGELOG.md`
* [x] `docs/B2_TUI.md`
* [x] `docs/MQLAUNCH_COMMANDS.md`

### Docs must include

* [x] What B2 TUI is
* [x] What B2 TUI is not
* [x] Local path assumptions
* [x] Commands
* [x] Examples
* [x] Troubleshooting
* [x] Test commands
* [x] Roadmap

### Done when

* [x] README has quickstart
* [x] ROADMAP has B2 TUI section
* [x] CHANGELOG mentions MVP
* [x] docs explain `mq b2`

---

## Phase 13 — v0.1.0 Release

### Release goal

Första stabila B2 TUI MVP.

### Release checklist

* [ ] `mq b2 validate` works
* [ ] `mq b2 list` works
* [ ] `mq b2 categories` works
* [ ] `mq b2 show 02.11` works
* [ ] `mq b2 route "..."` works
* [ ] `mq b2 compose 02.11 "..."` works
* [ ] `mq b2 history` works
* [ ] output exports to Obsidian
* [ ] tests pass
* [ ] README updated
* [ ] ROADMAP updated
* [ ] CHANGELOG updated
* [ ] version updated
* [ ] no dirty debug files
* [ ] branch merged or ready for PR

### Version target

```text
mqlaunch 0.6.0
```

### Tag

```bash
git tag v0.6.0
```

---

## Post-MVP roadmap

## v0.7.0 — mq-agent bridge

* [ ] Export route result to mq-agent
* [ ] mq-agent can read B2 composed prompt
* [ ] workflow: route → compose → review → output
* [ ] no duplicated review logic

## v0.8.0 — mq-mcp review bridge

* [ ] Send composed prompt/output to mq-mcp
* [ ] Use mq-mcp for architecture review
* [ ] Add review contract
* [ ] Add severity result output

## v0.9.0 — repo-signal integration

* [ ] Show repo status in B2 TUI
* [ ] Export repo status to Obsidian
* [ ] Link route decisions to repo health
* [ ] Add roadmap drift view

### v1.0.0 — Stack cockpit

* [ ] `mq stack` dashboard
* [ ] B2 projects
* [ ] repo status
* [ ] roadmap status
* [ ] last runs
* [ ] validation health
* [ ] Obsidian sync status

---

## Current priority

### Now

* [x] Phase 0 — Foundation
* [x] Phase 1 — Config
* [x] Phase 2 — Project Loader
* [x] Phase 3 — Validator
* [x] Phase 4 — CLI command surface

### Next

* [x] Phase 5 — Router
* [x] Phase 6 — Prompt Composer
* [x] Phase 7 — History
* [x] Phase 8 — Obsidian writer

### Later

* [ ] Phase 10 — Terminal TUI skeleton
* [ ] mq-agent bridge
* [ ] mq-mcp bridge
* [ ] repo-signal integration

---

## First sprint

### Sprint 1 — Loader + validate

### Goal

Få första körbara CLI-versionen.

### Tasks

* [ ] skapa `mqlaunch/b2_tui`
* [ ] skapa datamodeller
* [ ] skapa config
* [ ] skapa project loader
* [ ] skapa validator
* [ ] skapa argparse CLI
* [ ] koppla `mq b2 validate`
* [ ] koppla `mq b2 list`
* [ ] koppla `mq b2 show 02.11`
* [ ] skriva tester

### Acceptance commands

```bash
mq b2 validate
mq b2 list
mq b2 show 02.11
pytest mqlaunch/b2_tui/tests
```

---

## Definition of Done for MVP

B2 TUI MVP är klar när detta fungerar:

```bash
mq b2 validate
mq b2 list
mq b2 categories
mq b2 show 02.11
mq b2 route "ta fram blueprint för terminal TUI"
mq b2 compose 02.11 "ta fram blueprint för terminal TUI"
mq b2 history
```

Och:

```bash
pytest mqlaunch/b2_tui/tests
```

går grönt.

MVP:n ska dessutom:

* [ ] inte ändra B2-källfiler
* [ ] inte kräva OpenAI API
* [ ] inte kräva Ollama
* [ ] inte kräva GitHub access
* [ ] fungera från valfri terminalkatalog
* [ ] skriva tydliga felmeddelanden
* [ ] exportera markdown till Obsidian
