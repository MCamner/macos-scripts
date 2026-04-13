# macos-scripts
> ⚡ A modular CLI for structured terminal workflows on macOS

> Turn scattered macOS shell scripts into one clean command system.

[![Platform](https://img.shields.io/badge/platform-macOS-black)](#)
[![Shell](https://img.shields.io/badge/shell-zsh%20%2B%20bash-1f6feb)](#)
[![License](https://img.shields.io/badge/license-MIT-2ea44f)](#)

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
./install.sh
mqlaunch
```

---

## 🎬 Demo

```bash
mqlaunch demo
```

![mqlaunch demo](docs/demo.gif)

---

## 🔥 Highlight: System check

```bash
mqlaunch system check
```

Run a full system overview in one command:

* CPU usage
* memory usage
* disk status
* network info
* environment checks

No need to remember multiple commands.

👉 One command → full visibility.

---

## 🧠 What you get

* One entrypoint: `mqlaunch`
* Structured workflows
* Repeatable diagnostics
* Menu + command mode
* Modular CLI system
* Faster discovery than separate scripts

---

## 🧰 Common commands

```bash
mqlaunch                 # open main menu
mqlaunch perf            # performance tools
mqlaunch system check    # system health check
mqlaunch dev             # developer workflows
mqlaunch tools           # utility commands
mqlaunch demo            # demo mode
```

---

## 🔍 More examples

```bash
mqlaunch
mqlaunch system check
mqlaunch release notes
mqlaunch theme-macos
```

Works both as:

* interactive menu
* direct command interface

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

## 🧭 Why

Scripts get messy fast.

`mqlaunch` gives you:

* structure
* reuse
* clarity
* repeatable workflows

---

## 📄 License

MIT
