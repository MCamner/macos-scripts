# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

## [Unreleased]

## [2.0.0] - 2026-07-28

Runtime authority and command-surface governance. One dispatcher,
one command registry with five gated consumers, an enforced output
contract, and ShellCheck raised from error to warning severity.

### Added

* A command must delegate to the repo that owns it. `validate-command-registry.py`
  already required `delegates_to` to be non-empty when the owner was another
  repo, but not to *name* that owner — so an entry could declare `mq-agent` as
  owner while routing to `mq-mcp`, the boundary violation
  `docs/RUNTIME_AUTHORITY.md` forbids. `delegates_to` holds the whole delegated
  command (`mq-agent review`, not `mq-agent`), so the rule compares its first
  word. All 16 delegating commands already satisfied it; the point is that they
  now have to. Fixture [17/17] proves the gate fires.

  Found by checking the roadmap against the tree rather than trusting its
  checkboxes: "Test delegation ownership" was true by convention and ungated.

* `tests/docs-file-inventory-smoke.sh` — a README that documents a file by name
  must not outlive it. Three READMEs describe their directory file by file as
  `###`name`` sections: `ui/ascii`, `terminal/menus` and `automation/workflows`.
  That form is a hand-written inventory, and it had already gone stale:
  `ui/ascii/README.md` carried a section for `mq-skull.txt` long after PR #32
  deleted the file. Confirmed the gate catches it — run against the README as it
  stood before the fix, it reports `mq-skull.txt`.

  One direction only, the same contract `mqlaunch help` and README follow:
  documented files must exist, coverage is not required. `terminal/menus/README.md`
  writes up 11 of its 21 files by design, and forcing the rest in would turn it
  into a directory listing the shell already provides. The uncovered count is
  printed rather than enforced — a number moving is a prompt to look, not a build
  break.

  `docs/AUTHORITY_MAP.md` claimed stray `*.sh.bak` files were removed in PR #32.
  One survives — `terminal/menus/mq-hal-menu.sh.bak.20260519-115142`, dated after
  that cleanup, referenced by nothing. The claim is corrected and the file is
  listed as dead rather than deleted here, since deletions belong in their own
  diff.

* `tools/scripts/shellcheck-report.sh` — measures what a stricter ShellCheck
  gate would cost, and changes nothing. Deliberately not wired into
  `test-all.sh`: a measurement that gates is no longer a measurement, and it
  would slow every suite run for a number nobody is reading that minute.

  It corrected the premise the roadmap was planning against. ShellCheck is not
  warn-only today — `tools/scripts/lint.sh` runs `shellcheck -S error` with no
  `|| true`, `test-all.sh` calls it, and CI runs `test-all.sh`. Error severity
  has been a hard gate all along. What is warn-only is the separate `quality.yml`
  step, which runs the same severity over a wider surface and discards the
  result.

  Measured: 0 errors, 96 warnings across 37 files, 270 at info, 276 at style.
  51 of the 96 warnings are one rule (SC2034, unused variable) and the next four
  rules account for 36 more, so roughly nine tenths of the warning surface is
  five rules. 10 zsh scripts — including `mqlaunch.sh` — are outside ShellCheck
  entirely, since it cannot parse zsh; they are covered by `zsh -n`. 34 files are
  scanned by the warn-only CI step but not by the gate, and at error severity
  they are clean too.

  The report verifies its own relevance: it runs `lint.sh` and fails if the file
  count it scanned differs from the count `lint.sh` gates, so a divergence in
  exclusions surfaces instead of quietly turning the numbers into a description
  of something else. Rule descriptions come from ShellCheck's own output rather
  than a table, so they cannot go stale against the installed version.

* `deprecated_aliases` in the command registry. An alias can outlive the reason
  it was added: deleting it breaks whoever still types it, and leaving it in
  `aliases` tells every consumer it is a current name. The field is the third
  state — still dispatched, no longer part of the surface a consumer may
  advertise.

  It is metadata on the alias, not a flag on the command. Retiring an old
  spelling says nothing about the command it points at, and `deprecated: true`
  on the entry could not express the difference. Keeping it out of `aliases`
  also makes the "not advertised" rule structural rather than enforced: a
  consumer building its surface from `aliases` excludes it without knowing the
  field exists.

  `validate-command-registry.py` enforces four rules — a deprecated alias must
  name a `replacement`; that replacement must be an active command name or alias
  and must not itself be deprecated; a word must not be listed as both active
  and deprecated; one word belongs to exactly one command. A deprecated word is
  still dispatched, so it stays subject to registry-versus-dispatch parity.
  `tests/registry-consumer-parity-smoke.sh` carries the consumer half: neither
  `mqlaunch help` nor the palette may offer a deprecated word, while
  `docs/COMMANDS.md` may still document one — a reference that records the old
  spelling is doing its job.

  Five fixtures, each asserting the reason and not merely a non-zero exit: a
  well-formed deprecation still validates, a missing replacement fails, a
  replacement nothing dispatches fails, a word that is active and deprecated at
  once fails, and a deprecated word two commands claim fails. The consumer
  fixture is built from a word `mqlaunch help` actually prints, so it raises
  rather than quietly testing nothing if help stops advertising aliases.

  Nothing in the registry is deprecated today. The words that would have
  qualified — `tools-menu`, `dev-v1`, `gitlaunch` — lived in the second
  dispatcher and went with it. The rules exist so the first real deprecation is
  stated rather than remembered.

* Subcommands in the command registry. The nine namespaces that dispatch a
  nested `case "$sub" in` — `workspace`, `srm`, `repos`, `system`, `git`,
  `release`, `dev`, `help`, `obsidian` — now declare their 47 subcommands with
  aliases and summaries, plus `unknown_subcommand`, which records whether the
  namespace rejects an unrecognised word itself (exit 2) or forwards it to a
  delegate. That is the one thing a consumer must know before publishing the
  list as complete: `system` rejects, so its list is the whole surface; `repos`
  forwards, so the registry can only speak for what `mqlaunch` routes.
  `validate-command-registry.py` gates all of it in both directions — a
  subcommand the dispatcher does not handle, a dispatched subcommand or alias
  the registry omits, a namespace that grows a nested case and declares
  nothing, and an `unknown_subcommand` value that contradicts the `*` branch.
  Five fixtures in `tests/command-registry-smoke.sh` assert the gate fires for
  the right reason, not merely that it exits non-zero.

