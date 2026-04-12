# ASCII UI

ASCII visuals, banners, and dashboard modules for **MQLAUNCH**.

This directory contains reusable terminal presentation layers used by the launcher and menu system. The goal is to make command-line workflows feel more polished, more readable, and more fun without adding unnecessary complexity.

## Purpose

The `ui/ascii/` folder exists to keep branding, dashboard rendering, and terminal identity separate from business logic.

Instead of hardcoding banners and dashboard layouts directly inside launcher scripts or menus, ASCII presentation modules live here and can be reused across the system.

This makes the project easier to:

- maintain
- theme
- test
- extend
- reuse across launcher modules

## Design goals

ASCII modules in this folder should aim for:

- strong terminal identity
- clean integration with launcher and menus
- reusable rendering functions
- minimal dependencies
- good readability in both narrow and wide terminals
- graceful fallback behavior

## Current files

### `mq-banner.sh`
A reusable banner-style module for simple branded terminal headers.

### `mq-dashboard.sh`
An early reusable dashboard module focused on dynamic terminal status output.

### `mq-dashboard-v3.sh`
A cyberpunk / CRT-inspired dashboard with stronger visual identity and dynamic system metadata.

### `mqlaunch-dashboard-v4.sh`
Introduces a clearer widget-based dashboard style for **MQLAUNCH**.

### `mqlaunch-dashboard-v5.sh`
Adds adaptive layout support and dirty-file bars for Git-aware terminal dashboards.

### `mqlaunch-dashboard-v6.sh`
Extends the widget model with live shortcuts and a severity-oriented Git view.

### `mqlaunch-dashboard-v7.1.sh`
The current polished branded dashboard for **MQLAUNCH**, featuring:

- **MQ** in bright pink
- **LAUNCH** in darker pink
- adaptive layout
- Git-aware status widgets
- severity meter
- live shortcuts
- reusable header rendering for launcher and menus

### `mq-skull.txt`
A raw ASCII art asset that can be reused in experimental retro / themed views.

### `mq-bg-grid.txt`
A retro CRT / neon grid background for splash screens, idle states, or static terminal backdrops.

### `mq-bg-bbs.txt`
A BBS-inspired background with bulletin-board energy and clean 80s hacker-page vibes.

### `mq-bg-skullgrid.txt`
A darker cyber-skull background for dramatic retro overlays and experimental themed views.

### `mq-bg-miami-muse.txt`
A Blade Runner-style ASCII backdrop with neon noir skyline, rain, and retro-future city energy.

### `mq-bg-miami-muse.sh`
A colorized ANSI-rendered version of the Blade Runner-style backdrop for neon terminal output.

## Recommended usage

Example from `mqlaunch.sh`:

```bash
DASHBOARD_V71="$BASE_DIR/ui/ascii/mqlaunch-dashboard-v7.1.sh"
