# macos-scripts

**Turn scattered shell utilities into a usable macOS command system.**

`macos-scripts` is a practical terminal toolkit for macOS that organizes workflows, automation, and system tools into a structured command interface.

At the center is **`mqlaunch`** — a modular CLI that gives you one operational surface for everyday terminal work.

---

## 🚀 What this is

This is not a collection of random scripts.

It is a **structured command system** for:

* terminal workflows
* repeatable automation
* system observability
* project and repo utilities
* release and operational tasks

The goal is simple:

> make useful scripts easier to use, extend, and trust.

---

## ⚡ Quick Example

Instead of this:

```bash
top
df -h
ps aux | sort -nrk 3 | head
./tools/scripts/system-check.sh
```

You use:

```bash
mqlaunch perf
```

And get a structured interface for diagnostics, monitoring, and snapshots.

---

## ⚡ Try this in 30 seconds

Run:

```bash
mqlaunch
mqlaunch system check
mqlaunch release notes
mqlaunch theme-macos
```

You can use it in both menu mode and direct command mode:

```text
mqlaunch                  -> open the main menu
mqlaunch system check     -> run a check directly
mqlaunch release notes    -> open release notes directly
mqlaunch theme-macos      -> apply the macOS theme
```

One quick performance example still looks like this:

```text
Performance Menu
1  Overview
2  Health score
3  Top CPU processes
4  Top memory processes
5  Disk usage
6  Network overview
7  Battery status
8  Create snapshot
9  Quick watch
b  Back
```

### What you get

* instant system visibility
* repeatable diagnostics
* structured command workflows

👉 This is the core idea:
**turn everyday terminal tasks into clean, reusable workflows**

---

## 🎬 Demo

![mqlaunch demo](docs/demo.gif)

Shows the `mqlaunch` command surface and navigation.

---

## 🎯 Demo Flow

```text
mqlaunch
  ↓
Select: Performance
  ↓
Run: Health → Snapshot → Monitor
  ↓
Jump to: Dev / Tools / Workflows
  ↓
Execute repeatable actions from one interface
```

👉 One entrypoint
👉 Multiple workflows
👉 No scattered commands

---

## 🖥️ Screenshots

### Main Menu

![Main Menu](docs/screenshots/main-menu.png)

### Performance Menu

![Performance](docs/screenshots/performance-menu.png)

### Release Flow

![Release](docs/screenshots/release-flow.png)

---

## 🧠 Why this exists

Most script collections break down over time:

* commands are scattered
* workflows live in memory
* scripts grow without structure
* maintenance becomes harder than the automation

This repo solves that by introducing:

* one clear entrypoint (`mqlaunch`)
* modular menus instead of script sprawl
* reusable workflows
* safer operational patterns

---

## 🔥 What you get

* `mqlaunch` as a central launcher
* structured workflows for daily terminal work
* system observability tools
* repo and automation utilities
* repeatable release flows
* modular architecture that scales

---

## 📌 Case: From Scripts to System

This project started as separate shell utilities.

It evolved into a **modular CLI system** centered around `mqlaunch`.

### Result

* consolidated scattered scripts into one command system
* introduced a clear entrypoint
* improved usability through menus
* enabled safer operations (dry-run, debug, rollback)
* made the system easier to extend

### Impact

Reduced friction in daily terminal workflows and created a foundation for scalable, repeatable automation.

📖 Full case:
https://github.com/MCamner/MCamner/blob/main/cases/macos-scripts.md

---

## 🔧 Getting Started

Clone:

```bash
git clone https://github.com/MCamner/macos-scripts.git
cd macos-scripts
```

Install:

```bash
chmod +x install.sh
./install.sh
```

Run:

```bash
mqlaunch
```

Or try demo mode:

```bash
mqlaunch demo
```

Or jump straight into command mode:

```bash
mqlaunch system check
mqlaunch release notes
mqlaunch theme-macos
```

---

## ⚙️ Useful Commands

```bash
mqlaunch
mqlaunch demo
mqlaunch system
mqlaunch system check
mqlaunch perf
mqlaunch dev
mqlaunch git
mqlaunch tools
mqlaunch workflows
mqlaunch release notes
mqlaunch theme
mqlaunch theme-macos
mqlaunch login
mqlaunch shortcuts
```

---

## 🧱 Architecture

```text
macos-scripts/
├── bin/               # CLI entrypoints (mqlaunch)
├── terminal/
│   ├── launchers/     # main launcher logic
│   ├── menus/         # modular menu system
│   ├── bridges/       # compatibility bridges
│   └── mqlaunch-v1/   # compatibility layer and reusable modules
│       ├── commands/  # v1 command handlers
│       ├── lib/       # shared v1 core + UI helpers
│       └── menus/     # v1 menu definitions
├── tools/             # scripts and utilities
├── system/            # macOS tweaks
├── automation/        # workflows (login, shortcuts)
├── ui/                # terminal UI components
├── docs/              # demo and screenshots
└── install.sh
```

---

## 🧩 Design Principles

* Practical over clever — focus on real workflows
* Structure over sprawl — everything fits into a system
* Repeatability matters — do it once, reuse it forever
* Usability is part of engineering — if it's hard to use, it's not done
* Growth without monolith — scale without breaking structure

---

## 🔍 Example Use Cases

* build a personal terminal workspace
* organize automation workflows
* reduce repeated command overhead
* create reusable CLI-driven tools
* improve discoverability of scripts

---

## 📈 Current Focus

* improving `mqlaunch` UX and structure
* refining menus and command discovery
* strengthening debug and release flows
* documenting patterns and workflows
* evolving toward a modular CLI system

---

## 🧠 What this demonstrates

This project shows how I approach system design:

* turning fragmented tools into cohesive systems
* designing for usability, not just execution
* building modular CLI architecture
* structuring workflows instead of scripts
* balancing speed, clarity, and maintainability

---

## 🧭 Philosophy

> Build things that work. Then make them easier to use. Then make them harder to break.

---

## 🌐 Links

* Repo: https://github.com/MCamner/macos-scripts
* Profile: https://github.com/MCamner
* Project Page: https://mcamner.github.io/macos-scripts/

---

## ⭐️ If you like it

* Star ⭐
* Fork 🍴
* Build your own terminal system ⚡
