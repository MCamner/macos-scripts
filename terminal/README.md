# Terminal

Terminal-focused macOS tools and workflows.

This area contains the command-line control layer of the project: launchers, menu-driven tools, shared terminal UI, and terminal-specific themes.

---

## Overview

The `terminal/` section is where the project becomes a usable terminal environment rather than a loose collection of scripts.

It is designed for:

- launcher-driven workflows
- direct command mode
- menu-based terminal tools
- reusable terminal UI patterns
- modular expansion over time

---

## Structure

```text
terminal/
├── bridges/      # compatibility handoff to v1 where needed
├── launchers/    # primary mqlaunch entrypoints and routing
├── menus/        # shared menu modules used by the launcher
├── mqlaunch-v1/  # compatibility implementation still used by performance
├── themes/       # zsh themes and theme switching
└── README.md
```

## Recommended entrypoints

The current `mqlaunch` surface is built around one launcher with two modes:

- menu mode via `mqlaunch`
- direct mode via commands such as `mqlaunch system check`, `mqlaunch release notes`, and `mqlaunch demo`

Primary commands to know:

```bash
mqlaunch
mqlaunch demo
mqlaunch system
mqlaunch system check
mqlaunch perf
mqlaunch dev
mqlaunch git
mqlaunch tools
mqlaunch release notes
mqlaunch theme-macos
