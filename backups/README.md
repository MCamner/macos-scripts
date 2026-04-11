# Backups

This folder stores project-generated backups, snapshots, and support artifacts for `macos-scripts`.

It is the place where temporary safety copies and diagnostic exports are kept so the main workflow can move quickly without losing recoverability.

## What Lives Here

Typical contents include:

- prompt backups such as zipped copies of `ai-prompts/`
- launcher backups for older or stable `mqlaunch` versions
- debug bundles created for troubleshooting
- performance snapshots and reports

## Current Structure

```text
backups/
├── debug-bundles/         # exported support/debug bundles
├── launchers/             # mqlaunch backups and stable copies
├── performance-reports/   # saved performance snapshots
├── ai-prompts-*.zip       # prompt library backups
└── README.md
```

## Purpose

The goal of this folder is to make experimentation safer.

It helps when you want to:

- keep a restorable copy before changing `mqlaunch`
- save prompt libraries before major edits
- inspect previous system or performance snapshots
- attach debug information when something breaks

## Examples

Launcher backups:

```text
backups/launchers/mqlaunch-20260410-022926.sh.bak
backups/launchers/mqlaunch-v3.2-stable.sh
```

Prompt backups:

```text
backups/ai-prompts-20260330-011812.zip
```

Debug bundles:

```text
backups/debug-bundles/mqlaunch-bundle-2026-04-11_16-15-47.txt
```

Performance reports:

```text
backups/performance-reports/perf-snapshot-2026-04-10_22-22-09.txt
```

## How It Gets Used

Several scripts in the repo write to `backups/`, especially around:

- `mqlaunch` backup actions
- prompt backup flows
- debug/support bundle generation
- performance snapshot exports

This means the folder is expected to change over time and may contain many timestamped files.

## Notes

- contents are mostly generated artifacts, not hand-edited source files
- timestamps in filenames are intentional and make rollback easier
- older backups can be cleaned up manually when no longer useful
- some system-level backup flows in this repo use separate locations under your home directory and not this folder

## Recommendation

Treat `backups/` as a working safety net:

- keep important stable snapshots
- prune noisy old artifacts occasionally
- use it for rollback and troubleshooting, not as a primary source folder
