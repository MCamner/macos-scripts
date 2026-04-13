# Themes

Theme-related files for terminal appearance and shell experience.

This folder contains both:

- **zsh prompt themes**
- **theme switching tools**
- **UI theme management for shared terminal modules**

---

## Overview

There are two separate theme tracks here.

## Available ZSH Themes

The following theme variants are available via the theme switcher:

- `macos` — Clean Apple-inspired blue/gray theme (recommended)
- `minimal` — Low-noise, distraction-free terminal
- `ice` — Cool cyan/blue look
- `amber` — Warm classic terminal tone
- `green` — Traditional green-on-dark style

The current fallback default in `mq-zsh-theme-v3.zsh` is `amber`, while `macos` is the recommended starting point.

## Usage

Open the interactive theme menu:

```bash
mqlaunch theme
```

Apply a theme directly:

```bash
mqlaunch theme-macos
```

Check current theme:

```bash
mqlaunch theme-current
```

Reset the launcher-managed theme lines from `.zshrc`:

```bash
mqlaunch theme-reset
```

### 1. ZSH shell themes

These change the actual shell prompt in `zsh`, including:

- prompt layout
- colors
- git branch display
- status indicators
- command duration
- terminal title behavior

### 2. MQ UI themes

These affect the visual style used by scripts that rely on:

```bash
ui/terminal-ui/mq-ui.sh
