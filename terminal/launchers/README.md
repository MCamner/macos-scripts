# Launchers

Launcher entrypoints for the `mqlaunch` command surface.

## Current launcher

- `mqlaunch.sh` — the primary launcher behind `bin/mqlaunch`

It supports both:

- menu mode via `mqlaunch`
- command mode via commands such as `mqlaunch system check`, `mqlaunch release notes`, and `mqlaunch demo`

## What lives here

- main launcher flow and entry bootstrap
- command routing and aliases
- dashboard / header integration
- shared actions used by menus
- demo mode
- theme menu integration

## Common commands

```bash
mqlaunch
mqlaunch demo
mqlaunch system
mqlaunch system check
mqlaunch dev
mqlaunch tools
mqlaunch release notes
```

## Run locally

```bash
chmod +x mqlaunch.sh
./mqlaunch.sh
./mqlaunch.sh demo
```

## Goal

Keep `mqlaunch` as one coherent entrypoint: easy to navigate, easy to script, and easy to evolve without losing consistency.

## Maintainer Note

Current routing is intentionally mixed:

- `dev` and `tools` are primary in the main launcher flow
- `performance` is still user-facing as a primary command, but its implementation currently lives behind the compatibility bridge

This is a deliberate choice.

`performance` already has a richer implementation in `terminal/mqlaunch-v1`, so it stays there until a first-class replacement in the main launcher is worth doing as a focused migration rather than a partial rewrite.
