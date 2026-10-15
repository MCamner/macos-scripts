---
name: mq-stack-recovery
description: Diagnose and safely repair MQ stack CI verification drift, MCP contract errors, launchd port conflicts, and Keychain auth without weakening required gates or rebooting. Use for mqlaunch stack status FAIL/UNVERIFIED/STALE, MCP live drift, and background server startup failures.
---

# MQ Stack Recovery

Shared workflow for **Codex** and **Claude Code**. Treat CI evidence and server state as separate truths. Read repository instructions and current branch before edits. Prefer read-only checks first.

## Diagnose, don't guess

1. Capture `mqlaunch stack status --json`; inspect each repository's `verification.status`, `reason`, `scopes`, exact `commit`, `branch`, and `dirty`.
2. For a failing scope, inspect GitHub check-runs **on that exact SHA**. Distinguish pending, skipped, missing, failing and stale. Never reuse a green check on an older SHA.
3. For `mq-agent`, distinguish PR-specific `Contract and release gates (CI mode)` from main-push `Contract and release gates`. PR branch protection and main-head verification require different jobs; skipped is not success. Inspect workflow event predicates and the verifier code before proposing edits.
4. For `STALE`, check evidence freshness (24h default) and whether local checkout is behind origin/main. Do not create empty commits to refresh a status or pull over uncommitted changes.
5. For MCP compatibility, check declarations, lockfiles, manifests, active checkout, and `--live` warnings independently.
6. For launchd failures, inspect user LaunchAgent status and error logs, then port owners. `Address already in use` means identify duplicate manual services; do not kill processes without checking their command and parent.
7. For auth warnings, use `mqlaunch auth status` then `mqlaunch auth test openai`. Environment variable missing is not necessarily a failure when Keychain is the effective source. Do not print keys or put secrets in plist, logs or repository files.

## Read-only command set

```bash
mqlaunch stack status --json | jq -r '.repos[] | [.name, .verification.status, .verification.reason, "\(.verification.verified_count)/\(.verification.required_count)"] | @tsv'
mqlaunch auth status
mqlaunch doctor
launchctl print "gui/$(id -u)/se.mq.mcp"
launchctl print "gui/$(id -u)/se.mq.image"
lsof -nP -iTCP:8765 -sTCP:LISTEN
lsof -nP -iTCP:8766 -sTCP:LISTEN
```

From the mq-agent checkout:

```bash
uv run mq-agent stack compatibility --repo-path "mq-mcp=$HOME/mq-mcp-main" --live
```

When needed inspect `gh api repos/MCamner/mq-agent/commits/<SHA>/check-runs` and local `git status -sb`. Verify actual paths before using examples.

## Safe repair protocol

- State the confirmed failure, evidence, and intended minimal change.
- Obtain a clean worktree or use an isolated branch/worktree; never overwrite someone else's work.
- Fix CI profile selection rather than declaring skipped checks green; do not loosen branch protection. Keep exact-SHA and fail-closed semantics.
- For launchd, stop duplicate manual processes **only with explicit operator approval** after verifying PID ownership. No surprise logout, restart or reboot.
- Add regression tests for both positive and negative scenarios; run focused tests and full repository gates. Open a PR and wait for success before merge. Rerun stack status on the new HEAD; PR green does not imply merge-commit green.
- Verify a live tool result separately from declaration/registration. Do not claim `risk_review_repo` executed unless its actual output was inspected.
- Capture a sanitized learn and commands summary in mqobsidian; never store private file paths, host details or secrets.

## Output contract

Report **confirmed**, **pending**, and **not tested** separately with exact commit, affected scope, non-destructive next action, and rollback. A stack-wide 8/8 VERIFIED means required GitHub checks passed for the checked-out HEADs; it does not prove a complete runtime E2E, AI invocation, or post-reboot launchd persistence.

## Evals

- Main HEAD: PR gate skipped, full-stack gate succeeded => VERIFIED if other requirements pass.
- Main HEAD: full-stack gate absent or failed => UNVERIFIED or FAIL.
- PR HEAD: CI-mode job skipped => FAIL, regardless of full-stack job result.
- Freshness: old green evidence => STALE; missing => UNVERIFIED.
- Two occupied MCP ports: report owners; do not kill them autonomously.
- Keychain HTTP 200 and missing process env => auth PASS for tested client, not proof for other processes.
- Eight repos VERIFIED with untested reboot => explicitly preserve reboot test as pending.
