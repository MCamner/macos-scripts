# macOS Tweaks Utility

A modular, script-based tweak system for macOS focused on **performance, clarity, and control**.

Designed to fit into the `macos-scripts` ecosystem and integrate cleanly with `mqlaunch`.

---

## ⚡ Overview

This tool lets you:

* Apply curated macOS tweaks via profiles
* Backup current system preferences before changes
* Revert safely using stored backups
* Preview changes using dry-run mode
* Inspect current system state

---

## 📁 Location

```
system/tweaks/macos-tweaks.sh
```

---

## 🚀 Quick Start

Make sure the script is executable:

```
chmod +x system/tweaks/macos-tweaks.sh
```

Run interactive menu:

```
./system/tweaks/macos-tweaks.sh menu
```

---

## 🧠 Commands

| Command         | Description                      |
| --------------- | -------------------------------- |
| `menu`          | Interactive menu                 |
| `status`        | Show current system tweak values |
| `backup`        | Save current settings            |
| `revert-latest` | Restore latest backup            |
| `dev`           | Developer-focused tweaks         |
| `clean`         | Minimal & clean UI tweaks        |
| `fast`          | Performance & workflow tweaks    |
| `workstation`   | Balanced daily-driver setup      |
| `all`           | Apply all tweak profiles         |

---

## 🧪 Safe Testing (Recommended)

Always start with:

```
./system/tweaks/macos-tweaks.sh all --dry-run
```

This shows exactly what will change without applying anything.

---

## 🧩 Profiles

### 👨‍💻 dev

Optimized for development:

* Show hidden files
* Show file extensions
* Faster keyboard repeat
* Dock auto-hide (instant)

---

### 🎯 clean

Cleaner UI experience:

* Minimal dock animations
* Reduced Finder noise
* No `.DS_Store` on network/USB

---

### ⚡ fast

Performance + productivity:

* Disable personalized ads
* Instant password lock after screensaver
* Dedicated screenshot folder

---

### 🖥 workstation

Balanced daily setup:

* Finder clarity (path/status bar)
* Dock tuned for productivity
* Security + usability balance

---

## 💾 Backup & Revert

Backup is automatically created before applying tweaks.

Manual backup:

```
./system/tweaks/macos-tweaks.sh backup
```

Revert to latest:

```
./system/tweaks/macos-tweaks.sh revert-latest
```

Backups are stored in:

```
~/.macos-tweaks-backup/
```

---

## 🔍 Status Inspection

View current system configuration:

```
./system/tweaks/macos-tweaks.sh status
```

---

## 🔌 mqlaunch Integration

Example integration:

```bash
tweaks) bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" menu ;;
tweaks-status) bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" status ;;
tweaks-workstation) bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" workstation ;;
tweaks-all) bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" all ;;
tweaks-revert) bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" revert-latest ;;
```

---

## ⚠️ Notes

* Uses `defaults write` → changes are system-level preferences
* Some changes require app restart (handled automatically)
* Behavior may vary slightly between macOS versions
* Always use `--dry-run` before applying on a new system

---

## 🧱 Design Philosophy

This is not a random tweak dump.

It is:

* Structured
* Reversible
* Scriptable
* Extensible

Think of it as:

> “Infrastructure-as-code for your macOS UX”

---

## 🔮 Future Ideas

* Additional profiles (minimal, secure, power-user)
* Per-setting revert
* JSON/YAML config support
* Remote deployment (MDM-style)

---

## 🤝 Contributing

Add tweaks by extending:

* `apply_*_tweaks()` functions
* `backup_selected()` mappings
* `show_status()` output

Keep it:

* Minimal
* Reversible
* Tested

---

## 🧠 Author

Part of the **macos-scripts** toolkit
Built for real-world usage, not theory.

---
