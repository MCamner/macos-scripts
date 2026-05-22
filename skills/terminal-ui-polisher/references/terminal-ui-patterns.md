# Terminal UI Patterns

## Pattern 1: Main menu

```text
MQ LAUNCH
────────────────────────────────────────────────────────────
Host: Zephyr   User: mansys   Mode: Main

CORE
  1. Workflows        2. System
  3. Git              4. Release
  5. Dev              6. Help

QUICK ACCESS
  p. Performance      n. Network
  h. Health Check     a. Apps

COMMANDS
  /doctor             /scan
  /review             /atlas

Status: ready
Select option:
```

## Pattern 2: Doctor output

```text
MQ DOCTOR
────────────────────────────────────────────────────────────

SYSTEM
  ✔ Shell              zsh
  ✔ Repo               clean
  ⚠ Dependencies       2 missing
  ✖ GitHub CLI         not authenticated

RECOMMENDED ACTION
  Run: gh auth login

Status: warning
```

## Pattern 3: Command result

```text
RESULT
────────────────────────────────────────────────────────────
✔ Completed: release dry-run

Changed:
  - VERSION
  - CHANGELOG.md
  - README badge

Next:
  git status
```

## Pattern 4: Safe destructive action

```text
DANGER ZONE
────────────────────────────────────────────────────────────
You are about to delete local cache files.

Path:
  ~/.cache/mqlaunch

This cannot be undone.

Type DELETE to continue:
```

## Pattern 5: Empty state

```text
NO RESULTS
────────────────────────────────────────────────────────────
No matching repositories found.

Try:
  - Check the search term
  - Run: mq repo refresh
  - Use: mq repo list
```
