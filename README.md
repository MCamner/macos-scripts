# macos-scripts

⚡ A modular CLI for structured terminal workflows on macOS

Turn scattered shell scripts into one clean command system.

---

<p align="center">
  <img src="docs/demo.gif" alt="mqlaunch demo" width="900"/>
</p>

---

## 💡 What this is

**macos-scripts** is a lightweight CLI toolkit that organizes terminal workflows into a structured, repeatable system.

Instead of remembering multiple commands:

```bash
top
df -h
ps aux | sort -nrk 3 | head
./tools/scripts/system-check.sh
```

You run:

```bash
mqlaunch perf
```

---

## 🚀 Quick start

```bash
git clone https://github.com/MCamner/macos-scripts.git
cd macos-scripts
chmod +x install.sh
./install.sh
mqlaunch
```

---

## 🎯 Core idea

> One command → structured workflows → repeatable execution

- One entrypoint: `mqlaunch`
- Clear workflow categories (Dev, System, Performance, Tools)
- Works both as menu and direct CLI
- Built for real-world terminal usage

---

## 🧠 Why this exists

Most environments don’t lack tools —  
they lack structure.

Typical problems:

- scripts scattered across folders  
- commands hard to discover  
- inconsistent execution  
- reliance on memory or tribal knowledge  

This project solves that by turning:

> **useful chaos → usable system**

---

## 🧩 How it works

```text
User → mqlaunch → Workflows → Scripts → System
```

- `mqlaunch` = control layer  
- workflows = structure  
- scripts = execution  
- system = environment  

---

## 🧰 Common commands

```bash
mqlaunch              # open main menu
mqlaunch perf         # performance tools
mqlaunch system check # system health check
mqlaunch dev          # developer workflows
mqlaunch tools        # utilities
mqlaunch demo         # demo mode
```

---

## 🎬 Demo

```bash
mqlaunch demo
```

---

## 🖼️ Screenshots

### Main Menu
<p align="center">
  <img src="docs/screenshots/main-menu.png" alt="Main Menu" width="700"/>
</p>

### Performance Menu
<p align="center">
  <img src="docs/screenshots/performance-menu.png" alt="Performance" width="700"/>
</p>

### Release Flow
<p align="center">
  <img src="docs/screenshots/release-flow.png" alt="Release Flow" width="700"/>
</p>

---

## 🧱 Project structure

```text
macos-scripts/
├── bin/               # CLI entrypoints
├── terminal/          # menus, launchers, themes
├── tools/             # scripts and utilities
├── system/            # macOS helpers
├── automation/        # repeatable workflows
└── ui/                # terminal UI components
```

---

## ⚖️ Design principles

- Keep it simple  
- Prefer structure over more tools  
- Optimize for real usage, not theory  
- Make workflows repeatable  
- Reduce cognitive load  

---

## 📈 What you get

- Faster access to useful commands  
- Consistent execution  
- Better discoverability  
- Foundation for automation  

---

## 📄 License

MIT
