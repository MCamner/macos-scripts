---
name: shell-script-auditor
description: Audit changed Bash, Zsh, and POSIX shell scripts for syntax errors, unsafe patterns, portability problems, and missing smoke-test coverage. Use when shell files are created or modified, before committing shell changes, or when asked for a shell safety review.
---

# Shell Script Auditor

Audit shell changes without modifying or executing the scripts under review.

## Workflow

1. Read repository instructions and inspect `git status --short`.
2. Identify changed shell files with `git diff --name-only --diff-filter=ACMR HEAD`.
3. Determine each file's declared shell from its shebang.
4. Run the matching syntax check:
   - Bash: `bash -n <file>`
   - Zsh: `zsh -n <file>`
   - POSIX shell: `sh -n <file>`
5. Run `shellcheck <file>` when installed. Report its absence instead of installing it.
6. Search `tests/` for coverage of the file, command, or function being changed.
7. Inspect the diff for unsafe behavior:
   - unguarded destructive commands
   - `eval` or `bash -c`/`zsh -c` with user-controlled input
   - unquoted expansions in filesystem operations
   - unresolved variables used as paths
   - missing error propagation or misleading exit codes
   - Bash-only syntax in macOS system-Bash or POSIX paths
8. Report evidence per file and finish with a go/no-go verdict.

Do not execute the changed scripts unless the user explicitly asks for runtime
verification and the command is safe.

## Severity

- Blocker: syntax failure, clear command injection, unsafe destructive target, or
  broken required behavior.
- Warning: ShellCheck warning, portability risk, weak quoting, or missing relevant
  test coverage.
- Clean: syntax passes and no material safety or coverage issue is found.

Do not treat style preferences as blockers.

## Output

For each file, report syntax, ShellCheck, test coverage, and safety findings with
file and line evidence. End with:

```text
SUMMARY: <count> files checked — <clean> clean, <review> need review
VERDICT: GO | REVIEW BEFORE COMMIT | NO-GO
```

## Evals

### Should trigger

- "auditera mina ändrade shellscript innan commit"
- "jag har ändrat en zsh-fil, kontrollera syntax och säkerhet"
- "finns det osäkra eval eller rm-anrop i den här bash-diffen?"
- "review the changed shell scripts and give me a go/no-go verdict"

### Should not trigger

- "fixa buggen i shellscriptet" — implementation, not an audit-only request
- "bygg en ny mqlaunch-meny" — use `mqlaunch-menu-template`
- "ändra mqlaunch-kommandots routing" — use `mqlaunch-command-surface`
- "gör terminalgränssnittet tydligare" — use `terminal-ui-polisher`
