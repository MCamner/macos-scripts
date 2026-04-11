# Tools

Reusable scripts, CLI utilities, and release automation for the **macos-scripts** project.

This folder is where standalone tools live — things you can run directly, reuse across modules, or use outside `mqlaunch`.

---

## 🎯 Purpose

Keep powerful, reusable building blocks in one place:

* run tools directly from terminal
* support `mqlaunch` workflows
* enable safe automation (including releases)

---

## 📦 Contents

```
tools/
├── cli/                  # command-line tools (AI, helpers, wrappers)
├── scripts/              # standalone utility scripts
├── mac-terminal-guide/   # terminal guide source
├── release.sh            # release automation script
└── README.md
```

---

## 🚀 Release Automation

The repo includes a **safe, repeatable release system**:

```
tools/release.sh
```

### Preview (no changes)

```
./tools/release.sh --dry-run 0.1.3
```

### Run full release

```
./tools/release.sh 0.1.3
```

### What it handles

* updates `VERSION`
* updates README version badge
* validates `CHANGELOG.md`
* creates commit + tag
* pushes to GitHub
* rolls back changes on failure

👉 Designed to prevent broken or partial releases.

---

## 🧠 CLI Tools

Run tools directly from the repo root:

```
bash tools/cli/ai-mode.sh
```

Used for:

* AI workflows
* command helpers
* integration with `mqlaunch`

---

## 🛠 Scripts

Located in:

```
tools/scripts/
```

Examples include:

* system helpers
* debug / snapshot tools
* reusable shell utilities

Run directly:

```
bash tools/scripts/<script-name>.sh
```

---

## 📚 Terminal Guide

Source:

```
tools/mac-terminal-guide/
```

Generated HTML (via docs):

```
docs/mac-terminal-guide.html
```

Used for:

* onboarding
* reference material
* learning terminal workflows

---

## 🔗 How it fits the system

* `tools/` = reusable building blocks
* `terminal/` = user interface (`mqlaunch`)
* `system/` = OS-level tweaks
* `automation/` = workflows

👉 Tools power everything, but remain independently usable.

---

## ⚡ Philosophy

* simple scripts > complex frameworks
* reusable > one-off hacks
* safe automation > manual steps
* evolve tools without breaking workflows

---

## 🔮 Next Steps

* integrate release flow into `mqlaunch`
* expand CLI toolset
* add validation / diagnostics tools
* improve automation pipelines

---

💡 Tip: If something becomes useful more than once — it belongs in `tools/`.

