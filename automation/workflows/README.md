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

## Usage

From the repo root:

```bash
bash automation/workflows/project-boot.sh
```

With custom values:

```bash
bash automation/workflows/project-boot.sh "my-project" "$HOME/my-project" "https://github.com/example/my-project"
```

## Relationship to mqlaunch

Workflows can be launched:

- directly from `automation/workflows/`
- from `mqlaunch workflows`

The goal is to keep workflow logic here and let `mqlaunch` act as the entry surface.
