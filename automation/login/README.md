# MQLogin

`mqlogin.sh` is a session boot script for `macos-scripts` that pairs nicely with `mqlaunch`.

Its job is to make the start of a work session feel fast and intentional by opening the project context you need and handing off to `mqlaunch`.

## What It Does

By default, `mqlogin.sh`:

- creates a timestamped log file
- detects the current `macos-scripts` project root
- opens the project folder
- opens Visual Studio Code if installed
- opens Terminal and starts `mqlaunch`

If `mqlaunch` is not available, it falls back to opening a terminal session in the project root and showing `git status`.

## Location

```text
automation/login/mqlogin.sh
```

## Run Directly

From the repo root:

```bash
bash automation/login/mqlogin.sh
```

You can also make sure it is executable and run it directly:

```bash
chmod +x automation/login/mqlogin.sh
./automation/login/mqlogin.sh
```

## Use Through mqlaunch

`mqlogin` is also wired into `mqlaunch`.

Examples:

```bash
mqlaunch login
mqlaunch login menu
mqlaunch login about
mqlaunch login check
```

`mqlaunch login` now opens an interactive Login / Session menu by default.

## Modes

`mqlogin.sh` supports three main modes:

- `menu` = launch the full `mqlaunch` menu
- `about` = show `mqlaunch about`, then hand off to the full menu
- `check` = run `mqlaunch check`, then hand off to the full menu

Default mode:

```bash
bash automation/login/mqlogin.sh
```

Explicit mode examples:

```bash
bash automation/login/mqlogin.sh menu
bash automation/login/mqlogin.sh about
bash automation/login/mqlogin.sh check
```

## Options

```text
--menu         Open full mqlaunch menu in Terminal
--about        Show mqlaunch about, then return
--check        Show mqlaunch check, then return
--inline       Run in the current terminal instead of opening Terminal.app
--no-finder    Do not open the project folder
--no-code      Do not open Visual Studio Code
--no-terminal  Do not open Terminal.app
--help         Show help
```

Example:

```bash
bash automation/login/mqlogin.sh about --inline --no-finder --no-code --no-terminal
```

## Logging

Logs are written to:

```text
~/.macos-scripts/logs/login/
```

Each run creates a timestamped log file so you can inspect how the session boot behaved.

## Why It Fits mqlaunch

`mqlogin` is designed as a clean entry point into the same workflow system as `mqlaunch`:

- launch context first
- tools second
- minimal friction
- graceful fallback if parts are missing

It works well as a manual “start my workspace” command, and it can also be used as the basis for a macOS login item or LaunchAgent later.
