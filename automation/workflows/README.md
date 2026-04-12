# Workflows

Project-oriented workflow scripts for `macos-scripts`.

This folder contains higher-level automation that bundles several actions into one repeatable flow.

## Included

### `project-boot.sh`

Bootstraps a project workspace by:

- validating the project directory
- opening the project folder
- opening the repo URL
- opening `README.md` when present
- starting a Terminal session in the project
- opening VS Code when available

### `project-check.sh`

Runs a quick health check for a project workspace by verifying:

- project directory exists
- git repo is present
- working tree state
- upstream and remotes
- common project files such as `README.md`, `VERSION`, and `CHANGELOG.md`
- key local scripts such as `bin/mqlaunch` and `tools/scripts/test-all.sh`

## Usage

From the repo root:

```bash
bash automation/workflows/project-boot.sh
bash automation/workflows/project-check.sh
```

With custom values:

```bash
bash automation/workflows/project-boot.sh "my-project" "$HOME/my-project" "https://github.com/example/my-project"
bash automation/workflows/project-check.sh "my-project" "$HOME/my-project"
```

## Relationship to mqlaunch

Workflows can be launched:

- directly from `automation/workflows/`
- from `mqlaunch workflows`

Useful launcher entrypoints:

- `mqlaunch workflows`
- `mqlaunch workflows boot`
- `mqlaunch workflows check`

The goal is to keep workflow logic here and let `mqlaunch` act as the entry surface.
