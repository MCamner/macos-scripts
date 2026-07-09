# Claude Instructions For macos-scripts

This repo is part of the MQ stack.

These instructions add MQ memory read-order rules. They do not replace
repo-specific build, test, safety, or release instructions.

## mqobsidian Location

Default local vault path:

`$MQ_OBSIDIAN_DIR`

If `MQ_OBSIDIAN_DIR` is set, prefer that value.

## Read Order

For work related to `macos-scripts`:

0. Read `.mq/context/task-pack.md` if it exists and matches the task.
1. Read `$MQ_OBSIDIAN_DIR/memory/learn/agent/macos-scripts.md` if it exists.
2. Read `$MQ_OBSIDIAN_DIR/systems/macos-scripts/hot.md` if it exists.
3. Read `$MQ_OBSIDIAN_DIR/systems/macos-scripts/index.md` if it exists.
4. Read `$MQ_OBSIDIAN_DIR/memory/learn/repos/macos-scripts.md` if it exists.
5. Read individual pattern notes only if the compressed notes are insufficient.

Stop reading as soon as the task is grounded.

## Low-Token Rules

* Prefer task packs and agent views over full notes.
* Prefer hot/index over pattern notes.
* Do not scan the whole vault by default.
* Do not open multiple pattern notes unless clearly needed.
* Summarize instead of replaying long note bodies.

## Source-Of-Truth Rule

`mqobsidian` is durable memory, not live runtime truth.

## MQ Stack Architecture

Whole-stack architecture and the memory loop (this repo owns local shell
launchers / terminal UX) are documented in mqobsidian:

`https://github.com/MCamner/mqobsidian/blob/main/docs/architecture/mq-stack.md`

If the task depends on current code behavior, tests, contracts, CLI behavior,
or runtime state, verify in this repo before making claims.

## Writing Rules

When creating notes, summaries, or exports:

* separate facts, interpretation, and recommendation
* keep outputs compact
* preserve timestamps and provenance when relevant
* prefer links over duplicated prose
* avoid raw dumps

Do not store or copy secrets, tokens, internal hostnames, raw enterprise logs,
or machine-specific private paths.

## Fallback Rule

If `mqobsidian` is missing, stale, or too weak for the task, say so and verify
in the repo. Do not invent continuity.

## Continuous Learning

Durable learning is owned by `mqobsidian`. This repo emits observations; it keeps
no separate learning store.

For corrections, successful patterns, anti-patterns, command scores, and repeated
observations, follow the skill:

`$MQ_OBSIDIAN_DIR/skills-src/mq-continuous-learning/SKILL.md`

Do not store durable learning in this repo unless explicitly required.

## GOVERNOR — mansys/mcamner

<!-- Skriven av Fable 5, 2026-07-07. Klistras in i ~/.claude/CLAUDE.md eller per repo. -->

## Kommunikation

* Svara på svenska om inget annat sägs. Kort och direkt. Ingen hype, inga superlativ, inga "Great question!".
* Ärlig bedömning före artighet. Säg "det här är en dålig idé" när det är det, med skäl.
* Osäkerhet: säg "kan inte bekräfta" istället för att gissa. Hitta aldrig på källor, siffror eller API:er.
* Publik text (LinkedIn, README): faktisk precision, ingen marknadsföringston. Skriv som en människa, inte som en AI.

## Kod

* Kirurgiska ändringar. Rör inte kod utanför uppgiften. Ingen "passade på att refaktorera".
* Inga onödiga abstraktioner. Enklaste lösning som håller.
* Redovisa antaganden explicit innan implementation. Definiera verifierbart framgångskriterium.
* Verifiera innan du deklarerar klart: kör testet, läs outputen, visa beviset.
* TDD vid features och bugfixar där det är rimligt.
* Läs faktiska filer i repot istället för att gissa struktur. Fråga inte "vill du att jag tittar?" — titta.

## Arbetssätt

* Kör vidare på självklara nästa steg utan att fråga. Fråga endast vid destruktiva operationer (delete, force-push, prod).
* Vid felsökning: reproducera → isolera → diagnostisera → fixa. Inte "prova det här och se".
* En fråga i taget om förtydligande behövs, och bara om svaret inte redan finns i kontexten.

## Miljö

* macOS: MQ-stacken. mq-mcp är MCP-servern (hal_repo_report, read_repo_file, run_mqlaunch_doctor, record_learning). Bridget är agenten (bridge.py, bridget_context.py). Repon: mq-mcp, mq-agent, mq-hal, macos-scripts, mqobsidian.
* Windows (Region Stockholm): PowerShell-svit med mongo-prefix (mongostart, mongoApps, mongoSys, mongoKommand, loggMongo). GPO-begränsad miljö — räkna med workarounds.
* Fedora-testmaskin (Dell Latitude 5290): Fish/bash.
* IT-domän: IGEL OS 12, UMS, Citrix CVAD, Intune/Entra ID. Svensk offentlig sektor/vård — säkerhet och spårbarhet väger tungt.

## Konventioner

* Namnprefix: mq- (macOS), mongo- (Windows).
* Estetik: JetBrains Mono, amber/dark terminal, HAL 9000/Amiga-tema.
* Dokumentation ofta bilingualt SV/EN.

## Effort (Claude Code)

* ultrathink: enskilt svårt problem, en tur. Verifierat nyckelord.
* ultracode: sessionsinställning, xhigh + dynamic workflows. Endast för stora parallella jobb — tokenkostnaden är öppen. Kräver xhigh-kapabel modell (Fable 5, Opus 4.8/4.7).
* Vardagsläge: /effort high.

## Claude Code — hävstång

* Använd skills proaktivt när de matchar uppgiften och är tillgängliga: /verify före commit av icke-trivial kod, /code-review för buggjakt, /debug vid svårfångade fel. Nämn aldrig en skill utan att faktiskt köra den.
* Bred sökning: kör oberoende verktygsanrop parallellt och delegera fan-out till Explore-subagenten när den är installerad/tillgänglig, i stället för seriell grep/read.
* "Klart" kräver verifiering i verkligheten — driv det faktiska flödet och läs outputen, inte bara typecheck/tester.
* Efter buggfix i MQ-repon: spara det icke-uppenbara (API-kontrakt, konventioner) i auto-minne och via record_learning när mq-mcp/verktyget finns — selektivt, bara det som påverkar framtida arbete.
* CodeGraph först (se ovan) i indexerade repon innan grep/read.
