# macos-scripts

⚡ **Turn your macOS terminal into a fast, modular command center**

Run your workflows, monitor your system, and manage your projects — all from a single launcher.
Built for speed. Designed to evolve.

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

## 🚀 Why this exists

Most terminal setups fall into one of two traps:

* **Too minimal** → no real productivity gain
* **Too complex** → hard to maintain

**macos-scripts** aims for the middle:

* simple to install
* fast to use
* modular by design
* easy to extend over time

---

## 🧩 What you get

* ⚡ **mqlaunch** — central command launcher
* 📊 **Performance** — system health & monitoring
* 🛠 **Dev** — git + repo workflows
* 📦 **Tools** — scripts, CLI utilities, guides
* 🔌 **Modular architecture** — evolve without breaking

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

## 🚀 Try this first

```bash
mqlaunch perf
```

Press:

* `1` → Overview
* `2` → Health score
* `8` → Snapshot
* `9` → Live monitoring

Then explore:

```bash
mqlaunch dev
mqlaunch tools
```

---

## 🧠 Core Commands

```bash
mqlaunch        # Open launcher
mqlaunch perf   # System performance
mqlaunch dev    # Dev / git workflows
mqlaunch tools  # Tools & scripts
```

---

## 🏗️ Project Structure

```
macos-scripts/
├── ai-prompts/        # AI workflows & prompts
├── automation/        # automation scripts
├── backups/           # snapshots & reports
├── docs/              # GitHub Pages
├── system/            # macOS tweaks & utilities
├── terminal/
│   ├── bridges/       # legacy → v1 routing
│   ├── launchers/     # production launcher
│   └── mqlaunch-v1/   # modular v1 system
├── tools/             # reusable scripts & guides
├── ui/                # terminal UI & dashboards
└── install.sh
```

---

## 🧠 Architecture

This project uses a **safe migration model**:

* legacy launcher stays stable
* new features built in **v1 modules**
* bridges route commands safely
* no risky rewrites

👉 Result: evolve fast without breaking your workflow

---

## 🔧 Modules

### ⚡ Performance

* system overview
* health score
* CPU / memory analysis
* disk usage
* network info
* battery status
* snapshots
* quick watch

---

### 🛠 Dev

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
* repo structure overview
* README discovery

---

## 🎯 Use Cases

* bootstrap a new Mac
* speed up terminal workflows
* build a personal CLI workspace
* organize scripts into a real system
* learn shell scripting through practical tools

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
* move toward plugin-style modules
* remove legacy layer when stable

---

## 👤 Author

**Mattias Camner**

🌐 https://mcamner.github.io/macos-scripts/

---

## ⭐️ If you like it

Star the repo ⭐
Fork it 🍴
Build your own terminal system ⚡





