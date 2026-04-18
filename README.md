# macos-scripts ⚡

![macOS](https://img.shields.io/badge/platform-macOS-black)
![Shell](https://img.shields.io/badge/shell-zsh%20%2B%20bash-1f6feb)
![License](https://img.shields.io/badge/license-MIT-2ea44f)
![Status](https://img.shields.io/badge/status-active-success)

**Turn scattered shell commands into structured workflows**

Stop memorizing commands. Start running workflows.

---

## 🚀 Quick start

### Option 1 — Install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/MCamner/macos-scripts/main/install.sh | bash
```

### Option 2 — Clone

```bash
git clone https://github.com/MCamner/macos-scripts.git
cd macos-scripts
./install.sh
```

---

## ⚡ First run

```bash
mqlaunch doctor
```

This will:

* verify your environment
* check required dependencies
* validate your setup
* highlight issues with clear fixes

---

## 🚦 Then explore

```bash
mqlaunch
```

* browse workflows via the interactive menu
* or run commands directly (`perf`, `system`, `dev`, `tools`)

---

## ⚡ One command instead of many

Instead of:

```bash
top
df -h
ps aux | sort -nrk 3 | head
./tools/scripts/system-check.sh
```

Run:

```bash
mqlaunch perf
```

---

## 🎯 What this solves

Most environments don’t lack tools — they lack structure.

This project turns:

> useful chaos → usable system

---

## 🧠 Core idea

**One command → structured workflows → repeatable execution**

* single entrypoint: `mqlaunch`
* organized workflows (Dev, System, Performance, Tools)
* works as menu and direct CLI

---

## 🧰 Common commands

```bash
mqlaunch
mqlaunch perf
mqlaunch system check
mqlaunch dev
mqlaunch tools
mqlaunch demo
```


---
## 🩺 Health check

Before diving into workflows, verify your environment.

Run:

mqlaunch doctor

What it does:

- checks required tools (git, brew, node, python, jq)
- validates repo state (branch, dirty tree, required files)
- evaluates workflow readiness (Git, Release, Dev, System)
- highlights issues and gives actionable recommendations

Example use:

mqlaunch doctor

→ quickly understand if your environment is ready  
→ fix issues before running workflows  
→ reduce debugging time and surprises

💡 Tip  
Run this after install or when something feels off.

---

## 🎬 Demo

```bash
mqlaunch demo
```

---

## 🖼️ Screenshots

### Main Menu
<p align="center">
  <img src="docs/screenshots/main-menu.png" width="700"/>
</p>

### Performance Menu
<p align="center">
  <img src="docs/screenshots/performance-menu.png" width="700"/>
</p>

### Release Flow
<p align="center">
  <img src="docs/screenshots/release-flow.png" width="700"/>
</p>

---

## 🧱 Project structure

```text
macos-scripts/
├── bin/               # CLI entrypoints
├── terminal/          # menus, launchers, themes
├── tools/             # scripts and utilities
├── system/            # macOS helpers
├── automation/        # workflows
└── ui/                # terminal UI
```

---

## ⚖️ Design principles

- keep it simple  
- structure > more tools  
- optimize for real usage  
- make workflows repeatable  
- reduce cognitive load  

---

## 📈 Real use case

Example:

Instead of remembering 5–10 system commands during troubleshooting:

- open CLI  
- search commands  
- run manually  

You run:

```bash
mqlaunch system check
```

→ full system overview in one step

---

## 🔭 Roadmap

- workflow validation / health checks  
- plugin-style extensions  
- remote execution support  
- improved onboarding  

---

## 🤝 Contributing

PRs welcome.  
If you have ideas for workflows or improvements — open an issue.

---

## 📄 License

MIT
