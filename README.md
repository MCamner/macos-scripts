# macos-scripts

<p align="center">
  <b>Turn a folder of shell scripts into a usable macOS command system.</b><br>
  <code>mqlaunch</code> gives you one entrypoint for workflows, system insight, project utilities, and repeatable release tasks.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-supported-black?style=for-the-badge&logo=apple">
  <img src="https://img.shields.io/badge/shell-zsh%20%7C%20bash-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/status-active-success?style=for-the-badge">
  <img src="https://img.shields.io/badge/version-0.1.3-informational?style=for-the-badge">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey?style=for-the-badge">
</p>

`macos-scripts` is a practical terminal toolkit for people who live in macOS and want faster, cleaner, more repeatable command-line workflows.

At the center is `mqlaunch`: a modular launcher that brings together performance checks, repo utilities, project workflows, login helpers, shortcuts, and release automation behind a single command surface.

This project is not just a collection of scripts. It is an attempt to solve a common problem: useful shell tools often grow into a messy pile of one-off commands, inconsistent entrypoints, and hard-to-maintain logic. `macos-scripts` turns that into a structured system.

---

## Demo

<p align="center">
  <img src="docs/demo.gif" alt="mqlaunch demo" width="800">
</p>

> Shows the `mqlaunch` command surface and main workflow menu.

---

## Why this project exists

Most personal script collections break down in predictable ways:

* commands are scattered across folders
* workflows live in memory instead of in tooling
* one useful script turns into twenty unrelated ones
* maintenance becomes harder than the automation itself

`macos-scripts` addresses that by giving the toolset:

* one clear entrypoint
* modular menus instead of one giant shell file
* reusable workflows for recurring tasks
* safer release handling with dry-run and rollback support

If you like the idea of "Raycast for your terminal", that is the closest shorthand.

---

## What it gives you

* `mqlaunch` as a central launcher for day-to-day terminal work
* performance and system observability from the command line
* structured menus for workflows, tools, repo operations, and automation
* release tooling built for repeatability instead of manual version juggling
* a modular shell architecture that can grow without collapsing into script sprawl

---

## Quick Start

```bash
git clone https://github.com/MCamner/macos-scripts.git
cd macos-scripts
chmod +x install.sh
./install.sh
mqlaunch
```

Useful entry points:

```bash
mqlaunch perf
mqlaunch git
mqlaunch workflows
mqlaunch release
mqlaunch login
mqlaunch shortcuts
```

---

## Try this first

Start with performance mode:

```bash
mqlaunch perf
```

Good first actions:

* `1` for overview
* `2` for health score
* `8` for a snapshot
* `9` for live monitoring

Then explore:

```bash
mqlaunch dev
mqlaunch tools
mqlaunch workflows
```

---

## Core Commands

```bash
mqlaunch            # open launcher
mqlaunch perf       # system performance and monitoring
mqlaunch dev        # prompt tools and repo helpers
mqlaunch git        # git workspace actions
mqlaunch tools      # tools, scripts, and guides
mqlaunch workflows  # project workflows
mqlaunch release    # release menu
mqlaunch login      # login and session helpers
mqlaunch shortcuts  # shortcut-related actions
```

---

## What this shows technically

This repo is useful on its own, but it is also intended to demonstrate how I build operational tooling:

* turn fragmented utilities into a coherent product surface
* design for repeatability, not just convenience
* keep shell tooling modular enough to evolve safely
* make terminal UX discoverable instead of relying on tribal knowledge

That matters because the real challenge is usually not writing one script. It is making many small tools work together cleanly over time.

---

## Architecture

The launcher follows a modular model:

* `bin/mqlaunch` is the user-facing entrypoint
* `terminal/launchers/mqlaunch.sh` coordinates the experience
* `terminal/menus/` contains extracted interactive flows
* `automation/` holds workflow scripts such as login and shortcuts
* bridges and `mqlaunch-v1` remain where compatibility still matters

This keeps new capabilities from being stuffed into one oversized launcher script.

---

## Release Workflow

Release handling is built around `tools/release.sh` so versioning is safer and more repeatable.

Preview a release:

```bash
./tools/release.sh --dry-run 0.1.3
```

Run a release:

```bash
./tools/release.sh 0.1.3
```

Included in the flow:

* version sync across `VERSION` and `README`
* changelog validation
* git commit and tag creation
* rollback support on failure

---

## Preview

```text
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

## Project Structure

```text
macos-scripts/
├── bin/               # user-facing entrypoints
├── terminal/
│   ├── launchers/     # main launcher
│   ├── menus/         # extracted menu modules
│   ├── bridges/       # compatibility bridges
│   └── mqlaunch-v1/   # legacy compatibility layer
├── tools/             # scripts and guides
├── system/            # macOS tweaks
├── automation/        # login, shortcuts, workflows
├── ui/                # terminal UI
├── docs/              # demo and pages
└── install.sh
```

---

## Good Fit For

* people building a personal command-line workspace on macOS
* developers or operators who want one command surface for recurring tasks
* anyone tired of maintaining a growing pile of disconnected shell scripts

---

## Philosophy

* simple over clever
* practical over theoretical
* repeatable over fragile
* modular evolution over rewrites

---

## Roadmap

* GitHub release integration with `gh`
* stronger release validation
* deeper `mqlaunch release` integration
* plugin-style modules
* continued cleanup of legacy compatibility paths

---

## Author

**Mattias Camner**  
https://mcamner.github.io/macos-scripts/

---

## ⭐️ If you like it

Star ⭐
Fork 🍴
Build your own terminal system ⚡