* `mqlaunch/lib/command-registry.json` — the canonical inventory of top-level
  `mqlaunch` commands: 67 entries covering 145 names, each carrying its aliases,
  namespace, summary, owner repo, safety mode, output modes, JSON support,
  interactivity, compatibility status and delegation target.
  `tools/scripts/validate-command-registry.py` is the gate: it rejects duplicate
  names and alias collisions, empty summaries, unknown owners or safety modes,
  and JSON claims not backed by a JSON output mode — then walks
  `dispatch_cli_command` and fails if the registry and the dispatcher disagree in
  either direction. Registered as `tests/command-registry-smoke.sh`, which also
  asserts that the gate itself fires rather than passing everything. The registry
  sits on the authority-owned path required by `docs/RUNTIME_AUTHORITY.md`.
  Nothing consumes it at runtime yet; help, palette and docs generation come
  later in the v2.0.0 block.

### Changed

* ShellCheck is enforced at **warning** severity. `tools/scripts/lint.sh` runs
  `-S warning` instead of `-S error`, which is the actual change — `error` has
  been a hard gate since before this work, because `lint.sh` has never carried
  `|| true` and `test-all.sh` calls it. The roadmap said "ShellCheck must not
  remain warn-only forever" and was planning against a premise that was wrong.

  The warn-only step in `.github/workflows/quality.yml` now calls `lint.sh`
  rather than re-deriving the file list with its own `find` and its own
  exclusions. It could not simply drop `|| true`: its wider surface includes
  `tools/legacy/` and `terminal/mqlaunch-v1/`, which still hold 5 warnings that
  `lint.sh` deliberately excludes, so removing the safety net would have failed
  CI on frozen paths that are closed to new work. Sharing one surface fixes that
  and removes the duplicate definition.

  `shellcheck` is installed in CI and its presence asserted before the gate runs.
  `lint.sh` exits 0 when the binary is missing so a developer without it can
  still run the suite; unguarded, that convenience would have made the CI step
  unfailable.

  Verified by mutation: an unused variable added to a throwaway script fails the
  gate with SC2034 and exit 1, and removing it returns to green.

  The ShellCheck version is pinned in CI rather than taken from apt. The first
  enforced run failed on two SC2120 findings the version used for the
  measurement does not report at all — the rule set moves between releases, so
  an unpinned gate means something different depending on when it runs. Both
  findings were fixed and the baseline is now zero under 0.9.0 and 0.11.0 alike:
  `surface_git_state` keeps its repo argument with a directive naming the
  contract test that passes one, and `_run_demo_flow` lost a parameter no caller
  had ever supplied.

* The nine unquoted command substitutions ShellCheck flagged for word splitting
  are now quoted (SC2046). Eight are `read A B C <<< $(…)` in
  `tools/scripts/scan.sh`; the ninth passes a default-gateway lookup as an
  argument in `tools/scripts/pulse.sh`.

  Quoting a here-string is only safe when the command emits one line — unquoted,
  word splitting flattens newlines into spaces, so a multi-line result feeds
  every field to `read`, while quoted it would read the first line and drop the
  rest. All eight emit exactly one line by construction (`awk 'NR==2 …'` and a
  single `END { printf }`), which is why quoting them changes nothing.

  Verified against a deterministic stub rather than the live process list:
  `scan.sh` reads `ps` and `vm_stat`, so its output differs between two runs of
  the *same* code and whole-output diffing cannot decide the question. With a
  stubbed `ps` emitting irregular whitespace and a process name containing
  spaces, both forms produce identical variables, as does the empty-output edge
  case. `pulse.sh` output is byte-identical before and after.

  With this the ShellCheck warning baseline is **zero**, down from 96 when the
  measurement started. `tools/scripts/shellcheck-report.sh` now reports
  `-S warning  already clean — a gate here costs nothing today`.

* The five unquoted `@{u}` git refs now match the two the repo already quoted.
  `@{u}` is git's upstream shorthand, not shell — and the braces have to reach
  git literally. They already did: neither bash nor zsh expands a single-element
  brace, which is why `{a,b}` splits and `{u}` does not. So SC1083 was flagging
  a form that worked, in the two spellings the repo used side by side.

  Quoting is what ShellCheck suggests, is what
  `ui/ascii/mqlaunch-dashboard-v7.1.sh:131` and
  `automation/workflows/workspace.sh:100` already did, and states that the braces
  belong to git. Verified identical against a real upstream (`origin/main`,
  `1 0`), against a repo with no upstream (exit 128 either way), and through
  `tests/git-status-contract-smoke.sh`, which drives the live dashboard.

  Everything ShellCheck governs is now quoted. `terminal/launchers/gitlaunch.sh`
  has five more unquoted, unflagged because it is zsh and outside ShellCheck's
  reach; it was checked and is not a defect — zsh leaves `@{u}` literal exactly
  as bash does.

  SC1083 is now zero; the warning count is 19 → 9.

* The ten dynamic `source` calls ShellCheck could not follow now carry a
  directive. Four name the real file — `mq-ui.sh` from `macos-tweaks.sh` and
  `mq-ui-demo.sh`, `mq-ai-prompts.sh` from the release check, and
  `mq-performance-menu.sh` from the performance bridge, which had a
  `disable=SC1091` standing in for a path it could simply have named. Six cannot:
  the mqobsidian and recommendations menus build their paths inside a loop over a
  list of library names, and `ask`/`chat`/`fix`/`srm` source an operator's
  `~/.env`, which lives outside the repo and is optional by design. Those get
  `source=/dev/null` and a comment saying why no target exists.

  Paths are script-relative, which is the form that resolves wherever ShellCheck
  is invoked from. That matters more than it looks: `source=` resolves against
  the working directory by default and against the script's directory under
  `--source-path=SCRIPTDIR`, and `lint.sh` runs from neither predictably. All
  four were verified to resolve to a file that exists.

  SC1090 is now zero; the warning count is 31 → 21. The diff is comments only —
  17 lines added, and the single removed line is the `disable=SC1091` a directive
  replaced.

