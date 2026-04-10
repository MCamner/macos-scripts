# UI

Visual and interface-focused terminal components for the `macos-scripts` project.

## Purpose

Keep presentation, branding, and terminal experience separate from core script logic.

## Contents

* `terminal-ui/` — reusable terminal UI helpers and layout functions
* `ascii/` — ASCII visuals, branded headers, and dashboard modules
* `dashboards/` — compact dashboard-style views and status screens

## Design goals

The `ui/` layer should make command-line tools feel:

* clearer
* more consistent
* more polished
* more fun to use

## How it is used

UI modules in this directory are intended to be reused by launcher scripts, menus, and dashboard views.

Examples include:

* shared terminal layout helpers from `ui/terminal-ui/`
* branded ASCII headers from `ui/ascii/`
* status-oriented dashboard views from `ui/dashboards/`

## Notes

Keep UI concerns in this directory whenever possible instead of hardcoding presentation directly inside launcher or menu logic.

