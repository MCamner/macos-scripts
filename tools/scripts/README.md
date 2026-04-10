# Scripts

Standalone helper scripts for the `macos-scripts` project.

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