* `tests/command-docs-smoke.sh` is a README contract instead of a second,
  hand-maintained command registry. It named eleven commands — `palette`,
  `ghost`, `pulse`, `reap`, `guard`, `mc`, `nickname-set`, `theme-macos`,
  `theme-reset`, `bundle` — and grepped for each in `docs/COMMANDS.md` and again
  in the dispatcher. All twenty assertions were strictly weaker than gates that
  already run: `tests/registry-consumer-parity-smoke.sh` requires COMMANDS.md
  coverage in both directions for all 73 commands, and
  `validate-command-registry.py` holds registry-versus-dispatch parity exactly.
  All eleven words were verified present in the registry and in COMMANDS.md
  before the assertions were removed, so nothing stopped being checked — it is
  checked for 73 commands now rather than eleven.

  In their place, README becomes the fifth consumer of the registry, and the
  first one that was never checked at all. It is the first page anyone reads, it
  prints commands in runnable blocks, and nothing verified those commands exist.
  README has the same contract as `mqlaunch help`: curated, so coverage is not
  required, but every command it shows must dispatch and it must not promote a
  word the registry is retiring. Extraction reads only fenced runnable blocks,
  so the product boundary written as prose — `mqlaunch shows the right
  workflow` — does not contribute a command called `shows`. Two fixtures, each
  asserting the reason rather than a non-zero exit: a command README shows that
  nothing dispatches, and a deprecated spelling README still teaches.

  One assertion was dropped rather than moved: nothing now requires README to
  mention `mqlaunch palette` specifically. Which commands earn a place on the
  front page is a curation decision, not a contract, and a gate cannot tell the
  difference between a command being removed from README and a command being
  removed.

