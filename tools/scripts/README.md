# Scripts

System utilities, diagnostics, and workflow helpers for **macos-scripts**.

This directory contains **active runtime tools** used by both:
- direct CLI usage
- mqlaunch menus and workflows

---

## 🎯 Purpose

Provide fast, reliable tools for:

- system diagnostics  
- observability  
- troubleshooting  
- workflow support  

These scripts are designed to be:

- safe to run  
- useful standalone  
- easy to integrate into mqlaunch  

---

## 📦 Contents

```text
tools/scripts/
├── doctor.sh                # environment readiness check
├── mission-control.sh       # system overview (cockpit view)
├── overseer.sh              # system/process monitoring
├── network-ghost.sh         # network diagnostics
├── vault-scan.sh            # scan for secrets / config issues
├── system-check.sh          # basic system validation
├── create-debug-bundle.sh   # generate debug snapshot
├── blackout.sh              # experimental display/UX tool
├── mqlaunch_desktop.sh      # desktop integration
├── test-*.sh                # test scripts
└── README.md
```

---

## 🚀 Usage

Run any script from repo root:

```bash
bash tools/scripts/<script-name>.sh
```

Examples:

```bash
bash tools/scripts/doctor.sh
bash tools/scripts/mission-control.sh
bash tools/scripts/network-ghost.sh
```

---

## 🧠 Key Tools

### 🩺 doctor
Checks environment readiness.

- validates tools (git, brew, etc.)
- checks repo state
- highlights issues with fixes  

---

### 🖥 mission-control
Live system overview.

- CPU / memory / disk  
- network / IP  
- battery  
- git status  
- top processes  

---

### 👁 overseer
Process and system monitoring.

- tracks resource usage  
- helps identify bottlenecks  

---

### 🌐 network-ghost
Network diagnostics tool.

- IP / gateway  
- connectivity insights  

---

### 🔐 vault-scan
Security-oriented scan.

- detects sensitive files / config issues  
- useful before commits or sharing  

---

### 📦 create-debug-bundle
Creates a snapshot for troubleshooting.

- system state  
- logs / environment info  

---

## 🧪 Tests

Scripts prefixed with `test-` are used for:

- validating mqlaunch flows  
- smoke testing tools  

Run all tests:

```bash
bash tools/scripts/test-all.sh
```

---

## ⚠️ Notes

- These scripts are part of the **active toolchain**  
- Deprecated or one-off scripts are moved to:

```text
tools/legacy/
```

- CLI-style tools live in:

```text
tools/cli/
```

---

## 🔗 How it fits

- `tools/scripts/` → core runtime tools  
- `tools/cli/` → user-facing commands  
- `terminal/` → mqlaunch UI  
- `automation/` → workflows  

👉 Scripts power the system — mqlaunch exposes them.

---

## ⚡ Philosophy

- fast > complex  
- observable > opaque  
- reusable > one-off  
- terminal-first  

---

💡 Tip:  
If a script is useful more than once, it belongs here.# macos-scripts 🚀

A curated collection of utility scripts designed to automate system tweaks, manage installations, and enhance the macOS power-user experience.

## 📁 Repository Structure

The core logic of this repository is located in the `tools/scripts` directory:

- `tools/scripts/boot-maker.sh`: A powerful utility to create bootable Linux USB drives. Automatically detects system architecture (Intel vs. Apple Silicon) and supports Asahi Linux installation for M-series Macs.
- `tools/scripts/mqlaunch_desktop.sh`: Custom launcher/desktop integration script.
- `tools/scripts/patch-*.sh`: A series of specialized patching scripts for UI tweaks, theme management, and dashboard enhancements.
- `tools/scripts/system-check.sh`: Basic health and environment verification.

## 🛠 Installation & Usage

To use these scripts, clone the repository and ensure the files have execution permissions:

```bash
# Clone the repository
git clone [https://github.com/MCamner/macos-scripts.git](https://github.com/MCamner/macos-scripts.git)
cd macos-scripts
```

# Make the scripts executable
chmod +x tools/scripts/*.sh

---

## Purpose

Keep reusable support scripts in one place.

## Contents

This directory contains patch scripts, helper utilities, and maintenance scripts used to update or support other parts of the project.

Examples include:

* patch scripts for extending `mqlaunch`
* helper scripts for UI integration
* maintenance scripts such as `system-check.sh`

## How to run

### Run a patch script

From the project root:

`bash tools/scripts/<script-name>.sh`

### Run the system check

From the project root:

`bash tools/scripts/system-check.sh`

## Notes

Scripts in this directory should stay focused, reusable, and safe to run from the terminal.
