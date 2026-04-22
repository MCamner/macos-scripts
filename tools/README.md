# Tools

Reusable scripts, CLI utilities, and release automation for the macos-scripts project.

This folder contains standalone tools — things you can run directly, reuse across modules, or use outside mqlaunch.

---

## 🎯 Purpose

Keep powerful, reusable building blocks in one place:

* run tools directly from terminal
* support mqlaunch workflows
* enable safe automation (including releases)

---

## 📦 Contents

```
tools/
├── cli/                  # user-facing CLI tools
├── scripts/              # system, diagnostics, and utility scripts
├── legacy/               # archived/old scripts (patches, backups)
├── mac-terminal-guide/   # terminal guide source
├── onboarding.sh         # onboarding/setup helper
└── README.md
```

---

## 🚀 Release Automation

Safe, repeatable release workflow:

```
release.sh
```

Run from repo root:

```bash
./release.sh --dry-run 0.1.5
./release.sh 0.1.5
```

What it handles:

* updates `VERSION`
* updates README version badge
* validates `CHANGELOG.md`
* creates commit + tag
* pushes to GitHub
* rolls back changes on failure

👉 Designed to prevent broken or partial releases.

---

## 🧠 CLI Tools

Run from repo root:

```bash
bash tools/cli/<tool>.sh
```

Examples:

* `boot-maker.sh` → create bootable USB (Intel / Apple Silicon / Asahi support)
* `ai-mode.sh` → AI workflow helper

Used for:

* user-triggered workflows
* standalone utilities
* integration with mqlaunch

---

## 🛠 Scripts

Located in:

```
tools/scripts/
```

These are reusable system and diagnostic tools.

Examples:

* `doctor.sh` → environment readiness check
* `system-check.sh` → basic system validation
* `network-ghost.sh` → network diagnostics
* `vault-scan.sh` → scan for sensitive data / config issues
* `create-debug-bundle.sh` → generate debug snapshots

Run directly:

```bash
bash tools/scripts/<script-name>.sh
```

---

## 🗃 Legacy

```
tools/legacy/
```

Contains:

* old patch scripts
* backups (`.bak`)
* deprecated utilities

👉 Not part of the active system — kept for reference only.

---

## 📚 Terminal Guide

Source:

```
tools/mac-terminal-guide/
```

Generated HTML:

```
docs/mac-terminal-guide.html
```

Used for:

* onboarding
* documentation
* learning terminal workflows

---

## 🔗 How it fits the system

* `tools/` = reusable building blocks
* `terminal/` = user interface (mqlaunch)
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

* integrate release flow into mqlaunch
* expand CLI toolset
* improve diagnostics (doctor, vault-scan, network)
* strengthen automation pipelines

---

💡 Tip:
If something becomes useful more than once — it belongs in `tools/`.
