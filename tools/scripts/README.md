# macos-scripts 🚀

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
