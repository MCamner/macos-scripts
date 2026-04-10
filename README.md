# macos-scripts

⚡ **Turn your macOS terminal into a modular workflow hub**

A curated collection of macOS scripts, tools, launchers, and terminal utilities designed to speed up daily work, automate repetitive tasks, and provide a clean foundation for a personal CLI toolkit.

---

## 🚀 Why this exists

Most terminal setups fall into one of two traps:

* **Too minimal** → no real productivity gain
* **Too complex** → hard to maintain

**macos-scripts** aims for the middle:

* simple to install
* fast to use
* modular by design
* easy to expand over time

---

## 🧩 What you get

* **mqlaunch** — a terminal launcher for workflows, tools, and navigation
* **Performance tools** — system health, load, disk usage, snapshots
* **Dev tools** — git workflows, repo health, navigation helpers
* **Tools module** — access to scripts, CLI tools, and guides
* **Modular architecture** — legacy + v1 system running safely in parallel

---

## ⚡ Quick Start

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

## 🧠 Core Commands

### Launcher

```bash
mqlaunch
```

### Performance

```bash
mqlaunch perf
```

### Development

```bash
mqlaunch dev
mqlaunch git
```

### Tools

```bash
mqlaunch tools
```

---

## 🧪 Demo Flow (Recommended)

After install:

```bash
mqlaunch perf
```

Try:

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

## 🏗️ Project Structure

```text
macos-scripts/
├── ai-prompts/        # AI workflows & prompts
├── automation/        # automation scripts
├── backups/           # snapshots & backups
├── docs/              # GitHub Pages
├── system/            # macOS tweaks & system tools
├── terminal/
│   ├── bridges/       # legacy → v1 routing layer
│   ├── launchers/     # production launcher
│   └── mqlaunch-v1/   # modular v1 system
├── tools/             # reusable scripts & guides
├── ui/                # terminal UI / dashboards
└── install.sh
```

---

## 🧠 Architecture

This project uses a **safe migration model**:

* legacy launcher remains stable
* new modules are built in **v1 architecture**
* bridges connect old → new
* no risky rewrites

---

## 🔧 Modules

### ⚡ Performance

* system overview
* health score
* CPU / memory processes
* disk usage
* network info
* battery status
* snapshots
* quick watch

---

### 🛠️ Dev

* repo health
* git status / pull / push
* commit history
* branch overview
* repo navigation

---

### 📦 Tools

* tools directory navigation
* scripts / CLI access
* terminal guide
* repo structure view
* README discovery

---

## 🎯 Use Cases

* bootstrap a new Mac
* speed up terminal workflows
* build a personal CLI environment
* organize scripts into a real system
* learn shell scripting through real tools

---

## 🧠 Philosophy

* simple > complex
* practical > theoretical
* fast > perfect
* modular evolution > rewrites

---

## 🗺️ Roadmap

* unify UI helpers across modules
* expand automation workflows
* improve CLI UX
* evolve toward plugin-style modules
* remove legacy layer when stable

---

## 👤 Author

**Mattias Camner**

Project page:
https://mcamner.github.io/macos-scripts/

---

## ⭐️ If you like it

Star the repo, fork it, and build your own workflow system.




