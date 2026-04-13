# macos-scripts

> Turn scattered macOS shell scripts into one clean command system.

[![Platform](https://img.shields.io/badge/platform-macOS-black)](#macos-scripts)
[![Shell](https://img.shields.io/badge/shell-zsh%20%2B%20bash-1f6feb)](#-quick-start-30-seconds)
[![License](https://img.shields.io/badge/license-MIT-2ea44f)](#license)

---

## ⚡ One command instead of many

```bash
top
df -h
ps aux | sort -nrk 3 | head
./tools/scripts/system-check.sh
```

becomes:

```bash
mqlaunch perf
```

---

## 🚀 Quick start (30 seconds)

```bash
git clone https://github.com/MCamner/macos-scripts.git
cd macos-scripts
chmod +x install.sh
./install.sh && mqlaunch
```

---

## 🎬 Demo

```bash
mqlaunch demo
```

![mqlaunch demo](docs/demo.gif)

---

## 🧠 What you get

* One entrypoint: `mqlaunch`
* Structured workflows
* Repeatable diagnostics
* Menu + command mode
* Modular CLI system
* Faster discovery than separate scripts

---

## 🧱 Why

Scripts get messy fast.

This gives you:

* structure
* reuse
* clarity

---

## 🧰 Common commands

```bash
mqlaunch              # open the main menu
mqlaunch perf         # performance tools
mqlaunch system check # run a system health check
mqlaunch dev          # developer workflows
mqlaunch tools        # utility commands
mqlaunch demo         # demo mode
```

---

## 🎯 Why It Exists

Most script collections break down over time:

* commands get scattered
* workflows live in memory
* useful scripts become harder to discover
* maintenance gets harder than the automation

This repo solves that with one clear entrypoint, modular menus, and repeatable workflows.

---

## 🔍 More Examples

```bash
mqlaunch
mqlaunch system check
mqlaunch release notes
mqlaunch theme-macos
```

Use it in both menu mode and direct command mode.

---

## 🖼️ Screenshots

### Main Menu

![Main Menu](docs/screenshots/main-menu.png)

### Performance Menu

![Performance](docs/screenshots/performance-menu.png)

### Release Flow

![Release](docs/screenshots/release-flow.png)

---

## 🧱 Architecture

```text
macos-scripts/
├── bin/               # CLI entrypoints
├── terminal/          # launchers, menus, themes, bridges
├── tools/             # scripts and CLI utilities
├── system/            # macOS-focused helpers and tweaks
├── automation/        # repeatable workflows
└── ui/                # terminal UI building blocks
```

---

## License

MIT
