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
├── overseer.sh              # system/process monitoring (interactive menu)
├── network-ghost.sh         # network diagnostics
├── port-scan.sh             # local TCP port listener scan
├── vault-scan.sh            # scan for secrets / config issues
├── system-check.sh          # basic system validation
├── srm.sh                   # Semantic Repository Memory assistant
├── create-debug-bundle.sh   # generate debug snapshot
├── document-functions.sh    # add comments above shell functions
├── brew-check.sh            # Homebrew health dashboard
├── cleanup.sh               # macOS cleanup (trash, downloads, caches)
├── focus.sh                 # Pomodoro focus timer with notifications
├── env-snap.sh              # environment snapshots (PATH, env, git, disk)
├── blackout.sh              # experimental focus / screen effect tool
├── mqlaunch_desktop.sh      # desktop integration
├── test-*.sh                # test scripts
├── pulse.sh                 # quick system pulse / lightweight status
└── README.md
```

---

## 🏷 Status

| Script | Category | Status | Description |
| ------- | -------- | -------- | ------------ |
| `doctor.sh` | Diagnostics | 🟢 Stable | Environment readiness check |
| `mission-control.sh` | Observability | 🟢 Stable | System overview |
| `overseer.sh` | Monitoring | 🟡 Beta | Interactive process monitor with search and kill |
| `network-ghost.sh` | Network | 🟢 Stable | Network diagnostics |
| `port-scan.sh` | Network | 🟢 Stable | Local TCP port listener scan |
| `vault-scan.sh` | Security | 🟢 Stable | Scan for secrets / config issues |
| `system-check.sh` | Diagnostics | 🟢 Stable | Basic system validation |
| `srm.sh` | AI / Repo memory | 🟡 Beta | Query a Semantic Repository Memory vector store with Responses API |
| `create-debug-bundle.sh` | Support | 🟢 Stable | Generate debug snapshot |
| `document-functions.sh` | Maintenance | 🟡 Beta | Add function comments |
| `brew-check.sh` | Maintenance | 🟢 Stable | Homebrew health dashboard |
| `cleanup.sh` | Maintenance | 🟢 Stable | macOS cleanup — trash, downloads, caches |
| `focus.sh` | Productivity | 🟢 Stable | Pomodoro focus timer with macOS notifications |
| `env-snap.sh` | Observability | 🟡 Beta | Environment snapshots — PATH, env, git, disk |
| `pulse.sh` | Observability | 🟡 Beta | Quick system pulse |
| `blackout.sh` | UX / Experimental | 🔴 Experimental | Focus effect tool |
| `mqlaunch_desktop.sh` | Integration | 🟡 Beta | Desktop helper |
| `test-*.sh` | Testing | 🟢 Stable | Test and validation scripts |

---

### Legend

- 🟢 **Stable** — safe to use, core functionality
- 🟡 **Beta** — works, but evolving
- 🔴 **Experimental** — unstable or exploratory

---

💡 Tip:
Stable tools are safe entry points.
Experimental tools are for exploration.

## 🚀 Usage

Run any script from repo root:

```bash
bash tools/scripts/SCRIPT_NAME.sh
```

Examples:

```bash
bash tools/scripts/doctor.sh
bash tools/scripts/mission-control.sh
bash tools/scripts/network-ghost.sh
```

### Command Cheat Sheet

```bash
# Check that the documentation helper has valid bash syntax
bash -n tools/scripts/document-functions.sh

# Preview which function comments would be added to one script
tools/scripts/document-functions.sh tools/scripts/scan.sh

# Add missing function comments to one script
tools/scripts/document-functions.sh --write tools/scripts/scan.sh

# Preview missing function comments for all scripts in this directory
tools/scripts/document-functions.sh tools/scripts

# Add missing function comments for all scripts in this directory
tools/scripts/document-functions.sh --write tools/scripts
```

---

## 🚦 Start here

These are the primary entry-point tools for this directory:

If you're new to `tools/scripts/`, start with these:

### 1. `doctor.sh`

Best first step.

Use it to:

- verify your environment
- detect missing tools
- check repo readiness

```bash
bash tools/scripts/doctor.sh
```

---

### 2. `mission-control.sh`

Best overview tool.

Use it to:

- get a live system snapshot
- review CPU, memory, disk, network, battery, and git status

```bash
bash tools/scripts/mission-control.sh
```

---

### 3. `network-ghost.sh`

Best for connectivity checks.

Use it to:

- inspect network basics
- troubleshoot IP, gateway, and connectivity issues

```bash
bash tools/scripts/network-ghost.sh
```

---

### 4. `vault-scan.sh`

Best before sharing or committing.

Use it to:

- detect sensitive files or risky config patterns
- reduce the chance of leaking secrets

```bash
bash tools/scripts/vault-scan.sh
```

---

### 5. `create-debug-bundle.sh`

Best when something is broken.

Use it to:

- capture a troubleshooting snapshot
- gather useful system and environment context

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
If a script is useful more than once, it belongs here.
