# Dashboards

This folder contains compact dashboard-style terminal views for `macos-scripts`.

These scripts are meant to give a fast project or system overview without dropping you into a larger interactive menu first.

## Purpose

The dashboard layer is useful when you want a quick status screen for:

- project health
- repo state
- key tool availability
- backup visibility
- important paths and support resources

It is designed to be readable at a glance and fit naturally into the broader `mqlaunch` experience.

## Current Contents

```text
ui/dashboards/
├── mq-dashboard.sh   # project status console
└── README.md
```

## mq-dashboard.sh

`mq-dashboard.sh` is a project status dashboard for `macos-scripts`.

It reports on things such as:

- repository path and branch
- git dirty/clean state
- latest commit and remote URL
- presence of core scripts like `mqlaunch.sh`
- availability of tools such as `rg`, `bat`, `jq`, `gh`, and `btop`
- latest tweak-backup locations
- key project paths such as the guide URL and UI library

## How It Works

The dashboard script:

- loads shared UI helpers from `ui/terminal-ui/mq-ui.sh`
- checks important project files and commands
- gathers lightweight git and filesystem status
- renders the result as a terminal dashboard

This keeps the presentation layer separate from launcher logic while still making the output feel consistent with the rest of the project.

## Why This Folder Exists

Dashboards are slightly different from menus and launchers:

- `launchers/` are entry points
- `menus/` are interactive navigation layers
- `dashboards/` are focused status views

That separation makes it easier to build overview screens without mixing them into routing code.

## Typical Use Cases

- sanity-check the project environment
- get a quick repo and tooling overview
- inspect backup presence
- open a polished status view before diving into deeper workflows

## Design Principles

- concise over noisy
- status-first presentation
- reusable UI primitives
- useful at a glance
- easy to call from other scripts later
