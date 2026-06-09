# B2 Atlas Prompt OS — TUI

Terminal interface for B2 Atlas Prompt OS — structured prompts for architecture,
implementation, review, research, content, learning, and decision work.

---

## What it is

B2 TUI is a terminal-first prompt browser and composer. It reads the B2 project
index from your local Obsidian vault, lets you navigate prompts by category,
compose them with a task description, and saves the result to Obsidian and your
clipboard.

## What it is not

* Not an AI — it structures and delivers prompts, it does not run them
* Not a cloud service — all data stays local
* Not a replacement for raw `mqlaunch ask` — it is optimised for structured
  B2 prompt work, not freeform questions

---

## Path assumptions

| Config key       | Default path                                             |
| ---------------- | -------------------------------------------------------- |
| `VAULT`          | `~/mqobsidian`                                           |
| `B2_SOURCE_DIR`  | `~/mqobsidian/Prompt-OS/B2-Atlas-Prompt-OS`              |
| `PROJECT_INDEX`  | `…/B2-Atlas-Prompt-OS/PROJECT_INDEX.md`                  |
| `PROMPTS_DIR`    | `~/mqobsidian/_prompts/saved-prompts-md-export`          |
| `RUNS_DIR`       | `~/mqobsidian/mq-stack/runs`                             |
| `HISTORY_FILE`   | `~/.b2tui_history.jsonl`                                 |

Paths are defined in [mqlaunch/b2_tui/config.py](../mqlaunch/b2_tui/config.py).

---

## Quickstart

```bash
mq b2               # open interactive TUI
mq b2 list          # list all prompts by category
mq b2 show 02.11    # show a single prompt
mq b2 compose 02.11 "design TUI architecture"
mq b2 route "bygga en blueprint för nytt system"
mq b2 history
mq b2 validate
mq b2 config
```

From the interactive menu: **Main → 5 (Dev) → a (B2 Atlas Prompt TUI)**

---

## Commands

### `mq b2` — open TUI

Launches the full-screen textual TUI.

```
┌──────────────────────────────────────────────────┐
│ B2 Atlas Prompt OS                               │
├───────────────────┬──────────────────────────────┤
│ Categories        │ Projects                     │
│  01 Core          │  02.11  Integration Blueprint│
│  02 Architecture  │  02.10  Architecture Review  │
│  05 Content       │  05.03  Interactive Content  │
├───────────────────┴──────────────────────────────┤
│ Preview                                          │
└──────────────────────────────────────────────────┘
```

**Keys:** `j/k` navigate · `Tab` switch panel · `/` search · `Enter` select ·
`r` route · `c` compose · `h` history · `v` validate · `q` quit

---

### `mq b2 list`

Lists all 43 prompts grouped by category.

---

### `mq b2 categories`

Lists categories with prompt counts.

---

### `mq b2 show <id>`

Shows prompt metadata and a content preview.

```bash
mq b2 show 02.11
```

---

### `mq b2 compose <id> "<task>"`

Composes a prompt with your task description. Copies to clipboard and saves a
timestamped run file to `~/mqobsidian/mq-stack/runs/`.

```bash
mq b2 compose 02.11 "design the payment service integration layer"
```

---

### `mq b2 run <id>`

Interactive version of compose — prompts for context in the terminal.

```bash
mq b2 run 02.11
mq b2 run 02.11 --context "design the payment service"
```

---

### `mq b2 route "<task>"`

Routes a task description to the best matching prompt and up to two support
prompts. Optionally composes immediately.

```bash
mq b2 route "ta fram blueprint för nytt API"
mq b2 route "granska pull request" --no-run
```

---

### `mq b2 validate`

Checks that all prompt files on disk are readable. Reports OK / WARN / FAIL per
file and exits non-zero if any FAIL.

---

### `mq b2 config`

Shows the resolved path configuration and whether each path exists on disk.

---

### `mq b2 history [last|export]`

```bash
mq b2 history           # show last 10 runs
mq b2 history last      # show most recent entry
mq b2 history export    # write b2-history.md to RUNS_DIR
mq b2 history -n 20     # show last 20 runs
```

---

### `mq b2 export-last`

Prints the path to the most recent Obsidian run file.

---

### `mq b2 open-last`

Opens the most recent run file in your default editor.

---

## Troubleshooting

**`No prompts found`** — Check that `PROJECT_INDEX.md` exists:

```bash
mq b2 config
```

**TUI does not start** — Check that textual is installed:

```bash
python3 -c "import textual; print(textual.__version__)"
pip3 install textual --break-system-packages
```

**Clipboard not working** — `pbcopy` is macOS-only. On other systems the
composed prompt is printed to stdout instead.

**`File not found` in validate** — Prompt files in `saved-prompts-md-export/`
do not match the IDs in `PROJECT_INDEX.md`. Run `mq b2 validate` for details.

---

## Running tests

```bash
cd ~/macos-scripts
PYTHONPATH=. /opt/homebrew/bin/pytest mqlaunch/b2_tui/tests -v
```

All 40 tests run without touching the real Obsidian vault — they use `tmp_path`
fixtures and `unittest.mock.patch`.

---

## Package layout

```
mqlaunch/b2_tui/
├── config.py               path constants
├── models.py               Prompt dataclass
├── main.py                 CLI entry point (argparse)
├── core/
│   ├── project_loader.py   parse PROJECT_INDEX.md
│   ├── router.py           keyword-based task router
│   ├── prompt_composer.py  compose + clipboard + history
│   ├── history.py          JSONL history read/write
│   └── validator.py        file-readability checks
├── adapters/
│   └── obsidian_writer.py  write run files to vault
├── tui/
│   ├── app.py              textual B2App
│   └── screens.py          modal screens (route/compose/history/search)
└── tests/
    ├── test_config.py
    ├── test_project_loader.py
    ├── test_router.py
    ├── test_prompt_composer.py
    ├── test_validator.py
    ├── test_history.py
    └── test_obsidian_writer.py
```
