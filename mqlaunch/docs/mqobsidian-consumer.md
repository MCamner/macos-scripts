# mqobsidian consumer (FAS 7b)

mqlaunch is a **read-only consumer** of the mqobsidian vault: it resolves the
vault, reads a small manifest of supported views, and opens the right file or
folder. It owns no context — `mqobsidian` does. No writes, no scoring, no
pattern/feedback logic.

## Inputs

* **`MQ_OBSIDIAN_DIR`** — primary source for the vault path.
* **Fallback** — `$HOME/mqobsidian` (the single v1 fallback; warns when used).
* **`config/mqobsidian/views.json`** — the only source of supported views. Each
  entry: `key`, `label`, `type` (`file`|`folder`), `relative_path`.
* **`MQOBS_OPENER`** — opener override (default `open`); set to `echo` to dry-run.

## Supported views (v1)

`dashboard` (systems/mqobsidian/index.md) · `roadmaps` · `reviews` · `decisions`
· `execution` · `mq-agent-hot` · `mq-mcp-hot` · `mq-hal-hot`. Paths are resolved
from the manifest, not hardcoded — change the manifest, not the logic.

## Commands

| Command | Does |
| --- | --- |
| `mqobsidian-doctor.sh` | health-check the chain; opens nothing; non-zero on any problem |
| `mqobsidian-open-dashboard.sh` | open the index |
| `mqobsidian-open-view.sh <key>` | open any manifest view |
| `mqobsidian-open-vault-root.sh` | open the vault root (works even if views are missing) |
| `mqobsidian-open-repo-context.sh <repo-key>` | open a repo's context (mq-agent/mq-mcp/mq-hal/mqobsidian) |

All live in `mqlaunch/commands/mqobsidian/`; shared logic in
`mqlaunch/lib/mqobsidian/` (`resolve`, `manifest`, `open`, `doctor`, `errors`).

## Menu

The existing `terminal/menus/mq-obsidian-menu.sh` (main menu → option 9 /
`obsidian`) is the user-facing surface. PR2 wired it to source this lib so the
menu and the commands share **one** opener (`open_mqobsidian_path`), degrading
gracefully if the lib is absent.

PR3 finished the reconciliation: the menu's open actions are now manifest-driven
(no hardcoded view paths — the formerly-inline `docs/roadmap-token-reduction.md`
and `docs/context-budget.md` moved into `views.json` as `roadmap-doc` /
`context-budget`), and a new menu entry **14. Open any view (manifest)** lists
every manifest view (including `decisions`, `execution`, repo hot files) and
opens by number or key. Each refactored action keeps a repo-relative fallback so
it still works if the lib is missing.

## Failure modes (clear errors)

* `MQ_OBSIDIAN_DIR` unset → warn, fall back; if fallback missing → error + exit 1.
* Root exists but missing `systems/`+`memory/` → structure error.
* Unknown view key → "not defined in views.json".
* Manifest target missing → "Target path from manifest does not exist".

## Non-goals

No writes to the vault. No scoring, promotion/downgrade, inbox or feedback-loop
(that is mqobsidian's command-pattern track). No "guess the right file" when the
manifest has no entry.

## Status

* **PR 1:** resolver, manifest, open, doctor + 4 commands, grounded `views.json`
  (8 real views). All 8 test-plan cases green; read-only verified.
* **PR 2:** `mqobsidian-open-repo-context.sh` + wired the existing
  `mq-obsidian-menu.sh` to the lib's shared opener. (Note: the menu already
  existed and is richer than the original spec — no parallel menu was created.)
* **PR 3 (this):** reconciliation — menu open actions are now manifest-driven
  (no hardcoded view paths), plus a manifest "Open any view" picker (entry 14)
  exposing `decisions`/`execution`/repo hot files. Verified non-interactively
  (syntax, doctor, routing, picker by number+key); **final panel rendering should
  be eyeballed once in a real terminal** (`mqlaunch` → 9).