* Added a root `release-check.sh` conforming to the `repo_release_check.v1`
  contract: `--json` emits the machine-readable verdict (`schema`, `repo`,
  `status`, `blockers`, `warnings`, `evidence`) on clean stdout and exits 0;
  human mode prints per-check ok/FAIL. Runs the read-only checks (contract/
  CHANGELOG/README version surfaces, check-skills, runtime-authority freeze,
  `bash -n` syntax, mqlaunch smoke suite). Lets mq-agent's `stack release --all
  --preflight` read the release verdict.

### Fixed

* `ui/ascii/mq-dashboard.sh` aborted halfway through rendering. Three lines wrote
  `${mq_repeat_char "-" "$width"}` — a parameter expansion of a variable by that
  name — where `$(mq_repeat_char …)`, a command substitution, was meant. bash
  raises `bad substitution` at runtime, which `bash -n` cannot catch because it
  is not a parse error.

  The effect was not a missing separator. The function stopped at the first one,
  so ten lines never printed: user, host, time, shell, OS, repo, branch and all
  three rules. Verified by diffing the script's output before and after —
  `main` emits one line to stderr and 12 lines of dashboard, this emits nothing
  to stderr and 22.

  ShellCheck reported it as SC2154, "mq_repeat_char is referenced but not
  assigned", and only for the first of the three occurrences.

  `docs/AUTHORITY_MAP.md` lists this file under "Dead — DEPRECATED … safe-to-delete
  candidates", alongside `mq-dashboard-v3.sh` and `mq-banner.sh`. Deleting the
  three is a separate decision and a diff worth seeing on its own; this makes the
  code correct without presuming it.

* `backup_zshrc` in `terminal/themes/mq-zsh-theme-switcher.sh` declared and
  assigned in one statement, so `local` masked the exit status of the command
  substitution (SC2155). Split. Both callers use `$(backup_zshrc)` and read
  stdout, and the function's status comes from its `echo`, so nothing observable
  changes — confirmed by driving the function against a temp directory.

* Three submenus advertised `x. Exit` and did not implement it. `mq-apps-menu`,
  `mq-system-menu` and `mq-help-center-menu` each carried
  `b|B|x|X|exit) return` followed by an `x|X)` branch that printed
  `Exiting …` and called `exit 0`. The first branch already matched `x`, so the
  second was unreachable: pressing `x` returned to the parent menu while the
  panel said it would exit.

  The label was wrong, not the code. Every other submenu in the repo —
  `mq-dev-menu`, `mq-git-menu`, `mq-ai-menu`, `mq-net-menu`, `mq-tools-menu` —
  uses the same `b|B|x|X|exit) return` and advertises only `b. Back`. These
  three were the outliers. The dead branch is removed and the panel row now
  reads `b. Back` alone, so what is shown matches what happens.

  Behaviour is unchanged, and that is verified rather than asserted: both `b`
  and `x` were driven through all three menus against `main` and against the
  branch, and every exit status is identical.

* A duplicated pattern in the main menu's REPL dispatch. `hal\ *|"hal "*)`
  spelled the same match twice — an escaped space and a quoted one — so the
  second alternative could never be reached. Collapsed to `"hal "*)`.

* `repo_state` reported `clean` for a checkout holding untracked files. All
  three reporting surfaces — `mqlaunch status --json`, the status dashboard and
  `mqlaunch version` — derived it from `git diff --quiet --ignore-submodules
  HEAD`, which sees tracked changes only. `mqlaunch git` has always gated on
  `git status --porcelain`, which counts untracked files, so the same tree could
  read `clean` from one command and have changes according to another. One repo
  should not answer "is this tree clean" two ways (#66).

  `dirty` now means any working-tree change, untracked files included. The
  question a consumer is asking is whether the checkout is safe to act on, and
  an untracked file is a change even though it does not differ from `HEAD`.

  The third value is `not-a-git-repo` everywhere. `mqlaunch status --json` said
  `unknown`, which reads as "could not determine" — a different claim from the
  one being made. The dashboard had no third value at all: a missing checkout
  read as `dirty`. The token covers git being unavailable too, since without it
  a checkout cannot be told from any other directory and the caller's options
  are the same either way.

  The derivation now lives in one place, `mq_repo_state` in
  `ui/terminal-ui/mq-ui.sh`, next to `mq_git_status_snapshot` — which already
  counted untracked files and already distinguished a non-checkout. The
  divergence was three surfaces re-deriving an answer the shared library was
  producing correctly. `tests/plain-output-contract-smoke.sh` drives all four
  states against real checkouts in a temp directory, asserts that the
  untracked-only fixture is one the old logic would have called clean, and fails
  if any surface goes back to a tracked-only diff.

* `mqlaunch release-check --json` printed the human banner and exited 0. The
  route forwarded flags to `terminal/release/mq-release-check.sh`, which reads
  only `--brain` and discards everything else, so a caller asking for JSON got
  a successful-looking banner to parse. `--json` now reaches `release-check.sh`,
  which owns the `repo_release_check.v1` contract, and its output is identical
  to running that script directly. Unknown flags exit 2 with a usage error
  instead of being ignored. Human mode is unchanged and keeps the wider review
  the two scripts do not share — secrets scan, mqobsidian manifest contract,
  changelog versus commits. The registry entry declared `"json": false` and now
  matches.

* `mqlaunch git help` never returned. It reached `open_git_menu`, which treats
  its argument as a repo path, so `help` became a failed path lookup and the
  interactive menu opened and looped on EOF — 12580 bytes and no exit without a
  terminal. `help`, `-h` and `--help` now resolve before the namespace body for
  every namespace mqlaunch routes, so `git`, `system`, `release` and `dev` join
  the seven that already exited 0. `system`, `release` and `dev` previously
  exited 2 for a successful help request.

* An unknown subcommand now behaves the same across the namespaces mqlaunch
  routes itself: a diagnostic on stderr, help on stdout, exit 2, and no menu.
  `obsidian` used to print a hand-written usage string and exit 1, while
  `system`, `release`, `dev` and `help` exited 2 silently. `git`, `srm`, `repos`
  and `workspace` are deliberately unchanged — they have no closed subcommand
  set, and the reasoning is in `docs/plans/P1-command-registry-subcommands.md`.

* `mqlaunch repos LIST` failed while `mqlaunch system TIME` worked. Command
  words are lowercased into `sub` before routing, but the `srm` and `repos`
  branches shifted and re-read the raw `"${1:-}"`, so those two namespaces were
  case-sensitive and nothing else was. Both now route on the normalised word,
  and `repos` forwards it to `mq-repos.py`, which matches its command word
  exactly. Only the command word is normalised: arguments keep the case the user
  typed, an unknown subcommand is still forwarded verbatim so the delegate's
  error names what was actually typed, and the free-text question that `srm`
  hands to `srm.sh` is untouched. Implements D1 of
  `docs/plans/P1-command-registry-subcommands.md`.

* 22 dispatch branches invoked a script under `$BASE_DIR` and then ended in an
  unconditional `return 0`, so a failing delegate was reported as success:
  `mqlaunch repos LIST` and `mqlaunch skills no-such-subcommand` both wrote a
  usage error to stderr and exited 0. Every delegating branch now captures
  `command_status` and returns it, matching the idiom the agent and HAL routes
  already used. `pause_enter` no longer overwrites the status on the routes that
  call it. `tests/delegated-exit-code-smoke.sh` gained the two behavioural cases
  and a structural check that fails if any delegating branch reverts to an
  unconditional `return 0`.

* `mqlaunch` dispatched `memory` from two different branches. The
  `srm|memory|repo-memory` branch claims it first, so the `memory` listed in the
  brain-bridge branch below it could never match — `mqlaunch memory` has always
  gone to the SRM surface, never to the brain bridge. Removed the unreachable
  token; behaviour is unchanged, and the registry gate now fails if a duplicate
  route is introduced again. Found while mapping the command surface for the
  registry.

* `docs/RUNTIME_AUTHORITY.md` — the runtime-governance contract for `mqlaunch`.
  Names the single live authority (`bin/mqlaunch` → `mqlaunch.sh` →
  `mqlaunch-command-mode.sh`), the allowed and forbidden responsibilities of that
  path, the LIVE/COMPAT/DEPRECATED/TEST-ONLY classes, the compatibility policy
  and its removal gate, and the dependency direction that forbids new live edges
  into `terminal/mqlaunch-v1/`. `AUTHORITY_MAP.md` keeps the path-by-path
  inventory; this document holds the boundary that must stay true while those
  paths migrate. Linked from the README documentation map, `COMMAND_SURFACE.md`
  and `MQ_BOUNDARY.md`. Closes the P1 "Single runtime authority" roadmap block,
  whose delegation tests already existed in
  `tests/compat-path-delegation-smoke.sh`.

* `mqlaunch status --json` (and `about --json`) now emit machine-readable JSON
  only. The `about|status` route ignored its arguments and always rendered the
  dashboard, so a caller piping `--json` got ~5.9 KB of ASCII banner, no JSON,
  and exit 0 — a silent failure. `dispatch_cli_command` now branches on
  `has_json_flag` into `print_status_json`, which prints one JSON document
  (`project`, `version`, `release_stage`, `repo_state`, `latest_bundle`) on
  clean stdout. The JSON path also drops the dashboard's smoke-test field, which
  shelled out to the full test suite: the call went from 20.7 s to 0.1 s and no
  longer recurses when run from `test-all.sh`. `repo_state` reports `unknown`
  instead of `dirty` when the repo root is not a git checkout. Proven by two new
  steps in `tests/plain-output-contract-smoke.sh`.

* The git "auto commit + push" automation no longer leaves the working checkout
  off-main. After creating and pushing an `mq/...` PR branch,
  `create_pr_branch_for_push` (in `gitlaunch.sh` and `mq-git-menu.sh`) now calls
  `tools/scripts/git-restore-to-base.sh`, which restores the checkout to the base
  branch and rewinds the local base ref to origin — non-destructively, since the
  commit is already on the pushed PR branch. Runs even when the push or PR step
  failed; reports repo/branch/dirty/next-command if it cannot restore. Proven by
  `tests/git-restore-to-base-smoke.sh`.

### Removed

* Nine variables that were assigned and never read: `SCRIPT_NAME` in
  `mqshortcuts.sh` (its usage heredoc is quoted, so nothing expanded it),
  `REPO_ROOT` in `demo-flow.sh`, `MQ_MCP_REVIEW` in the tools menu (a path
  constant naming a script that menu never invokes), `C_DIM` in `macos-tweaks.sh`
  and `BOLD` in `env-snap.sh` (the only colours in either palette nothing used),
  an unused `warnings` local in the performance menu, `top_glow` and `bot_glow`
  in `mq-dashboard-v3.sh` (built from `═` while the lines the dashboard actually
  draws use `▄` and `▀` inline), and a `delay` local in `vault-scan.sh`.

  `vault-scan.sh` is worth flagging rather than quietly resolving: the local said
  `0.02` while the loop below it sleeps `0.01` as a literal. Either the variable
  was meant to be used or it is a leftover. Wiring it up would double the
  animation delay, so this removes the dead local and changes no timing. If the
  intent was `sleep "$delay"`, that is a separate decision about how the effect
  should look.

  Two loop counters the bodies never read — in `excalidraw.sh` and `watch.sh` —
  became `_`.

  Six more SC2034 findings stay, each with a directive naming what reads it:
  three positional `read` fields in `scan.sh` where dropping the name would make
  `read` append the value to the previous variable, and three dynamic-scope
  contracts (`THEME_SCRIPT` and `MQ_THEME_ERROR_HEADING_BOLD` read by
  `mqlaunch/lib/themes.sh`, `MQ_SURFACE_WIDTH` by the prompt-separator pattern
  documented in `.claude/templates/`).

  SC2034 is now zero; the ShellCheck warning count is 96 → 45.

* `run_arg_command`, the second command dispatcher, and the freeze that held it.
  It answered the command palette and accepted 93 words the registry never
  modelled — names that worked when chosen and printed `Unknown command` when
  typed. Rerouting the palette through `dispatch_cli_command` left it with no
  callers, so this deletes 148 lines of unreachable launcher, the
  `mqlaunch/lib/legacy-command-vocabulary.txt` baseline that recorded its words,
  and `tests/legacy-vocabulary-freeze-smoke.sh`, which existed to hold a surface
  that no longer exists. `legacy_alias_notice` goes with it: its only callers
  were inside the deleted function. `dispatch_cli_command` is now the only
  dispatcher, so the registry governs the whole command surface rather than most
  of it.

  No command changed behaviour — every word in the deleted function had already
  stopped dispatching. What did change is what the gates prove.
  `tests/compat-path-delegation-smoke.sh` was matching the word
  `run_arg_command` in a comment, so it would have stayed green after the call
  it checks was deleted; it now anchors to the call and fails if a second
  dispatcher reappears anywhere under `terminal/`, `mqlaunch/` or `ui/`. Four
  assertions in `tools/scripts/test-mqlaunch.sh` were pointed at case labels
  inside the dead function: the performance, dev and tools routes moved to
  `mqlaunch-command-mode.sh`, which is the file that can now be wrong about
  them, and `restart` moved to `terminal/menus/mq-main-menu.sh`, where it is a
  menu key rather than a command word. The check for the legacy Tools aliases —
  `tools-menu`, `toolsmenu`, `menu-tools`, `tools-v1`, `menu-tools-v1` — is gone
  with them; nothing advertises them, and asserting the strings were still
  present only proved they were remembered.

  `tools/scripts/mqlaunch_desktop.sh` keeps its own copy. It is a separate live
  entrypoint that dispatches for itself, not a caller of this one.

## [1.0.1] - 2026-07-16

### Added

* `mq_debug` — a diagnostic logger in `mq-ui.sh`, silent unless `MQ_DEBUG` is
  set, writing to stderr and always returning 0. Use it as `… || mq_debug "why"`
  to make an unexpected best-effort failure observable instead of swallowing it
  with `2>/dev/null || true`. Adopted at the git-screen `cd` guard and the
  Obsidian menu's optional-lib loader; broader adoption is incremental.
* `scripts/check-skills.sh` — validates skill frontmatter, cross-references,
  referenced paths, and the generated SKILLS.md table; wired into the Quality
  workflow. `--fix` regenerates the table.
* Evals sections (should/should-not trigger) in every skill.

### Changed

* ROADMAP now tracks the `mqobsidian` v0.1.0 single-source-of-truth foundation
  as an upstream dependency, while keeping `mqlaunch` read-only or
  delegate-only for truth, inbox, ranking, and promotion surfaces.
* Documented the canonical mqobsidian view-manifest keys consumed by `mqlaunch`
  and marked that roadmap deliverable done.
* Added a smoke test that locks the MQ Obsidian menu out of memory promotion or
  rejection routes, preserving the review-gated ownership boundary.
* Verified the review command delegation boundary through
  `tests/mq-agent-routing-smoke.sh` and marked the roadmap item done.
* Added direct `mqlaunch obsidian status`, `mqlaunch obsidian inbox`, and
  `mqlaunch obsidian views` routes for read-only mqobsidian status/navigation.
* Added `mqlaunch obsidian promote` as a thin delegate to
  `mq-agent obsidian promote`, keeping scoring and memory writes out of
  mqlaunch.
* Added a release-check gate for the local mqobsidian view-manifest consumer
  contract, blocking malformed or drifted `views.json` before release.
* Added delegate-only `mqlaunch stack status` / `mqlaunch stack ...` routing to
  `mq-agent stack`, keeping canonical truth parsing outside mqlaunch.
* Monolith de-layering (Step 11a): five concerns moved verbatim out of
  `terminal/launchers/mqlaunch.sh` into dedicated libraries sourced back into
  the launcher's scope — the network concern (status/diagnostics/connectivity,
  17 functions → `mqlaunch/lib/network.sh`), the fzf interactive pickers
  (git log/branch, kill process/port, run snippet, recent files, 6 functions →
  `mqlaunch/lib/fzf-pickers.sh`), diagnostics (version reporting, self-check,
  debug bundle, release notes, plus the system check, 6 functions →
  `mqlaunch/lib/diagnostics.sh`), the git & release menu launchers
  (2 functions → `mqlaunch/lib/git-menus.sh`), and the GitHub repo picker
  (1 function → `mqlaunch/lib/repo-picker.sh`). No behavior change; the launcher
  drops ~720 lines and each concern now has a named owner. Guarded by
  `tests/monolith-delayer-smoke.sh`, a table-driven check that fails if any
  extracted function is redefined in the monolith or a lib source is dropped.
* `print_header` now has a single owner: `ui/terminal-ui/mq-ui.sh`. The launcher
  no longer overrides it; instead it opts the main loop into the dashboard-v7.1
  header via `MQ_USE_DASHBOARD_HEADER=1`. **Behavior change:** the main-loop
  header now renders through mq-ui's *cached* dashboard path (bounded by
  `MQ_DASHBOARD_CACHE_TTL`, default 5s, and invalidated by the git/release
  flows) instead of re-forking the dashboard script uncached on every screen.
  This removes a hidden fork in render behavior and aligns the main loop with
  the cache and invalidation model the rest of the runtime already used; it also
  avoids a dashboard re-fork per screen render. Escape hatch: set
  `MQ_DASHBOARD_CACHE_TTL=0` for an uncached, per-screen header while
  investigating. The dead `DASHBOARD_V71` launcher variable (only the removed
  override used it) is gone.
* `semantic-memory-maintainer` renamed to `vector-store-maintainer` to avoid
  routing collision with mq-mcp's skill of the same name.
* `command-template-library` skill moved to mq-ums, where the contracts and
  generator it documents live.
* The mqlaunch menu/GUI construction standard now has a single owner
  (`mqlaunch-command-surface`); `terminal-ui-polisher` references it instead of
  duplicating it. Stack surfaces (agent menu 17–18, `mq b2 stack`) documented.
* `release-readiness` rebuilt around `mqlaunch release-check`, the stack
  contract gate, and smoke tests. `docs-maintainer` no longer routes to the
  non-existent `repo-product-auditor`.

### Fixed

* The HAL command surface (`hal …` in the REPL and main menu) no longer runs
  user input through `eval`. Requests are tokenized into argv with `read -ra`,
  so `*`, `;`, `|`, and `$(…)` in a request stay literal instead of being
  expanded or executed. Behavior change: a quoted multi-word argument
  (`hal remember "buy milk"`) is now split on whitespace rather than kept
  together by the shell — quote it at the HAL level if grouping is needed.

### Removed

* Dead `run_git_screen` in `terminal/launchers/mqlaunch.sh` — it had no live
  caller in the launcher graph (the live copy lives in
  `tools/scripts/mqlaunch_desktop.sh`). Surfaced while de-layering the git
  concern (Step 11a); removed as a standalone cleanup rather than folded into a
  refactor.

## [1.0.0] - 2026-06-10

### Added

* **B2 Stack Cockpit** (`mq b2 stack`) — aggregated dashboard: repo health,
  B2 prompts, roadmap drift, last run, validation health, Obsidian sync status.
* **v0.7.0 mq-agent bridge** — `mq b2 review-last`, `--review` on compose,
  `route --compose --review` full pipeline. Thin subprocess bridge to mq-agent.
* **v0.8.0 review contract** — `review_contract.py`: capture `--json` from
  mq-agent, B2-style severity rendering, BLOCKER exit gate. `--risk` flag added.
* **v0.9.0 repo-signal integration** — `mq b2 repo-status`, `--export`,
  `mq b2 roadmap-drift`, repo health warning in route pipeline.
* 89 passing tests total across b2_tui test suite.

## [0.6.0] - 2026-06-09

### Added

* **B2 Atlas Prompt OS TUI** — full terminal interface for structured prompt
  work (`mq b2`). Phases 0–12 complete: CLI commands (list, show, compose, run,
  route, validate, config, history, export-last, open-last), textual TUI with
  two-panel browser + preview pane, rule-based task router, Obsidian run writer,
  JSONL history, 40 passing tests. Accessible via Dev menu → `a`.
* Added `docs/B2_TUI.md` — full B2 TUI reference.
* Added `mq b2` section to `docs/COMMANDS.md`.

### Changed

* Polished the Dev menu with clearer groups and safer script fallbacks.
* Bumped version to 0.6.0 — B2 Atlas Prompt OS TUI MVP.

## [0.5.1] - 2026-06-03

### Added

* Added `mqlaunch workflows validate` for workflow command-surface health checks.
* Added workflow validation to `mqlaunch release-check`.
* Added `document-functions.sh --quality` to flag generic function comments.
* Added a Document Functions menu entry for comment quality checks.

### Changed

* Synced README, ROADMAP and release metadata for `0.5.1`.
* Tightened the Ollama document-review prompt to return fewer, higher-signal
  comment suggestions without full diffs by default.

## [0.5.0] - 2026-06-02

### Added

* Added mq-agent review, risk-review, architecture, repo-health and mcp-status routing from mqlaunch.
* Added MQ ecosystem repo status, roadmap, skills and diff-summary commands.
* Added command-template-library skill.

### Changed

* Improved README onboarding with requirements, usage examples, docs map, roadmap context and contribution guidance.
* Updated Git menu AI COMMIT flow so it returns to the Git menu instead of the start menu.
* Preserved mq-agent bridge loading when running mq-mcp review from the Tools menu.

### Fixed

* Fixed protected-branch push handling by routing main/master pushes through PR branches.
* Fixed auto comment flow so existing comments are preserved.
* Fixed mq-agent bridge loading in `run_mq_mcp_review`.

## [0.4.12] - 2026-05-23

### Added

* `.github/workflows/quality.yml` — CI shell syntax check: `bash -n` on `install.sh`, `release.sh`, and all `.sh` files; `shellcheck` (warn-only).
* `scripts/install-smoke.sh` — local install smoke test covering `install.sh --dry-run`, `release.sh` syntax, all `.sh` bash -n, `mqlaunch doctor --json`, and `mqlaunch selftest`.
* `terminal/menus/mq-agent-menu.sh` — mq-agent submenu with ten commands across repo analysis, AI, and environment groups.
* `Proof` section in README listing what is verified: dry-run, release validation, JSON health report, selftest, publish gate, HAL read-only commands, and CI syntax coverage.

### Changed

* README version badge bumped to `0.4.12`.
* Main menu panel: added `g. Agent` quick access slot.
* `mqlaunch.sh`: sources `mq-agent-menu.sh` when present.
* `mq-main-menu.sh`: routes `g`/`G` and text aliases (`agent`, `score`, `signal`, `audit`, `doctor`) to mq-agent menu.

## [0.4.11] - 2026-05-20

### Changed

* Reworked `docs/index.html` into a clearer GitHub Pages project front door.
* Added a visible Install, Run, Explore flow for first-time users.
* Added a screenshots section covering HAL, main menu, performance, and release workflows.
* Added a docs map linking the case study, HAL page, command reference, and terminal guide.
* Updated the GitHub Pages sitemap for the refreshed front door and HAL page.

### Added

* Added Pages index smoke test coverage.

## [0.4.10] - 2026-05-20

### Added

* Added `docs/screenshots/hal-menu.png` as a rendered HAL menu screenshot.
* Added the HAL screenshot to `docs/hal.html`.
* Added a stronger HAL preview card on the GitHub Pages index.
* Added HAL screenshot smoke test coverage.

## [0.4.9] - 2026-05-19

### Added

* Added `docs/hal.html` as a GitHub Pages overview for the MQLaunch HAL command surface.
* Linked the HAL overview from existing Pages docs.
* Added HAL Pages smoke test.
* Linked HAL overview from README and command reference.

## [0.4.8] - 2026-05-19

### Added

* Added `docs/hal-gallery.md` as a visual reference for the MQLaunch HAL menu.
* Added `docs/hal-menu-preview.txt` with a plain text menu preview.
* Added HAL gallery smoke test.
* Linked HAL gallery docs from README and command reference.

## [0.4.7] - 2026-05-19

### Added

* Added `docs/hal-command-surface.md` for the full MQLaunch HAL command surface.
* Added smoke test for HAL command surface documentation.
* Added HAL menu layout smoke test.
* Added HAL file formatting smoke test.
* Linked HAL command surface docs from README and command reference.

## [0.4.6] - 2026-05-18

### Added

* Added Ollama review as option 7 in the Document Functions menu.
* Added local review-only helper for comments, docstrings, and function descriptions.
* Added documentation for Ollama Document Review.

### Changed

* Aligned Ollama review default model with installed `qwen3:4b-instruct` tag.

### Safety

* Ollama review is review-only and does not modify files automatically.

### Fixed

* Fixed `mq-release-check.sh` opening ChatGPT browser when called non-interactively (e.g. from `mq-hal release-brief`). AI prompt calls (`mq_ai_prompt_review`, `mq_ai_prompt_ui`) are now guarded with `[[ -t 1 ]]` — skipped when stdout is not a TTY.

## [0.4.5] - 2026-05-17

### Fixed

* Fixed `mqlaunch hal release-brief` (and any `mqlaunch <cmd>` typed from inside the menu prompt) routing to AI — `dispatch_cli_command` now handles `area="mqlaunch"` by stripping the prefix and re-dispatching, so typing the full `mqlaunch hal <sub>` form inside the menu works the same as typing `hal <sub>`.

## [0.4.4] - 2026-05-17

### Fixed

* Restored `mq_hal_run()` alias in bridge — mqlaunch calls `mq_hal_run` but the function was renamed to `mq_hal_main` in a prior refactor, causing all `mqlaunch hal <command>` calls to route to AI instead of the bridge.

## [0.4.3] - 2026-05-17

### Fixed

* HAL menu restored to the correct mqlaunch surface pattern: `surface_panel_header`, `surface_split_row`, `surface_bottom`, and `read_main_choice "hal"`.
* Menu now renders identically to other mqlaunch submenus (panel box + pinned prompt).
* `_hal_pause_enter` helper added for standalone-safe pause.

## [0.4.2] - 2026-05-17

### Fixed

* HAL menu now uses `print_header` when called from within mqlaunch, matching the style of all other submenus. Falls back to a plain standalone header when run directly.

## [0.4.1] - 2026-05-17

### Changed

* Rewrote HAL menu as self-contained (`mq-hal-menu.sh` no longer depends on `surface_*`, `print_header`, or `read_main_choice`).
* Reordered OBSERVE: Audit is now item 2 (between Brief and Release Brief).
* Expanded `tests/hal-menu-smoke.sh` from 6 to 8 checks — now verifies audit and release-brief routes and menu labels.

## [0.4.0] - 2026-05-17

### Added

* Added `mqlaunch hal audit` bridge command (publish quality + README score via `repo-signal`).
* Added Audit as item 8 in HAL menu OBSERVE section (total 16 items).
* Documented HAL Audit in `docs/COMMANDS.md` and README quick-reference.

## [0.3.9] - 2026-05-17

### Added

* Added `mqlaunch hal release-brief` bridge command.
* Added `release-brief` to HAL bridge usage text.
* Updated HAL menu OBSERVE section: Release Brief is now item 2; total 15 items.
* Documented HAL Release Brief in `docs/COMMANDS.md`.
* Added `brief`, `release-brief`, `repo-status`, and `ci` to README quick-reference.

## [0.3.8] - 2026-05-17

### Added

* Added `mqlaunch hal repo-status` bridge command.
* Added `mqlaunch hal ci` bridge command.
* Updated HAL menu OBSERVE section: added Repo Status (2) and CI Status (3); items renumbered to 14.
* Documented HAL Repo Status and CI Status in `docs/COMMANDS.md`.

## [0.3.7] - 2026-05-17

### Added

* Added `mqlaunch hal brief` bridge command.
* Rewrote HAL bridge (`hal-bridge.sh`) with `mq_hal_main` entry point, robust help text, and cleaner subcommand routing.
* Rewrote HAL menu (`mq-hal-menu.sh`) as a standalone grouped menu (Observe, Plan, Memory, Debug) with box-drawn prompts; no `surface_*` dependency.
* Updated smoke test (`tests/hal-menu-smoke.sh`) to 5 checks including brief coverage.
* Added HAL Brief section to `docs/COMMANDS.md`.

## [0.3.6] - 2026-05-16

### Added

* Added interactive `mqlaunch hal` menu (`terminal/menus/mq-hal-menu.sh`).
* Added HAL menu smoke test (`tests/hal-menu-smoke.sh`).
* Documented HAL menu in README and `docs/COMMANDS.md`.

## [0.3.5] - 2026-05-16

### Added

* Added `mqlaunch hal timeline` bridge command.
* Documented HAL Timeline UI in README and command reference.

## [0.3.4] - 2026-05-16

### Added

* Added `mqlaunch hal session`, `mqlaunch hal last`, `mqlaunch hal remember`, and `mqlaunch hal memory-path` bridge commands.
* Added HAL Session Memory section to README and command reference.

## [0.3.3] - 2026-05-16

### Added

* Added `mqlaunch hal fix-doctor` bridge command for HAL Fix Planner.
* Documented HAL Fix Planner in README and command reference.

## [0.3.2] - 2026-05-16

### Added

* Added `mqlaunch hal doctor` — delegates to `mq-hal doctor-summary` for local doctor JSON summaries and safe next-step recommendations.
* Added HAL Doctor Summary docs to README and `docs/COMMANDS.md`.

## [0.3.1] - 2026-05-16

### Added

* Added `mqlaunch hal` bridge — local Ollama-powered safe command router via [mq-hal](https://github.com/MCamner/mq-hal).
* Added `hal)` route in `dispatch_cli_command` and `run_arg_command`.
* Added `terminal/bridges/hal-bridge.sh` with `mq_hal_run()`.
* Added HAL bridge docs to README and `docs/COMMANDS.md`.

### Fixed

* Fixed `mqlaunch hal` routing — `dispatch_cli_command` catch-all was intercepting `hal` before `run_arg_command` could handle it.
* Removed stale `hal` alias from `apps|hal|guide-ai` case; old terminal guide still reachable via `guide-ai`.

## [0.3.0] - 2026-05-16

### Fixed

* Fixed `mqlaunch doctor --json` arg passthrough — `dispatch_cli_command` was calling `doctor.sh` without forwarding flags, silently dropping `--json` and returning ANSI output instead of JSON.
* Fixed `doctor --json` summary counts — subshell `$(...)` calls lost counter updates; replaced with in-process string accumulation.
* Fixed `read_menu_choice` prompt rendering — `vared` (ZSH ZLE) was clearing below-cursor content on init, erasing bottom separator and hint. Replaced with plain `read`.
* Fixed `read-only variable: status` ZSH error in release menu — renamed conflicting locals to `files_status` / `exit_code`.
* Fixed mq-help-menu.sh function name collisions — guarded standalone `print_header`/`print_footer`/`row` etc. so they only activate outside mqlaunch context.
* Fixed `x` and `exit` not working as back/quit in all 13 submenus.

### Added

* Added `doctor --json` full output: `project`, `version`, `status`, `checks[]`, `summary{}` per spec.
* Added `docs/COMMANDS.md` — complete command reference for all mqlaunch commands, menus, env vars, and exit shortcuts.
* Added `x` / `exit` as back shortcut in all submenu prompts.
* Added prompt hint text: `>> option, mqlaunch command, shell command, or x to exit`.
* Added VERIFY section to Tools menu (doctor, doctor --json, selftest, smoke test).

## [0.2.4] - 2026-05-15

### Fixed

* Fixed Document Functions submenu prompt missing separator lines — pre-draws full separator block before input using cursor repositioning, matching all other menu prompts.
* Fixed subprocess menus (git, release, themes, shortcuts, login) converted to in-process sourced modules — eliminates exiting mqlaunch on return.
* Removed stale Git Menu option from dev menu and renumbered options 10–14.

### Added

* Added submenu prompt separator template to `.claude/templates/` for future reference.
* Updated `tools/scripts/README.md` with status table entries for brew-check, port-scan, focus, env-snap, and cleanup scripts.

## [0.2.3] - 2026-05-12

### Added

* Added `mq-repo-signal-check.sh` — wrapper that runs `repo-signal publish-checklist . --fail-under 14` as a release gate.
* Added repo-signal check to `mq-release-check.sh` — blocks release if publish checklist score is below threshold.
* Added option 12 (Repo Signal Check) to `mqlaunch` release menu.
* Added `MQ_REPO_SIGNAL_FAIL_UNDER` env var to configure publish checklist threshold without hardcoding.
* Added `ROADMAP.md`, `.github/ISSUE_TEMPLATE/bug_report.md`, and security note to README so `macos-scripts` scores 16/16.

## [0.2.2] - 2026-05-10

### Changed

* update shell scripts
* add: auto-update wiki Command-Reference on release
* add: wiki Command-Reference generator
* update shell scripts
* update shell scripts
* update shell scripts
* fix: separator lines match panel width and use white color
* fix: match prompt separator width to actual panel width
* refactor: extract themes menu to separate script
* fix: themes menu header matches tools menu — dashboard then panel
* fix: use clear_screen instead of print_header in themes menu
* fix: remove duplicate host row and add themes label in themes menu prompt
* fix: consistent surface style for themes menu, rename option 7
* fix: remove redundant push in auto_release (release.sh already pushes)
* feat: add Auto comment option to Document Functions menu
* update project files
* update project files
* update project files
* update shell scripts
* update project files
* update project files
* update shell scripts
* update project files
* update project files
* update shell scripts
* update project files
* update project files
* update project files
* update project files

---

## [0.2.0] - 2026-05-06

### Changed

* Improve demo mode — pause_enter between steps, add AI and release commands
* Fix all 16 markdownlint errors in README.md
* Update README — add AI/Atlas/nickname/release sections, fix lint
* gitlaunch: replace 9. EXIT with b. BACK
* Git menu: remove option 9 (git log), b/9 both map to Back
* Auto-generate changelog section from git commits before dry run
* update documentation
* Prompt to open CHANGELOG before dry run if version section is missing
* Add nickname support — shown in header, set via mqlaunch nickname-set
* Intercept atlas at entry point before dispatch reaches ai-mode.sh
* Fix atlas routing — source ai-prompts directly in mqlaunch.sh
* Add Atlas REPL — interactive AI session with mq atlas
* Add git push --tags between live release and GitHub release in auto_release
* Add Auto Release (option 11) to release menu
* Fix ask usage hint to English on main menu
* Add mqlaunch chat — conversational AI mode with memory
* Show ask usage hint on main menu start page
* Add AI section to command index and help text
* Use read_main_choice in help menu for consistent prompt style
* Add pause_enter after ask in REPL so answer stays visible
* Fix ask routing in REPL — zsh no-split bug
* Fix ask.sh truncating multiline responses
* update shell scripts
* update shell scripts
* Fix cmd variable name in unknown command fallback
* update project files
* Route unknown commands to /ask in command-mode layer
* Improve mqlaunch ask UX and fallback
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts
* update shell scripts

---

## [0.1.8] - 2026-05-05

### Added

* Slash commands `/doctor`, `/scan`, `/atlas`, `/release-check` wired into main menu dispatch
* `pause_enter` after slash command output so menu does not redraw before user reads result
* gitlaunch prompt with separator lines and direct 1-9 key input (no arrow keys)
* Missing helper functions (`print_section`, `pass`, `fail`, `warn`) in release check script

### Changed

* Slash command dispatch no longer falls through to shell runner on recognized commands
* `/ask` now passes question text through to `mq_ai_prompt_ask`
* Prompt separator width pinned to same value used when drawing the box above it
* Added breathing room (blank rows) around Command Surface figures
* `release-check` displayed as `/release-check` in main menu for consistency
* `check_changelog_matches_commits` now runs before "Status: release-check complete" line

### Fixed

* `/ui`, `/doctor` and other slash commands doing nothing when typed in main menu
* `/atlas` routing to `safe_run_ai atlas` instead of missing `atlas.sh`
* `mq_ai_prompt_review` and `mq_ai_prompt_ui` falling through to shell on missing helper

---

## [0.1.7] - 2026-04-29

### Added

* AI skill prompt commands (`/review`, `/ui`, `/ask`) in mqlaunch main menu
* Release check command (`/release-check`) integrated into mqlaunch
* Repo question prompt command (`/ask`)
* Doctor checks improved and integrated into release check

### Changed

* Document release check workflow
* Show new commands in main menu panel

---

## [0.1.6] - 2026-04-23

### Added

* Add changelog template initialization for new releases

### Changed

* Improve release workflow validation
* Refine release script behavior for smoother version preparation

### Fixed

* Prevent release attempts from proceeding without a matching changelog entry

---

## [0.1.5] - 2026-04-22

### Changed

* Fix release dry-run flow
* Update shell scripts and wrapper behavior
* Refine release process for consistent versioning

---

## [0.1.4] - 2026-04-13

### Changed

* Clarify README structure
* Improve repo presentation
* Strengthen quick start and demo flow

---

## [0.1.3] - 2026-04-11

### Changed

* Improve release script with dry-run support and rollback handling
* Enhance release workflow safety and validation

---

## [0.1.2] - 2026-04-11

### Added

* Initial release automation script (`tools/release.sh`)

### Changed

* Improve version badge handling in README
* Refine release preparation workflow

---

## [0.1.1] - 2026-04-11

### Added

* About and status dashboard in `mqlaunch`
* Release notes and changelog command

### Changed

* Align README, help, command index, and menu labels

---

## [0.1.0] - Initial release

### Added

* Base structure for macos-scripts
* Initial mqlaunch functionality
* Core terminal workflows
