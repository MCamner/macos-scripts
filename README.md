# macos-scripts

<p align="center">
  <b>⚡ Turn your macOS terminal into a fast, modular command center</b><br>
  Run workflows, monitor your system, and manage your projects — all from one place.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-supported-black?style=for-the-badge&logo=apple">
  <img src="https://img.shields.io/badge/shell-zsh%20%7C%20bash-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/status-active-success?style=for-the-badge">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey?style=for-the-badge">
</p>

---

## 🎬 Demo

<p align="center">
  <img src="docs/demo.gif" alt="mqlaunch demo" width="800">
</p>

> 👉 Shows `mqlaunch perf`, live system overview, and navigation flow

---

## ⚡ What it feels like

```bash
mqlaunch
```

* Instant access to tools
* Real-time system insight
* Structured workflows instead of scattered scripts

👉 Think **Raycast for your terminal**

---

## 🧩 What you get

* ⚡ **mqlaunch** — central command launcher
* 📊 **Performance** — system health & monitoring
* 🛠 **Dev** — git + repo workflows
* 📦 **Tools** — scripts, CLI utilities, guides
* 🔌 **Modular architecture** — evolve without breaking

---

## 🚀 Quick Start

```bash
git clone https://github.com/MCamner/macos-scripts.git
cd macos-scripts
chmod +x install.sh
./install.sh
```

Then:

```bash
mqlaunch
```

---

## 🚀 Try this first

```bash
mqlaunch perf
```

Press:

* `1` → Overview
* `2` → Health score
* `8` → Snapshot
* `9` → Live monitoring

Then:

```bash
mqlaunch dev
mqlaunch tools
```

---

## 🧠 Core Commands

```bash
mqlaunch        # Open launcher
mqlaunch perf   # System performance
mqlaunch dev    # Dev workflows
mqlaunch tools  # Tools & scripts
```

---

## 🖥️ Preview

```
mqlaunch perf

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

---

## 🏗️ Project Structure

```
macos-scripts/
├── terminal/
│   ├── bridges/       # legacy → v1 routing
│   ├── launchers/     # production launcher
│   └── mqlaunch-v1/   # modular system
├── tools/             # scripts & guides
├── system/            # macOS tweaks
├── automation/        # workflows
├── ui/                # terminal UI
├── docs/              # demo + pages
└── install.sh
```

---

## 🧠 Architecture

This project uses a **safe migration model**:

* legacy launcher stays stable
* new modules built in **v1 architecture**
* bridges connect old → new
* no risky rewrites

👉 evolve fast without breaking workflows

---

## 🔧 Modules

### ⚡ Performance

* system overview
* health score
* CPU / memory
* disk usage
* network info
* battery status
* snapshots
* live monitoring

### 🛠 Dev

* repo health
* git status / pull / push
* commit history
* branch overview
* repo navigation

### 📦 Tools

* scripts & CLI tools
* terminal guide
* repo structure view
* README discovery

---

## 🎯 Use Cases

* bootstrap a new Mac
* speed up terminal workflows
* build a personal CLI workspace
* organize scripts into a real system

---

## 🧠 Philosophy

* simple > complex
* practical > theoretical
* fast > perfect
* modular evolution > rewrites

---

## 🗺️ Roadmap

* unify UI helpers
* expand automation
* improve CLI UX
* plugin-style modules
* remove legacy layer

---

## 👤 Author

**Mattias Camner**
🌐 https://mcamner.github.io/macos-scripts/

---

## ⭐️ If you like it

Star ⭐
Fork 🍴
Build your own terminal system ⚡






