# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

* The v2.1.0 Pulse contract — `docs/PULSE_CONTRACT.md` for the ownership
  boundary, `mqlaunch/lib/pulse/model.sh` for the rules that can be executed,
  `tests/pulse-contract-smoke.sh` for the gate. PR 1 of the sequence, landed
  before the first collector so that nothing depends on a rule still being
  decided.

  Five check states — `PASS`, `WARN`, `FAIL`, `UNAVAILABLE`, `SKIPPED` — and
  four exit codes: `0` healthy, `1` warnings, `2` failures, `3` Pulse could not
  complete. Two decisions the roadmap left open are made in the model rather
  than in prose:

  ```text
  PASS UNAVAILABLE   → WARN / 1    not a silent pass, not a failure
  FAIL SKIPPED       → FAIL / 2    a skip cannot lower a verdict
  SKIPPED            → INCOMPLETE / 3   nor stand in for a measurement
  (no checks)        → INCOMPLETE / 3
  ```

  `UNAVAILABLE` ranks with `WARN` because exiting 0 for a check that could not
  run is the silent pass the contract exists to forbid, one level down where a
  script reads it — and exiting 2 would claim the check was measured and found
  broken. A run with nothing contributing is `INCOMPLETE` because Pulse holds no
  signals of its own; the alternative makes the healthiest-looking run the one
  where every collector failed to register.

  The gate carries a 15-run truth table and was proved able to fail against four
  planted defects: `UNAVAILABLE` ranked as `PASS`, an empty run reporting
  `PASS`, a `pulse` dispatch arm running the network diagnostic again, and
  `pulse` re-added as an alias of `netpulse`.

### Changed

* `mqlaunch pulse` is now `mqlaunch netpulse`. The Wi-Fi and latency diagnostic
  is unchanged — same script, renamed to `tools/scripts/netpulse.sh`, same
  output, same colour contract, still on the `ops` help group — but it no longer
  holds the word every line of the v2.1.0 plan is addressed to.

  No alias was kept. `mqlaunch pulse` reaches the existing unknown-command path,
  which already answers with the nearest match:

  ```text
  ERROR: Unknown command: pulse
  Did you mean: mqlaunch netpulse
  ```

  A deprecated alias would have been the softer move and the wrong one: one word
  belongs to one command, and leaving `pulse` resolving to the diagnostic is
  exactly the overlapping command surface v2.0.0 spent a release removing.
  `mq pulse` on the secondary CLI moved with it.

### Fixed

* `terminal/themes/mq-theme-manager.sh` could only run from
  `$HOME/macos-scripts`. It read `${HOME}/macos-scripts` outright, where
  `tools/scripts/doctor.sh`, `tools/scripts/scan.sh` and — since #172 —
  `mq-zsh-theme-switcher.sh` all read
  `${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}`. This is the sibling #172 named
  and deliberately left alone.

  Measured with `HOME` pointed away from the checkout:

  ```text
  list      exit 0
  current   exit 0
  reset     exit 0
  apply     exit 0
  preview   exit 1   line 140: .../macos-scripts/ui/terminal-ui/mq-ui.sh
  ```

  Only `preview` reads `BASE_DIR`, through `UI_LIB`, which is why this stayed
  invisible: four of the five verbs work anywhere, and on a developer machine
  `$HOME/macos-scripts` exists so the fifth does too.

  `THEME_FILE` is untouched at `${HOME}/.mq-theme`. The selected theme is user
  state, the same class as `~/.zshrc`, and belongs in `$HOME` wherever the
  checkout lives.

  `tests/theme-manager-path-smoke.sh` runs the manager from a temporary tree
  holding nothing but a symlinked `ui/`, requires `preview` to render its panel
  rather than merely exit 0, and drives the other four verbs through
  apply → current → reset. Proven able to fail: with the hard-coded path put
  back it stops at step 2.

  Every run gets its own `HOME`, and the last step compares a checksum of the
  real `~/.mq-theme` from before the test. `apply` writes and `reset` deletes
  that file, and a probe against a real `HOME` earlier in this work applied a
  theme to the machine running it — the suite does not get to do that.

* The menu family disagreed about what it returns without a terminal. Measured
  headless, all ten local menus ended at their own prompt on EOF and three
  answered differently:

  ```text
  git release shortcuts tools workflows dev performance   exit 0
  system theme apps                                       exit 1
  ```

  `apps` is a third outlier the first sweep missed, having read it as an AI
  command and excluded it on cost. `hal` was in the sweep and answered 0, but
  it is not on this list: it delegates to `mq_hal_run`, a bridge into the
  mq-hal repo, so its status is the delegate's and 127 on a machine without
  mq-hal is the correct answer. The contract covers ten local menus.

  #168 had already settled which answer is right: a menu loop exits non-zero
  without a terminal by design (`tests/menu-eof-smoke.sh`), so propagating that
  reports "the command failed" for "there was no terminal". All three now take
  the split #168 gave `workflows` — the menu path returns 0, the argument path
  is untouched. `system bogusverb` still exits 2, `theme apply bogus` and
  `theme bogusverb` now exit 2 as well (see the entry below), and a failed
  `apps ask` still carries its status.

  **Step 7 of `tests/delegated-exit-code-smoke.sh` could not have caught any of
  this.** It flags a branch only when the branch both invokes a `$BASE_DIR`
  script and ends in a bare `return 0`. `theme` invokes no script, and the
  mixed shape — deliberate 0 on one path, propagation on the other — is not
  what the pattern describes. Applying the fix then made the step fail for the
  wrong reason: `system` and `apps` do call scripts, and now hold a deliberate
  `return 0`.

  Rather than reword the rule until it passed, the step now carries a named
  exception list with the reason beside each entry, and honours an entry only
  when the same branch propagates somewhere. An exception therefore cannot
  cover a branch that discards status on every path, and an entry describing a
  branch that no longer looks that way fails the step instead of passing
  quietly. The behavioural proof is separate: step 10 grew to ten propagating
  paths, step 11 to eight deliberate zeros, and step 12 stubs
  `hal-terminal-guide.sh` through a fake `BASE_DIR` to observe both `apps`
  paths.

  Both gates were proven able to fail. Restoring the `theme` defect stops the
  run at step 11; removing the propagating path from `apps` stops it at step 7.

  One more thing the fix surfaced: lifting the menu case into a guard above the
  `case` removed the literal `menu)` arm, and the registry validator reads that
  arm to confirm the declared subcommand exists. The menu path went back inside
  the `case` and returns 0 from within it.

* An invalid `theme` argument reported 1 where the rest of the surface reports
  2. `mqlaunch system bogusverb` has always answered 2, and so does the `srm`
  namespace; `mq-zsh-theme-switcher.sh` answered 1 for an unknown command word,
  for `apply` with no variant, and for a variant that does not exist. 1 is the
  code a caller reads as "the theme could not be applied" rather than "that is
  not a theme". All three are 2 now.

  The runtime failures keep 1 — a missing UI library, a missing theme file —
  because the distinction is the point of using 2 at all.
  `tests/theme-command-surface-smoke.sh` was unaffected: its exit-code step
  stubs `theme_cmd` with an arbitrary status and asserts propagation, not a
  particular value.

  `tests/menu-exit-contract-smoke.sh` holds the whole contract end to end
  through `bin/mqlaunch` rather than through stubs, on both surfaces: ten local
  menus exit 0 without a terminal and draw their prompt
  exactly once, the same holds on a real pty whose stdin is closed, four
  operations still report their own result, four usage errors are 2, and
  `repos` keeps 1 as the documented exception — it asks for a
  terminal-dependent picker while offering headless subcommands, so "there was
  no terminal" is the true answer there. Proven able to fail: putting `theme
  apply` back to 1 stops it at step 6, and letting the theme menu propagate
  again stops it at step 2.

  Writing that test found a second thing. `mq-zsh-theme-switcher.sh` resolved
  its own root as `${HOME}/macos-scripts` outright, where
  `tools/scripts/doctor.sh` and `tools/scripts/scan.sh` both read
  `${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}`. A checkout anywhere else could
  not run the switcher at all — it exited 1 with `Missing UI library` before
  reaching its first command. It uses the same resolution as its siblings now.
  (`terminal/themes/mq-theme-manager.sh` still hardcodes the path; it is
  untouched here and outside this change.)

  That also made the runtime branch testable without side effects. `apply` with
  a valid variant rewrites `$ZSHRC`, and a first version of the step tried to
  steer it by setting `THEME_FILE` — which the switcher assigns
  unconditionally and never reads from the environment, so the override did
  nothing and the theme was applied to the machine running the suite.
  `MACOS_SCRIPTS_HOME` is the handle that works: the step now runs the switcher
  against an isolated tree and an isolated `HOME`, requires exit 1 and the
  `Missing theme file` message, and requires that no `.zshrc` was written on
  the way to that verdict.

* The two commands the P2 operator inventory measured as unclear when called
  with no argument. Both answered with something the operator had not asked
  about:

  ```text
  $ mqlaunch skills
  usage: mq-skills.py [-h] [--repo REPO] {audit,validate,new} ...
  mq-skills.py: error: the following arguments are required: command   exit 2

  $ mqlaunch repos
  GitHub repo picker needs a terminal.                                 exit 1
  ```

  `skills` handed over the delegate's file name and argparse's phrasing for a
  command typed as `mqlaunch skills`. `repos` named a subject that never
  appeared in the command line — bare `repos` routes to the hub, which is an
  interactive picker — and offered no way forward, though six `repos`
  subcommands work headless. Now:

  ```text
  $ mqlaunch skills
  Usage: mqlaunch skills <command> [args]

  Commands: audit, validate, new                                       exit 2

  $ mqlaunch repos
  mqlaunch repos with no command opens the repo hub, which needs a terminal.

  Usage: mqlaunch repos <command> [args]

  Commands: list, status, roadmaps, skills, wiki-status, diff-summary   exit 1
  ```

  Message, usage and next step only. Nothing underneath changed, and both exit
  statuses are deliberately what they already were: 2 for `skills`, because a
  missing verb is a usage error either way, and 1 for `repos`, because bare
  `repos` is valid on a terminal — the failure is the environment, not the
  command line, so no caller's exit-code handling moves.

  Two things left alone on purpose. An invalid `skills` verb still goes to the
  delegate: its error names the word the operator typed, and intercepting it
  would mean carrying a second copy of the verb list. And on a terminal, bare
  `repos` still opens the hub — `tests/operator-usage-message-smoke.sh` asserts
  that with a stubbed hub under a pty, alongside `skills audit`, `skills bogus`
  and `repos list` still reaching their delegates. A fix that stopped
  delegating would pass a message-only check.

* The two colour surfaces that never went through the shared library, and so
  never inherited the P1 output contract. `tools/scripts/pulse.sh` defines its
  own six colour variables; `tools/cli/mq-ui.sh` defines four more and is
  sourced by `scan.sh`, `brew-check.sh` and `doctor.sh`. Both assigned the
  escapes unconditionally, so redirecting stdout wrote them into the file and
  neither `NO_COLOR=1` nor `--no-color` removed one:

  ```text
                     before  after     on a real terminal
  mqlaunch pulse         20      0     20 colour escapes, unchanged
  mqlaunch scan          36      0     34 colour escapes, unchanged
  mqlaunch doctor         -      0
  ```

  Both files now gate on `[[ -t 1 && -z "${NO_COLOR:-}" ]]`, the same condition
  the central guard in `ui/terminal-ui/mq-ui.sh` uses.

  Two details the measurement turned up that reading would not have. `pulse.sh`
  opened with a bare `clear`, which writes `^[[3J^[[H^[[2J` to a pipe whenever
  it can read a terminfo entry — three escapes ahead of the first line of the
  report, and invisible in a run with `TERM` unset. It is now gated on `-t 1`
  alone, matching `clear_screen()`: a screen clear is a terminal action, not
  colour, and every other mqlaunch screen still clears under `NO_COLOR`. And
  `blink_err` carried a literal `\033[5m` inside its own `printf` format, so it
  would have kept leaking one escape per call after the colour variables were
  emptied; the blink moved into a guarded `C_BLINK`.

  Only the escapes are conditional. The ASCII banner, the headings, the box
  rules and the `✔ ⚠ ✖` glyphs are untouched, and
  `tests/pulse-cli-color-contract-smoke.sh` checks that half explicitly —
  suppressing colour by dropping output would otherwise pass a bare "no ANSI"
  check. It stubs the Wi-Fi and network probes so every colour branch fires,
  compares the colour and plain runs line by line, and drives the real path
  under a pseudo-terminal. `mqlaunch scan` with `NO_COLOR=1` emits zero colour
  escapes and 5708 bytes, against 5426 with colour: the output grew.

* The seven remaining branches that called a shell-function delegate and then
  discarded its status. Each was measured with the delegate stubbed to exit 7
  before deciding anything, and the measurement split them in a way reading them
  would not have:

  ```text
  review-brain    operation            0 -> 7   mq-agent review repo --brain
  signal-brain    operation            0 -> 7   mq-agent signal --brain
  learn-promote   operation            0 -> 7   mq-agent learn promote --approve
  workflows save  operation            0 -> 7   with a subcommand
  login status    operation            0 -> 7   with arguments
  shortcuts list  operation            0 -> 7   with arguments
  workflows       menu                 0 -> 0   deliberate
  login           menu                 0 -> 0   deliberate
  shortcuts       menu                 0 -> 0   deliberate
  atlas           interactive session  0 -> 0   deliberate
  ```

  `learn-promote` is the one that matters most: it runs
  `mq-agent learn promote <slug> --approve`, a Class C write, and reported
  success whatever happened.

  **Three of them are mixed, which is why a per-branch answer would have been
  wrong.** `workflows`, `login` and `shortcuts` open a menu when called bare and
  run an operation when given arguments. A first attempt propagated the status
  in both cases and the full suite stayed green — but `mqlaunch shortcuts` with
  no terminal went from exit 0 to exit 1, because a menu loop exits non-zero on
  EOF by design (`tests/menu-eof-smoke.sh`). Propagating there reports "the
  command failed" for "there was no terminal". The suite did not catch it; running
  the real command did. Only the argument path propagates now.

  `atlas` is an interactive session in both forms and returns 0 on purpose.

  Steps 10 and 11 pin both halves — six operation paths propagate, four
  interactive entrypoints return 0 — so the deliberate half cannot later be
  mistaken for the bug and "fixed".

### Fixed

* `mqlaunch brain` and the seven verbs beside it reported success no matter what
  the bridge did. Both branches ended in an unconditional `return 0` after
  calling `mq_brain_run`, so a failing brain command exited 0 and a script could
  not tell that anything had gone wrong.

  `tests/delegated-exit-code-smoke.sh` step 7 already forbids exactly this, and
  it did not catch it: the structural check only inspects branches that invoke a
  `$BASE_DIR/...` script, and `mq_brain_run` is a shell function. The rule was
  right and its reach was short.

  Step 8 runs the branches instead of reading them — `mq_brain_run` stubbed to
  exit 0, 1, 2 and 127, across all eight verbs (`brain`, `note`, `sessions`,
  `decisions`, `reviews`, `learn`, `verified`, `systems`) — and was red on the
  old code. Step 9 pins the `else` arm that was already correct, so fixing the
  success path could not turn a missing bridge into a silent success.

  Verified on the real path: `mqlaunch brain not-a-real-verb` exits 1, where it
  exited 0 before.

  Not fixed here, and deliberately: seven other branches call a function
  delegate and then `return 0` — `workflows`, `review-brain`, `signal-brain`,
  `learn-promote`, `atlas`, `login`, `shortcuts`. Several open interactive menus,
  where the exit status of the menu is not obviously the thing to propagate, so
  each needs a judgment this PR was not scoped to make. Sweeping them together
  would have hidden that.

### Removed

* `tools/scripts/srm.sh` — 156 lines that built a system prompt and called
  `https://api.openai.com/v1/responses` directly with `file_search` against a
  hardcoded vector store, reached by `mqlaunch srm ask|search|inspect` and by any
  unrecognised word after `srm`.

  Retired rather than moved, because the capability already existed at its owner:
  `mq-agent memory status` reports the *same* vector store,
  `vs_69ffa9a4ef5c81919d7d237c3ecdc260`, through repo-signal and mq-mcp. The
  local path was a second route to the same memory, around the repo that owns
  it. `ask` and `search` were one query with two spellings and are
  `mq-agent memory search` now; `inspect` is `mq-agent memory status`.

  The fall-through is gone with it. Sending any unrecognised word to an LLM is
  what ROADMAP.md calls a v2.0.0 non-goal — "do not introduce hidden AI fallbacks
  for unknown commands" — and an unknown verb prints usage and exits 2. The
  rejection sits in an explicit `*)` arm inside the nested case rather than after
  it, so the registry can state `unknown_subcommand: reject` and
  `validate-command-registry.py` can see that it does.

  `srm` therefore delegates every verb and its owner is `mq-agent`, not
  `macos-scripts`. `LOCAL_ROLE_EXEMPT` is empty, the quick-command gate covers
  the whole local surface with no exception, and
  `tests/command-registry-smoke.sh` step 23 now fails on any entry rather than on
  any entry other than `srm`.

  Two tests pinned the retired behaviour and were retargeted, not deleted.
  `tests/command-word-normalization-smoke.sh` step 4 checked that a free-form
  question reached `srm.sh` with its case intact; the rule it protects — only the
  command word is normalised — is now asked of `srm SEARCH "What does HAL do"`.
  `tests/mq-agent-routing-smoke.sh` gained steps 12 and 13: every verb reaches
  mq-agent, `srm.sh` is absent, no OpenAI endpoint is reachable from the route in
  code, and an unknown verb prints usage.

  One defect found while verifying the real path and fixed here: `memory status`
  defaults to `.`, and `_run_agent` runs inside `$MQ_AGENT_BIN`, so
  `mqlaunch srm inspect` reported `repo: /Users/mansys/mq-agent` instead of the
  operator's directory. It supplies `$PWD` when no path is given and never
  overwrites an explicit one — the same shape as `_flow_has_repo_flag`.

### Added

* `local_role` — the positive rule for what a command this repo owns is allowed
  to be. `owner: macos-scripts` used to say only "not delegated", so a command
  could drift into orchestration, execution or memory and the registry would
  record nothing unusual. All 60 local commands are now classified by what their
  own code owns rather than by what they open: 28 `terminal-ux`,
  14 `host-operation`, 17 `thin-entrypoint`, and one exemption.

  `validate-command-registry.py` fails a local command with no role, a role
  outside the three, a `local_role` on a command another repo owns, and an exempt
  command that also classifies. Four negative fixtures in
  `tests/command-registry-smoke.sh` prove each rule fires.

  **The exemption is `srm`, and it is the finding.** Its first four verbs
  delegate to `mq-agent memory-*`; everything else falls through to
  `tools/scripts/srm.sh`, 156 lines that build a system prompt and call
  `https://api.openai.com/v1/responses` directly with `file_search` against a
  hardcoded vector store. That is semantic memory cognition in shell — memory
  belongs to mqobsidian, orchestration to mq-agent, and "do not implement memory
  promotion in shell" is a v2.0.0 non-goal. Classifying it `thin-entrypoint`
  would have recorded the breach as approved, so it is named in
  `LOCAL_ROLE_EXEMPT` with the reason and the removal condition beside it. The
  smoke test fails if that list ever holds anything other than exactly `srm`, so
  a second breach cannot be resolved by naming it.

  No runtime changed. The `srm` fix is a separate PR.

  Noted while classifying and deliberately not resolved: `ask`, `fix` and `chat`
  call the same OpenAI endpoint from their own scripts. They are classified
  `thin-entrypoint`, which is accurate about their four-line dispatch arms and
  says nothing about what those scripts own.

### Fixed

* The `stack` route named three of mq-agent's sixteen verbs and omitted the one
  the roadmap was waiting for. `mqlaunch stack --help` and `docs/COMMANDS.md`
  both listed `status, contract-check, truth-export`; the release cockpit is
  `mq-agent stack cockpit`, it already worked through `mqlaunch stack cockpit`
  because the route forwards everything, and the word appeared nowhere in this
  repo. An operator had to read mq-agent's help to find it.

  Both surfaces name it now, say that unlisted verbs forward, and state that
  `--json` is an option on the subcommands rather than the group —
  `stack status --json` and `stack cockpit --json` emit machine documents,
  `stack --json` exits 2 from mq-agent. The registry summary went from "Show
  stack status and operations" to "Show stack status and the read-only release
  cockpit", so help says it too.

  No routing change, and no `mq-agent` change. A bare `mqlaunch stack` still
  means `mq-agent stack status` — the only local decision on this route — and
  `tests/mq-agent-routing-smoke.sh` steps 10 and 11 now pin that default, the
  verbatim forwarding of every other verb including one this repo has never
  heard of, and the delegate's exit code for 0, 1, 2 and 127. Both steps were
  proved able to fail by planting a defect and watching them report it.

  The roadmap task this closes had been waiting since it was written for
  `mq-agent ship status`, a command that does not exist and is not planned.
  `mq-agent --help` lists 34 commands; the cockpit shipped under `stack`.

* `mqlaunch review file <path> --repo <repo>` reviewed the wrong thing. `--repo`
  was accepted here as a scope selector — an undocumented alias for
  `review repo` — and it also happens to be a real mq-agent option on
  `review file`, naming the external repo the file lives in. The scope arm won,
  so the path was dropped and the invocation became `review repo <repo>`: an
  entire repository reviewed instead of the one named file, silently, with the
  operator's argument read as the repo. The option was unreachable from the
  launcher.

  Scope is positional now — `diff`, `repo`, `file <path>` — which is the only
  form `docs/COMMANDS.md` ever documented. The `--diff`, `--repo` and `--file`
  spellings are gone, and anything unrecognised falls through to passthrough, so
  mq-agent options reach mq-agent.

  Found by reviewing the delegation handlers for the P2 roadmap item rather than
  by a report. The three existing routing assertions could not have caught it:
  they grep `mq-agent-menu.sh` for the strings it should contain, which proves
  the file mentions `_run_agent review file` and nothing about what an operator's
  arguments turn into. `tests/mq-agent-routing-smoke.sh` steps 8 and 9 run the
  translation against a stubbed delegate and compare the built command line —
  red on the old code, and the nine documented forms are pinned with it.
  Verified end to end through `mq-agent --dry-run`: `review file README.md
  --repo ~/mq-agent` now reaches `mq-mcp review_file README.md
  repo_path=/Users/mansys/mq-agent`.

* The three behaviour defects the performance golden pinned. One commit each,
  the golden red before the fix and regenerated after it.

* Seven of the nine Performance screens printed `print_section: command not
  found` where a heading belongs — eleven error lines, counting the two
  `print_kv` and one `print_divider` in Quick Watch. All three helpers lived
  only in the frozen v1 tree's `lib/ui.sh`, and the live path never sourced that
  file: `mq-performance-menu.sh` sources `mq-ui.sh` and the data layer, nothing
  else. Rows 3 to 9 have been broken for as long as this path has existed.

  Restored verbatim from `94d0eba` into `mqlaunch/lib/performance.sh` rather
  than into `ui/terminal-ui/mq-ui.sh`, because this file is their only caller
  and `terminal/release/mq-release-check.sh` already carries its own
  `print_section`. Guarded with `command -v`, so a later definition in the UI
  authority wins without this one having to be removed first.

* `Load (1m)` showed all three load averages glued together — `1.501.251.10`.
  `perf_load_1m` split `uptime` on `", "` while macOS separates the figures with
  spaces, so it kept all three and `tr -d ' '` closed the gaps. The same value
  appeared in the menu's Signals row. It splits on whitespace now, verified on
  both formats: macOS `load averages: 1.50 1.25 1.10` and Linux
  `load average: 0.15, 0.20, 0.18`.

  The masking had to go first, and that is the more useful half of the change.
  `<LOADAVG>` covered exactly the field the bug lived in, so the golden could
  not have gone red on a fix — and the malformed value matched the IP rule, four
  dot-separated groups being what `1.501.251.10` looks like, so the fixture read
  `Load (1m): <IP>`. Those lines pass through unmasked now.

* Quick Watch could not stop. It refreshed until something killed it, and the
  loop did not trap `SIGINT`, so Ctrl+C took the whole `mqlaunch` session rather
  than returning to the Performance panel. With no terminal there was no way out
  at all.

  A trap sets a flag the loop checks and `trap - INT` restores the caller's
  handling; the loop also breaks after one frame when there is no tty or
  `MQ_NO_TUI` is set, matching the guard `open_git_menu` already uses. Proven
  against the pre-fix code: `SIGINT` mid-watch used to kill the caller and now
  returns to it with status 0. With a real pty it still refreshes — six frames
  in nine seconds — so the guard is not firing where it should not.

  All nine screens exit 0 now, where the golden used to record a 124.

### Added

* `tests/performance-screens-golden-smoke.sh` and
  `tests/fixtures/performance-screens.golden` — the snapshot
  `docs/plans/step-12-v1-removal.md` asked for as 12.3 and never got.

  The plan gated the performance migration on a golden of its output. That
  fixture was never written, so 12.4 shipped verified by looking at the rendered
  panel, which proves the panel and not the nine `command_perf_*` screens behind
  it. All nine are live: rows 1–9 of the Performance menu call them directly.

  Reconstructed after the fact from a worktree of `94d0eba`, the commit before
  the migration, and compared screen by screen — stdout, stderr and exit status.
  **All nine matched**, and the committed golden was then verified against the
  pre-migration implementation as well, so it pins the behaviour the migration
  was supposed to preserve rather than whatever happens to be true now.

  `tools/scripts/normalize-performance-screen.py` masks only what is volatile:
  paths, load averages, uptime, timestamps, IPs, sizes, percentages, `ps` rows
  and `du` rows. Labels, section headings, box drawing, row counts, ordering and
  error text pass through. Step 3 of the test asserts the golden still carries
  eight of those labels, because a normalizer can be tightened until everything
  masks to the same thing and the comparison passes vacuously. Step 4 renders
  against a copy of the data layer with one character changed in a heading and
  requires the diff to show it.

  The system commands are stubbed (`tests/fixtures/perf-stubs`) so the fixture
  is a rendering snapshot rather than a photograph of one laptop. The first
  version captured this machine's battery, load and process list and failed CI,
  which runs Linux and has no `pmset`. With the inputs fixed, almost nothing
  needs masking, which makes the comparison sharper rather than looser.

  **The golden pins four defects, all pre-existing and all found by writing
  it:**

  * `print_section: command not found`, eleven times. Seven of the nine screens
    call `print_section` and one also calls `print_kv`; both live only in the v1
    tree's `lib/ui.sh`, which the live path never sourced — `mq-performance-menu.sh`
    sources `mq-ui.sh` and the data layer, nothing else. Rows 3 to 9 have been
    printing that error instead of a heading for as long as this path existed.
    Verified identical on `94d0eba`, so neither the migration nor the deletion
    caused it.
  * `Load (1m)` renders as one run of concatenated decimals — `1.541.481.58`.
    `perf_load_1m` splits `uptime` on `", "` while macOS separates the three
    load averages with spaces, so it keeps all three and `tr -d ' '` glues them.
    The same value appears in the menu's own Signals row.
  * `command_perf_quick_watch` cannot exit on its own. It is bounded in the
    harness and its status in the golden is the timeout's 124.
  * `awk -v load=...` in `perf_health_score`. `load` is a gawk builtin, so gawk
    rejects it as a variable name and the whole health score fails on any system
    with GNU awk. BSD awk on macOS accepts it, which is why it went unseen for
    as long as this code has existed.

  The fourth is **fixed** here, because it is what kept the test from being a CI
  gate at all — CI runs Linux. The variable is renamed and nothing else changed;
  the golden is unchanged on macOS, which is the proof the rename preserves
  behaviour there.

  The other three are recorded, not fixed. They are behaviour changes and this
  branch is a deletion that has to stay revertible.

  Verified as a chain rather than asserted: the pre-migration implementation
  extracted from `94d0eba` renders byte-identical to the committed golden, the
  current one does too, and a one-character change to a heading is reported.

### Removed

* `terminal/mqlaunch-v1/` — 23 files, 1125 shell LOC, plus its own
  `tools/scripts/test-mqlaunch-v1.sh`. The last legacy runtime, and the last
  duplicate UI implementation: it shipped its own `lib/ui.sh` alongside
  `ui/terminal-ui/mq-ui.sh`.

  Its live edges went first, in the PR before this one, which is why this one
  deletes rather than migrates. Four checks were run against `main` before
  anything was removed: the freeze gate reported 0 compat edges; a sweep of
  every tracked `.sh`, `.zsh` and `.py` outside the tree found no `source`,
  `bash` or `exec` reaching it; the 24 files still naming it were all history,
  tests, docs or tooling; and the suite passed after the deletion.

  **Nothing that ran was edited.** Seven tooling files named the tree — to
  exclude it from lint, to test it, or to police it — which is exactly the
  distinction the freeze gate's two lists were built to make:

  ```text
  test-mqlaunch-v1.sh            deleted with the tree
  test-all.sh                    v1 selftest block removed
  test-mqlaunch.sh               v1 launcher assertions removed
  lint.sh                        exclusion had nothing left to exclude
  shellcheck-report.sh           same
  generate-wiki-command-ref.sh   same
  check-runtime-authority.sh     became a tombstone gate
  ```

  The lint surface went from 189 files to 188 and stayed clean at warning
  severity. Four of the five SC2034 findings that `RUNTIME_AUTHORITY.md`
  documented as deliberately exempt left with the tree — they were colour
  variables in its `lib/core.sh` that the scripts sourcing it did read.

  `scripts/check-runtime-authority.sh` keeps running as a tombstone. A path that
  no longer exists cannot be depended on by accident, but it can be recreated,
  and a second runtime is what the v2.0.0 track spent its length removing. Its
  compat list is empty permanently; a non-empty one means the legacy runtime is
  back.

  Three READMEs still claimed performance routed through v1.
  `terminal/bridges/README.md` was 109 lines about a migration that is now
  finished and is rewritten; `terminal/README.md` and
  `terminal/launchers/README.md` are corrected.

  One gap is recorded rather than papered over: `docs/plans/step-12-v1-removal.md`
  called for a golden snapshot of performance output *before* the migration, and
  that fixture was never written. The migration was verified by driving the menu
  before and after — same score, same signals, same rows — which proves the panel
  but not each of the nine `command_perf_*` screens behind it. R1 in that plan's
  risk table is specifically about unnoticed output drift, and its mitigation is
  the step that was skipped.

### Changed

* Nothing live reaches `terminal/mqlaunch-v1/` any more. The freeze gate reports
  **0** compat edges, where it reported four.

  The one that mattered was not a legacy route. `mq-performance-menu.sh:26`
  sourced `commands/performance.sh` out of the frozen tree — 504 lines of
  working `perf_*` readings behind the Performance Hub's health score, signals
  line and ten rows. The tree was classified live in order to supply code, not
  to keep an old path open, which is why "delete the compat tree" was never the
  small job P3's Status line implied. The file moved verbatim to
  `mqlaunch/lib/performance.sh`; it sources nothing and reads only
  `$PROJECT_ROOT`, so it was a move rather than a port. Verified by driving
  `mqlaunch perf` before and after — same score, same signals.

  The other three were retired rather than relocated:

  * `terminal/bridges/tools-bridge.sh` forwarded `tools` to the v1 launcher as
    a subprocess. Deleted — neither `open_v1_tools_menu` nor
    `run_v1_tools_command` had a caller anywhere in the tree.
  * `terminal/bridges/performance-bridge.sh` fell back to the v1 launcher when
    the current menu was missing. A missing menu is a broken checkout, and
    answering it by running a frozen launcher hid that; it reports and returns 1
    now. `run_performance_command`, `open_v1_performance_menu` and
    `run_v1_performance_command` went with it, none of them called.
  * `tools/scripts/create-debug-bundle.sh` ran `bash v1/mqlaunch.sh help` as a
    health probe from `mq-system-menu.sh` option 6. A bundle reporting on a tree
    nothing routes to is noise.

  The dependency runs the other way now: `terminal/mqlaunch-v1/mqlaunch.sh:22`
  sources the data layer from its new home. Legacy depending on live is the
  allowed direction, and it keeps the tree runnable so that deleting it stays a
  decision rather than a consequence of a move.

  `tests/compat-path-delegation-smoke.sh` no longer proves the legacy shim
  forwards correctly and preserves its exit status — there is no shim. It proves
  the shim is absent, that the performance bridge does not name the frozen tree,
  and that it fails rather than falling through when its menu is missing.
  `tests/runtime-authority-classification-smoke.sh` asserted the performance
  menu *is* COMPAT; it now asserts the menu reaches `mqlaunch/lib` and not the
  frozen tree, checked against the menu rather than the map's prose about it.

  `COMPAT_EDGES` in the freeze gate is an empty array, which needed the
  `${arr[@]+"${arr[@]}"}` guard: under `set -u`, bash 3.2 — `/bin/bash` on
  macOS — aborts on an empty `"${arr[@]}"`. Verified under both 3.2 and 5.3.

### Fixed

* `gitlaunch` reported a bad repo argument and then succeeded. Found by driving
  the command on a real machine after #156 put it on `PATH`.

  `gitlaunch` takes a repo path, not a subcommand — the registry's contract for
  `git` is `unknown_subcommand: forward` — so `gitlaunch status` forwarded
  `status` as a path. It printed `Path not found: status`, dropped into the menu
  with no repo, and exited **0**. Three separate places dropped the status:

  * `detect_repo` in `gitlaunch.sh` did `set_repo "$REQUESTED_REPO" || REPO=""`,
    turning an explicit argument the operator got wrong into a silent
    fall-through to detection. An argument that does not resolve is now an
    error, and the message names what the argument is for: `Repo path not
    found: status`.
  * `open_git_menu` ended on a `&&` whose status became the function's, and its
    restart loop treated a failed start as the mid-session crash it is meant
    for — five identical errors before giving up. It now breaks on a non-zero
    exit and returns it.
  * The dispatcher's `git)` arm ended in a bare `return 0`, the same defect the
    theme arm had in #150.

  One pre-existing status had to be corrected for propagation to be safe: the
  no-repo panel's Exit row was `*) exit ;;`, a bare `exit` that inherits the
  previous command's status and had been leaving 1 behind. Harmless while the
  caller discarded it, wrong the moment it is passed on. Now `exit 0`.

  Verified on every path — back `0`, EOF `0`, no-repo Exit `0`, bad path `1` —
  directly, through `mqlaunch git`, and through `bin/gitlaunch`.

### Fixed

* Two of `gitlaunch.sh`'s menu rows were invisible to the command-surface
  inventory, so the loop an operator sees as ten was measured as eight — under
  the gate whose whole subject is how many choices a loop offers.

  `ARM_OPEN`, `ARM_CLOSE` and `ARM_BODY_LINES` were each defined twice in
  `inventory-command-surfaces.py`, and in Python the second definition is the
  one that runs. That copy predated the `KEY` pattern and accepted all-digits or
  all-letters but never the mixed form, so widening `KEY` had no effect on
  multi-line case arms: `7|m|M)` and `8|p|P)` matched nothing.

  The gate still passes at `--max-loop 10` with both rows counted; the total
  option count goes 299 → 301. Step 9 of
  `tests/command-discovery-inventory-smoke.sh` requires two mixed-key rows in
  that menu and fails when the old regex is put back.

### Removed

* `tools/scripts/mqlaunch_desktop.sh`, 1104 lines that nothing started.

  `docs/AUTHORITY_MAP.md` called it an "alternate live entry". No file in the
  repo invoked it — the only two tracked mentions were comments in
  `inventory-command-surfaces.py` explaining why it was *excluded* from the
  command-surface count. It was not in `bin/`, not linked from
  `/usr/local/bin`, not named in a shell rc, and there was no LaunchAgent,
  Raycast or Alfred integration on the machine this was checked on.

  It was a second dispatcher rather than a wrapper: 63 numbered menu arms, its
  own `eval "$cmd"`, and its own vocabulary — `theme-amber`, `theme-green`,
  `theme-ice`, `netlaunch`, `gitlaunch` — none of it in the command registry. It
  knew nothing of `agent`, `obsidian`, `hal`, `theme apply` or `repos`. A
  snapshot of an older mqlaunch, and exactly the shape the map's own "Forbidden"
  rule names: parallel implementations of the same menu responsibility.

  `terminal/menus/mq-git-menu.sh` was live only through it and is now
  DEPRECATED, but kept: `mq-git-menu.sh log|status|…` is a documented entry and
  three tests drive its functions. Nine function names are shared with
  `gitlaunch.sh` and the two have already diverged — `safe_push` is 26 lines
  against 64, `pr_aware_push` takes a different signature and only
  `gitlaunch.sh` refuses to push from a detached HEAD. Two designs, not two
  copies, so the overlap is recorded in the map rather than merged in passing.

### Fixed

* The login flow preferred the frozen v1 launcher over the current runtime.
  `detect_mqlaunch_base` in `automation/login/mqlogin.sh` tried
  `command -v mqlaunch` first and the `mqlaunch-v1` launcher **second**, ahead
  of `terminal/launchers/`. On a machine with `mqlaunch` on `PATH` the first
  branch always wins, which is why nobody saw it; without it, the login flow
  booted into the compat tree. The fallback is now `bin/mqlaunch`.

* The runtime authority freeze gate scanned three directories — `terminal/`,
  `ui/` and `mqlaunch/` — which is narrower than the "live runtime shell" it
  claimed to cover. `automation/` and `tools/` were outside it, so two live→v1
  edges were never recorded: the `mqlogin.sh` fallback above, and
  `tools/scripts/create-debug-bundle.sh:74`, which runs `bash v1/mqlaunch.sh
  help` from `mq-system-menu.sh` option 6.

  The gate now reads `git ls-files` and covers every tracked shell file except
  the v1 tree itself and `tests/`, which drives v1 on purpose. Same source as
  `inventory-command-surfaces.py`, and for the same reason: an untracked copy of
  a menu in the working tree can neither add an edge nor hide one.

  Widening it needed two lists rather than a longer one. `COMPAT_EDGES` is live
  code that reaches v1 at runtime — now four entries, with the debug bundle
  added. `TOOLING` is the seven build, lint and documentation scripts that name
  v1 to exclude, test or police it; deleting v1 would edit those and break the
  others. A single allowlist could not say which.

  `tests/runtime-authority-freeze-smoke.sh` grew from one assertion to four. It
  plants an edge in `automation/` and one in `tools/` so the widened scope is
  proven rather than declared, asserts that every reference to v1 in the repo
  sits on one of the two lists, and drives `detect_mqlaunch_base` with `PATH`
  emptied — the only condition under which the fallback order is observable.
* `install.sh` symlinked `terminal/launchers/mqlaunch.sh` onto `PATH`, which is
  one file past the official entrypoint. `mqlaunch repl` is routed in
  `bin/mqlaunch` and nowhere else — the launcher it execs reports `repl` as an
  unknown command and suggests `mqlaunch repos` — so a fresh install produced a
  working `mqlaunch` with no REPL. Both link targets were verified rather than
  reasoned about: through the launcher, `repl` prints `Unknown command: repl`;
  through `bin/mqlaunch` it does not.

  The installer now links every executable under `bin/`, discovered rather than
  named. That is three commands: `mqlaunch`, `mq`, and the new `gitlaunch`.
  `mq` was in the same position as `gitlaunch` — on `PATH` as a hand-made copy
  that no install step maintains.

  Uninstall follows the same list, and removes only symlinks. A copy sitting at
  one of those names is reported and left alone: uninstall takes back what
  install put there, and a file on `PATH` the repo never owned is not the
  installer's to delete.

### Added

* `bin/gitlaunch`, so the git menu can be reached by typing `gitlaunch` without
  a second copy of it existing.

  `gitlaunch` was on `PATH` as a hand-made copy of
  `terminal/launchers/gitlaunch.sh` — 453 lines dated 25 June against the repo's
  1122. Everything since had reached `mqlaunch git` and not the command the hand
  types: the eight-choice grouping, the 92-column convergence, the protected-push
  guard. Committing to the repo cannot update a copy, which is the argument for
  a link.

  It is a wrapper rather than an entrypoint: `exec bin/mqlaunch git "$@"`. Going
  straight to `terminal/launchers/gitlaunch.sh` would skip the repo argument
  handling and the dashboard-cache invalidation in `open_git_menu`, and would add
  a second way into a command the dispatcher already routes — the class
  `tests/command-discovery-inventory-smoke.sh` holds at zero.

  `tests/install-contract-smoke.sh` installs into a temporary bin dir and
  asserts every entrypoint is linked, that each link resolves into `bin/` rather
  than past it, that the installed `mqlaunch` routes `repl`, and that `gitlaunch`
  hands `git <args>` to the dispatcher — the last one driven through a stub, so
  what is checked is the argv rather than the source text.

### Fixed

* `docs/COMMANDS.md` documented the wrong git menu. `mqlaunch git` opens
  `terminal/launchers/gitlaunch.sh`, whose panel puts safe merge on `7`/`m` and
  PR merge on `8`/`p`, with repo switching under `9. Repo and workspace`. The
  section described `mq-git-menu.sh` instead — ten rows, safe merge on `9`,
  repo actions under `10. Repo and remote` — so anyone reading the docs and
  pressing `9` for a merge got a submenu.

* `tests/runtime-authority-classification-smoke.sh` checked that the authority
  map declares an entry point, never that anything can enter through one. A
  seventh step now requires every path in the entry-point table to sit in `bin/`,
  which `install.sh` links onto `PATH` wholesale, or to be named by a tracked
  file outside `docs/` and `tests/`.

  Comment lines are stripped before that search. The first version of the check
  passed, because the two mentions of the desktop script were comments saying it
  is *not* part of the live surface — prose reads exactly like a caller to a
  grep, which is the mistake one level up from the one being caught.

* The Performance menu executed anything it did not recognise. Its last case arm
  was `*) /bin/zsh -lc "$choice"`, so mistyping a menu number ran the typo as a
  login-shell command — the pattern #137 removed from the HAL menu, left in the
  one menu that was not part of that change, and here without even `|| true`.

  Shell is still reachable, behind the explicit `!` prefix the main prompt
  already advertises. Unrecognised input is reported instead.

  `tests/menu-shell-guard-smoke.sh` holds the rule for every menu, not just this
  one: a static check that no menu hands its choice to a shell, plus a run of
  the real menu, because copying the choice into another variable first would
  pass the static check. Both were proven against planted defects.

* The Performance menu never returned when its input ran out. The fallback
  `read -r choice` discarded the EOF, so the panel redrew as fast as it could
  render, forever. `tests/menu-eof-smoke.sh` covers `mqlaunch perf` and passed:
  on that path `read_main_choice` is defined and its call site does act on the
  return. The defect was in the branch the file takes when it is executed
  directly, which is a supported entry point that no test drove.

### Changed

* The Release menu shows nine choices instead of twelve, and stops printing two
  of them out of position. Option 12 sat inside CHECKS between 4 and 5, and
  option 11 sat inside SHIP between 6 and 7, so anyone picking by position
  rather than by label got the wrong command — and on this menu the wrong
  command ships a release.

  CHECKS is Release status, Repo signal check and Latest tags. SHIP is Dry run,
  Run release, Auto release and Create GitHub release, in that order. Changelog
  and Setup are submenus; Setup holds the three things done once per repo rather
  than once per release.

  Nothing was dropped — `tests/release-menu-smoke.sh` lists every original
  handler by name, so a regrouping cannot quietly become a deletion.
* The Dev menu shows ten choices instead of sixteen: Prompts, Edit mqlaunch,
  Backup mqlaunch, Folders, Create repo, Repo signal folder check, Comment
  scripts, Env snapshot, Excalidraw, Menus.

  Prompts, Folders and Menus are submenus. Nothing was dropped —
  `tests/dev-menu-smoke.sh` lists every original handler by name, so a
  regrouping cannot quietly become a deletion.

  Network Tools, Themes and Tools Menu were rows 9-11, three doors to other
  menus sitting between actions. They are grouped rather than removed: Dev is
  the only menu that reaches Themes and Tools at all, and removing them would
  have left both reachable only as typed commands.

  `tools/scripts/test-mqlaunch.sh` asserted the literal row text
  `"9. Network Tools" "10. Themes"`, so it failed on a menu where both were
  still reachable. It pins the routes now, which is what its own name says it
  checks.

* The System menu shows ten choices instead of sixteen, grouped by what an
  operator is trying to find out: Performance, Network, Processes, Doctor,
  Checks, Debug bundle, Maintenance, Desktop, Repo folder, Repo in browser.

  Checks, Maintenance and Desktop are submenus. Nothing was dropped —
  `tests/system-menu-smoke.sh` lists every original handler by name, so a
  regrouping cannot quietly become a deletion.

  Doctor stays on the front menu although it is a check: it is the exit gate and
  the command doctor itself recommends on a healthy machine. Debug bundle stays
  because it is reached when something is already wrong and the evidence has to
  go somewhere, which is the wrong moment to add a keystroke.

  The two network rows were removed rather than moved. `show_network_info` and
  the ghost route are options 1 and 8 of the network menu, so the System menu
  offered two ways to reach two of its functions and no way to reach the other
  seven. One row opens that menu instead.

### Fixed

* The System menu numbered its rows 1-13, 16, 17, 14, 15 — MAINTENANCE was
  printed above NAVIGATION while keeping its later numbers, so anyone picking by
  position rather than by label got the wrong command. It is 1-10 now, and a
  test compares the numbers the panel prints against the numbers the case arms
  answer, failing on a gap, a duplicate, or an option with no arm.

### Fixed

* The READY banner printed with no colour at all, while the panel directly below
  it was white.

  `print_dashboard_header` captures the dashboard with `$( )`. Inside a command
  substitution stdout is a pipe, so the dashboard set its colours behind a guard
  that accepts `MQ_DASHBOARD_FORCE_COLOR`, then sourced `mq-ui.sh` — whose guard
  was `-t 1` alone. That reset every colour to empty *after* the dashboard had
  set them, so the banner carried no escape sequence whatsoever. Both guards
  accept the flag now.

  This is why picking a brighter white twice did not fix the banner: the value
  was never the problem there, the sequence was being discarded.

* Two panels were drawn with no colour at all, and the stack disagreed about
  what white meant.

  `hal_menu_missing` and `mq_obsidian_missing` passed `""` as the colour on
  every row, so the one panel an operator meets when something is already wrong
  was also the only one that ignored the theme. #139 made the colour themeable
  but only caught menus that set their *own* escape — passing an empty string is
  the same defect with the opposite symptom.

  `C_WHITE` meant `1;97` in `gitlaunch.sh`, the zsh theme and the prompt
  preview, but `37` — grey — in both dashboards and the miami background. The
  READY banner sits directly above a panel, so the disagreement showed up as two
  shades of almost-white on one screen. `mq-ui.sh` defines `C_WHITE` now
  (`MQ_COLOR_WHITE`), and the panel reads the same value, so the stack has one
  white rather than two that nearly match.

  That white is `38;2;255;255;255`, not a palette index. `0;37`, `1;37` and
  `1;97` are all names the terminal profile resolves, and on this machine the
  border still read as dim after two of them; naming the colour outright takes
  the profile out of the decision. `97` is emitted first so terminals without
  truecolor get bright white instead of falling back to the default foreground.

  `tests/panel-color-smoke.sh` gained both rules. Step 7 was first written as
  three piped greps, one holding an empty alternation that BSD grep rejects —
  the middle stage errored, the pipeline returned non-zero, and the step printed
  "ok" having checked nothing. It is python now.

### Fixed

* The HAL submenus drew a header and then died on `bad substitution`. The panel
  built its section heading with `${title^^}` — a bash 4 expansion. macOS ships
  `/bin/bash` 3.2, and the menu is sourced into whatever shell mqlaunch runs
  under, so opening *Memory* produced a half-drawn box and no menu.

  The pipeline was green throughout: CI runs bash 5, where the expansion works,
  and `bash -n` does not evaluate substitutions. The smoke test drove only the
  front loop, so no submenu was ever entered by anything.

  `tests/hal-menu-smoke.sh` now renders all three submenus under every shell
  present on the machine and requires the heading to appear — a panel that fails
  to render prints no heading either, so the check cannot pass on nothing.

### Security

* The HAL menu ran unrecognised input through a shell. Its front loop ended in
  `*) /bin/zsh -lc "$choice" 2>/dev/null || true`, so a typo at the `hal>` prompt
  was a shell command — and `2>/dev/null` meant it failed silently when it was
  not one.

  Measured rather than reasoned about. Typing a `touch` line at the prompt on the
  previous menu created the file; on this one it does not, and `! touch …` still
  does:

  ```text
  before   touch <path>     the file appeared
  after    touch <path>     "Unknown HAL choice", nothing ran
  after    ! touch <path>   the file appeared
  ```

  Shell now needs an explicit `!`, the panel says so, and `2>/dev/null` is gone
  so a failing command is visible. Two steps in `tests/hal-menu-smoke.sh` drive
  the real menu and check for the file either way, so neither half can be
  removed quietly.

  The first version of the guard step passed on CI while proving nothing.
  `mq_hal_menu_main` returns 127 before reading a line when `$MQ_HAL_BIN` is
  missing, and a runner has no `~/mq-hal` — so the menu never ran, no file was
  created, and the step reported "a typo stays a typo". The step after it caught
  that, because a run which never happened cannot execute `! touch` either. Both
  steps drive a stub backend now, and reintroducing the fallback was checked to
  make the guard fail.

  The same fallback is still in `terminal/menus/mq-performance-menu.sh:98`,
  without even the `|| true`. Out of scope here and reported rather than fixed
  quietly.

### Changed

* The HAL menu shows ten choices instead of seventeen, grouped by what an
  operator wants rather than by backend command name: Brief, Repo status,
  Release readiness, CI status, Doctor, Fix plan, Memory, Diagnostics, Repos,
  Prompt.

  Memory, Diagnostics and Prompt are submenus. Every action that was on the flat
  menu is still reachable.

  Two of the seventeen were not in the grouping brief: `audit` and `context`.
  Neither is dropped — both are in Diagnostics, and `audit` also keeps its `a` /
  `audit` shortcut typed straight into the front loop, which costs no visible row.

* **Back and quit were half-counted.** The inventory treated `x|X) exit 0` as an
  operator choice while `b|B|back)` never matched its arm pattern at all, so
  whether a menu's exit row reached the total depended on how the arm happened to
  be spelled. ROADMAP P2 counts what a menu offers to do, not the ways out of it,
  and exit arms are classified as navigation now. That took `performance` off the
  over-limit list without touching the menu.
* The panel border and its host/mode row are now themeable, and white by
  default. `surface_panel_color()` printed a literal `\033[0;37m` — ANSI white
  at normal intensity, which terminals render grey — so the box around every
  menu was the one surface element no theme could reach, while the title it
  framed took `MQ_COLOR_TITLE`.

  It now reads `MQ_COLOR_PANEL`, defaulting to `1;37`. Four menus
  (`mq-main-menu.sh` twice, `mq-help-center-menu.sh`, `mq-performance-menu.sh`)
  assigned the same grey escape themselves behind their own `[[ -t 1 ]]` guard;
  they call the library now, so the tty and `NO_COLOR` checks live in one place.

  `tests/panel-color-smoke.sh` pins the colour as themeable and single-sourced
  rather than pinning a shade: the default may change, but the panel has to keep
  reading it from one place. Its render checks run through a pty, since the
  colour block is guarded by `[[ -t 1 ]]` and would otherwise compare empty
  strings and pass.

### Added

* `mqlaunch focus` — the Pomodoro timer in `tools/scripts/focus.sh` now has a
  command. #132 removed its Tools menu row, and since it had no dispatcher route
  that left the script orphaned rather than demoted: 169 lines of working tool
  reachable by nothing.

  It works, which is why it was routed rather than deleted. Checked before
  deciding, not after:

  ```text
  focus.sh log            read-only, prints the session log
  focus.sh not-a-thing    exit 1
  focus.sh (no args)      interactive menu, quits cleanly on q
  ```

  Arguments are forwarded rather than enumerated. `focus.sh` owns `start`, `deep`
  and `log` and rejects anything else itself, so declaring them in the dispatcher
  would be a second vocabulary to keep in step with the first.

  `local-write` rather than `read-only`: it appends to
  `~/.local/share/mq-focus/sessions.log`.

  It is a public entrypoint, so it appears in `mqlaunch help` under `UTILITY`. It
  did not go back on the Tools menu — that menu is at exactly ten choices, and
  adding an eleventh to restore a row would undo #132 for a command that now has
  a better home.

### Changed

* The Tools menu shows ten choices instead of thirty, and the Agent menu ten
  instead of twenty-one. Grouped, not cut:

  ```text
  Tools   Skills, Repos and Markdown became submenus; System check and the four
          folder openers went, being `mqlaunch check` and `mqlaunch repo` with
          extra steps; Focus Timer went.
  Agent   Repo analysis, Review to brain, Co-change and memory, MCP and
          Environment became submenus. Demo flow moved to Workflows, beside the
          other full-stack run. Learn promotion moved into Co-change and memory,
          where the rest of the memory writes already were.
  ```

  Nothing in the submenus became unreachable; the rows are one level down.
  `focus.sh` is the exception — the Tools menu was its only entry point, and it
  has no dispatcher route, so it is now orphaned rather than merely demoted.

* **The per-menu count was measured per file, and a file is not a menu.**
  `mq-tools-menu.sh` holds five loops, so the inventory reported 23 choices for a
  menu showing ten — and splitting a long menu into submenus, which is the fix
  ROADMAP P2 asks for, could never have improved the number. Each option is
  attributed to the loop containing it now.

* **The two remaining menu targets pull against each other.** Restructuring
  removed eleven flat rows and added sixteen, because every submenu costs a row
  in the parent and a Back arm of its own. Per-loop counts fell; the total rose
  from 243 to 244. Reaching the 190 target means deleting capability rather than
  regrouping it, which is a different decision and is recorded as one.

* Three tests pinned menu layout rather than menu behaviour and broke on the
  regrouping: `skills-repos-smoke.sh` grepped for the labels `Skills audit` and
  `Repos diff`, and `mq-memory-cochange-routing-smoke.sh` required
  `20) _agent_menu_cochange` by number. Both now assert that some option reaches
  the handler, which is what they were for — the same correction
  `markdownlint-routing-smoke.sh` needed.

* No menu option runs a script the dispatcher also routes. `excalidraw` in the
  Apps menu, `reap` in the System menu, and the `self-check` rows in the System
  and Tools menus go through `bin/mqlaunch`. The pin was a ratchet at three while
  the count came down; it is a hard zero now.

  A ratchet at zero cannot prove itself the way the others do — "one lower must
  fail" has nowhere to go. `tests/command-discovery-inventory-smoke.sh` plants a
  bypass in a tracked menu instead and requires it to be reported, restoring the
  file through a trap. The first version of that fixture appended a *function*
  and passed while proving nothing: the classifier reads menu options, so the
  plant has to be a case arm.

* The Tools menu drops its `doctor`, `doctor --json` and `self-check` rows, and
  renumbers. All three are on the System menu, which is where checks belong, and
  all three still run from the CLI. That takes cross-menu duplication to zero
  without adding an allow-list: nothing yet needs a documented exception, and
  building the mechanism first would have made the target reachable by writing
  prose.

* **The duplication count was wrong, and it was wrong because of a change made
  two commits earlier.** The inventory reported five commands offered by more
  than one menu. Four were the generated help list: its rows read
  `mqlaunch doctor  Check the environment`, which the invocation scanner matched
  exactly like a call, so `mq-help-menu.sh` looked like a menu reaching half the
  registry. Printing a command's name is not a way in. The scanner skips
  generated list blocks now, and the real count was 1.

  This also corrects the "three duplications" figure reported while planning
  this work.

* `tests/markdownlint-routing-smoke.sh` asserted `23. Markdown lint` and
  `24. Markdown fix` by number, so renumbering the Tools menu broke it — a true
  statement about the old layout and nothing about whether the rows route
  correctly, which is what the test is for. It now reads the number out of the
  panel and requires that option to reach `run_markdownlint`, so the rows can
  move without the gate going red or, worse, being loosened.

* `mqlaunch help` takes its descriptions from the registry's `summary` field.
  They used to be typed beside it — two sources for one sentence, the same shape
  as the `chat` drift between help and the index, only on the description
  instead of the name.

  45 summaries were rewritten as short, user-facing text. The technical
  delegation phrasing goes, since `delegates_to` already records it:

  ```text
  Delegate stack status and stack operations to mq-agent  ->  Show stack status and operations
  Delegate a diff review to mq-agent                      ->  Review a diff
  System namespace: performance, network, doctor, ...     ->  Performance, network, doctor, checks, utilities
  ```

  `tools/scripts/generate-help-list.py` writes the block in
  `terminal/menus/mq-help-menu.sh`, and `tests/registry-consumer-parity-smoke.sh`
  regenerates it and requires the file to be current. It is generated rather
  than read at runtime because `doctor` reports `python3` as a check that can be
  missing, and help is the one command that has to keep working on a machine
  where things are missing — a help screen needing a JSON parser to render is
  the wrong trade.

  The validator caps a summary at 66 characters and rejects a multi-line one.
  66 is 92 columns, the clamp in `ui/terminal-ui/terminal-width.sh`, minus the
  26-character `mqlaunch <name>` row prefix — derived rather than chosen. The
  widest row help now renders is 73 columns.

  **Three things help lost**, all consequences of having one source:

  * `mqlaunch doctor --json` is no longer shown. An argument is not a command,
    and the registry does not model one.
  * the argument hints `ask "fråga"` and `fix "fel"` are now plain
    `ask` and `fix`.
  * the AI rows were the only Swedish on the screen and are now English, like
    the rest of it.

  All three forms are in `docs/COMMANDS.md`, which remains the complete listing.
  Say the word if any of them should come back — a small declared set of example
  rows in the generator would do it without reintroducing a second source of
  descriptions.

### Added

* A run of `mqlaunch doctor` on a healthy machine ends in something to do:

  ```text
  ✔ MQ operational — 12 checks passed

    Next: mqlaunch stack
  ```

  Doctor could already say what to fix (#128); on a machine with nothing to fix
  it stopped at the count. That answered half of what ROADMAP P2's exit gate
  asks — the operator learned the machine was fine and nothing about what to
  run. `mqlaunch stack` is the landing because it is the one command that shows
  the whole stack, every repo with its readiness and its own next action, rather
  than a menu to navigate afterwards.

  `next` is no longer null on a clean run. The field now means "one instruction",
  not "one fix": the highest-priority repair while anything needs attention, the
  recommended landing once nothing does. It was added yesterday and has not
  shipped, so nothing external depended on the old meaning.

  The recommendation is held to the advertised surface rather than to being
  non-empty. `tests/doctor-status-contract-smoke.sh` requires it to be a registry
  command with `operator_surface` true, so a new operator can find it again in
  `mqlaunch help`. Three rejections were each proven separately:

  ```text
  mqlaunch markdownlint   not advertised by help — could not find it again
  mqlaunch not-a-command  not a registry command
  open the menu           not a mqlaunch command
  ```

  With this, P2's exit gate closes: a new operator can run `mqlaunch doctor`,
  read a verdict that matches its own checks, fix what it names, and be pointed
  at one command that shows the whole stack.

* `operator_surface` in `mqlaunch/lib/command-registry.json`: whether a command
  is a public operator entrypoint. `mqlaunch help` and `mqlaunch commands` show
  the 48 that are, grouped by `namespace`, and stay quiet about the other 26.

  Help was curated by whoever last edited the text. It advertised 40 of 74
  commands, and the selection did not follow a rule anyone could state — `review`
  and `risk-review` were listed while `stack`, `architecture` and `repo-health`
  were not, though all five are the same kind of delegation to mq-agent.

  The rule is now a field, and the field is enforced.
  `tests/registry-consumer-parity-smoke.sh` requires help to advertise exactly
  the public set, and to print each command under a heading naming its
  namespace. `tools/scripts/validate-command-registry.py` rejects a
  `compat_only` command marked public, and a public command with no namespace —
  which would have nowhere to be printed and would show up as a missing row
  rather than an error.

  The 26 unadvertised commands stay dispatchable and stay in `docs/COMMANDS.md`,
  which remains the complete listing. They are the ones reached through a
  namespace or menu (`git-log`, `kill-port`, `workspace`, `release-check`),
  variants and implementation detail (`theme-macos`, `docwrite`, `markdownlint`),
  and second spellings of something already advertised (`index`, `self-check`,
  and `mqlaunch`, which is `compat_only` and therefore never advertisable).

  `POPULAR FLOWS` is exempt from the heading rule, since it is a selection
  rather than a namespace — but the exemption is bounded: every command it
  highlights must also appear under its own namespace, so the section can
  promote a command and never be the only place it is listed.

  `stack` is advertised now, under `AGENT` and in `POPULAR FLOWS`. The entrypoint
  already worked and already showed all five stack repos; it was simply invisible.

  Fixed while making the comparison load-bearing: the help extractor matched
  `mqlaunch\\s+(\\w+)`, and `\\s` crosses newlines, so the bare `mqlaunch` line
  under `POPULAR FLOWS` borrowed the next row's first word and reported
  `mqlaunch` as advertised. Harmless while the set was only searched for ghosts
  — `mqlaunch` is a real registry word — but a phantom member fails an equality
  check on every run.

* `mqlaunch doctor` says what to do about every check that does not pass, and
  ends in the one thing to do first:

  ```text
  ⚠ gh missing — brew install gh
  ⚠ mqlaunch not in PATH — run ./install.sh from the repo to install the symlink
  ⚠ 9 of 12 checks need attention

    Next: run ./install.sh from the repo to install the symlink
  ```

  The document carries the same advice — `hint` on each check that did not pass,
  and a top-level `next` that is `null` when the status is `ok` — so a script and
  a person reading the same run are told the same thing. Both fields are
  additive.

  The nine brew formulae are listed by name rather than caught by a `*` arm. A
  fallback would turn any check added later into `brew install <whatever>`, and a
  confidently wrong instruction is worse than none: `pbcopy` has no formula, it
  ships with macOS. The names were confirmed with `brew info` rather than
  recalled, and the two non-tool checks point at what the repo actually provides
  — `install.sh` for the symlink, the shell profile for `OPENAI_API_KEY`.

  The next step follows an explicit fix order, not the order the checks print
  in. Those are grouped for reading, and following them would advise installing
  `eza` while `mqlaunch` is not on `PATH`. The launcher comes first because
  nothing else here is reachable without it, then the tools the launcher shells
  out to, with `eza` last because it only changes how listings look.

  `tests/doctor-status-contract-smoke.sh` grew two steps. Hints are checked
  exhaustively rather than sampled — the stripped world warns on all twelve, so
  a check added without a hint fails the suite instead of printing a blank. The
  order is pinned by two worlds that differ by a single tool: with only `eza`
  missing the next step is `brew install eza`; with `eza` and the launcher both
  missing it must not be `eza`. One world could have come out right by luck.

  Found while writing it: the hint step read its input through `< <(python3 …)`,
  where a process substitution hides the exit status. A python that bailed out
  left the array empty and every loop below passed over nothing, reporting
  "0 warnings, each carrying a hint". It writes to a file now, and asserts the
  hint count equals the warning count.

### Fixed

* `mqlaunch doctor` reported success no matter what it found.
  `tools/scripts/doctor.sh` ended in an unconditional `ok "MQ operational"`, and
  the counters it might have consulted were only ever updated in JSON mode. On a
  machine with nine of twelve checks warning, the two modes said opposite things:

  ```text
  --json   {"status": "warn", "summary": {"ok": 3, "warn": 9, "fail": 0}}
  human    ✔ MQ operational                                 EXIT=0
  ```

  The JSON was honest. The screen — the surface a new operator actually reads —
  was not, which made this ROADMAP P2's exit gate rather than a cosmetic defect.

  Both modes now derive the same verdict from the same counters and exit `0`
  only when every check passes. The summary branches on the run's status rather
  than on a warning count, so a `fail` check added later cannot slip past a
  `warn`-shaped condition and print "operational" again.

  This changes an exit-code contract. No caller gates on it:
  `terminal/release/mq-release-check.sh` runs doctor without `|| exit 1` — unlike
  the `validate.sh` line directly below it — and is `set -u`, not `set -e`, so it
  continues and still exits 0, which was verified by running it against a
  warning doctor rather than by reading the script.

  Two tests did gate on it, and both were asserting the wrong thing:

  * `tests/headless-smoke.sh` ran doctor bare under `set -e`. It is about
    pausing and output shape, so it now accepts 0 or 1 — and still rejects 124,
    which a plain `|| true` would have swallowed along with the hang.
  * `tests/output-mode-parity-smoke.sh` treated any non-zero exit as a parity
    problem. A health command reports its verdict that way, so the rule is now
    that the exit code and the document must agree: non-zero is accepted only
    when the JSON says something is wrong. A third fixture proves that
    allowance is not a hole, by replaying an observation that exited 1 while
    reporting `"status": "ok"`.

  `tests/doctor-status-contract-smoke.sh` is new. It builds a provisioned
  machine and a stripped one out of `PATH` rather than testing whichever machine
  runs the suite — a CI runner has no `eza` and a laptop does, and asserting
  either would have produced a test that passes in one place and fails in the
  other. It pins that the two modes agree, that the exit status follows the
  verdict, and that the summary line differs between the two worlds, so it
  cannot be a constant again.

* `mqlaunch help` and `mqlaunch commands` were two hand-maintained copies of the
  same command list, and they had already drifted: `chat` was in the index and
  not in help. Both now render one list, `command_list` in
  `terminal/menus/mq-help-menu.sh`, so a command can no longer reach one surface
  and miss the other.

  `mqlaunch commands` was not checked by anything. `tests/registry-consumer-parity-smoke.sh`
  held help, `docs/COMMANDS.md` and the palette against the registry; the index
  was the one advertised surface with no gate on it, which is why the drift
  survived. It is now a fourth consumer with help's contract — every word it
  offers must dispatch, and it must not promote a deprecated alias — plus one of
  its own: help and the index must offer the same commands.

  The comparison is on command words, not on text. The index adds a banner and a
  footer, so the two captures are not meant to be byte-identical.

  Run against the previous `terminal/menus/mq-help-menu.sh`, the new step names
  the real defect:

  ```text
  `mqlaunch help` and `mqlaunch commands` advertise different commands
    — only in help: mqlaunch; only in the index: chat
  ```

  The index is read with a one-or-two-space indent while help is read with two.
  A stricter anchor was tried first and reported all 43 commands as missing,
  because the old index indented by one — a true failure for a reason that hid
  the one worth reading.

* `mqlaunch pulse` wrote `TERM environment variable not set.` to stderr and the
  four dispatched tools that call `clear` unguarded now guard it:
  `tools/scripts/pulse.sh`, `blackout.sh`, `chat.sh` and `network-ghost.sh`.

  Same class as the `doctor` defect: a bare `clear` fails in a stripped
  environment — GUI launch, cron, a CI runner — writing to stderr and exiting
  non-zero. The repo already had the fix in four other scripts as
  `clear 2>/dev/null || true`; it simply was not everywhere, so all four adopt the
  existing idiom rather than a new helper.

  `tests/plain-output-contract-smoke.sh` gained a static step. Step 11 proves
  `doctor` is quiet by running it, and that does not generalise: `pulse` spends
  twenty seconds probing the network, so executing every command to check the same
  property would make the suite unusable. The new step reads the dispatcher for
  the `tools/scripts/` paths it invokes and rejects a bare `clear` in any of them
  — 15 tools, expected count zero, so there is no ratchet and no allowance for a
  wrong row.

  Scoped to dispatched tools because that is the surface a caller reaches through
  the documented CLI. Menus and TUI internals have a terminal by construction; the
  eleven remaining unguarded `clear` calls live there and are out of scope. The
  relation is read from the dispatcher rather than matched on filenames, since a
  basename heuristic would be exactly the kind of approximation that has produced
  two wrong attributions in this area already.

* `ghost` was declared `safety: read-only` in the command registry while
  `tools/scripts/network-ghost.sh` ran `sudo ifconfig $INTERFACE ether $NEW_MAC`
  to spoof the machine's MAC address and flushed the DNS cache with
  `sudo killall -HUP mDNSResponder`. It is now `destructive`.

  `safety` exists so a consumer can decide what is safe to run, and `read-only` is
  the value that invites running something unattended. This was a false label with
  a security consequence rather than a cosmetic one — and the truth was already
  written down one file over, in `docs/COMMANDS.md`:
  `mqlaunch ghost # network cloaking (MAC/DNS spoof)`.

  `tools/scripts/validate-command-registry.py` now rejects `read-only` on any
  command whose dispatched script escalates, so the label cannot drift back. The
  check looks for `sudo` in command position, not anywhere in the file, and that
  distinction is what makes it usable: `tools/scripts/scan.sh` contains
  `echo "- Restart audio if glitching: sudo killall coreaudiod"` — a suggestion
  printed for the operator — and `scan` is correctly `read-only`. A substring
  search would have relabelled it.

  The gate is one-directional on purpose. It says `read-only` is wrong when a
  script escalates; it does not choose between `local-write` and `destructive`,
  which is a judgement about blast radius that a regex has no standing to make.

  Two steps in `tests/command-registry-smoke.sh` cover it: one restores the old
  `read-only` value and requires the validator to reject it, the other pins that
  `scan` stays `read-only` and that its printed suggestion is still there, so the
  false-positive guard cannot quietly stop proving anything.

### Changed

* `POPULAR FLOWS` moved from the bottom of `mqlaunch help` to the top of the
  shared list, so it is the first thing both surfaces show and the index gets it
  too. ROADMAP P2 asks for the most useful workflows first; they were last.

* The network signal rows go through the dispatcher: `run_network_pulse` and
  `run_network_ghost` in `mqlaunch/lib/network.sh`, and the system menu's GHOST
  row. Unlike `doctor`, the `pulse` and `ghost` routes end in `return $?` with no
  pause of their own, so these callers keep their `pause_enter` — dropping it
  would return straight to the menu and repaint over the output.

  The pinned bypass count drops from nine to three, and again only part of that is
  the rerouting:

  ```text
  9 → 6   three rows were attributed to pulse.sh that never called it (see Fixed)
  6 → 3   the two network rows and the system GHOST row now route through mqlaunch
  ```

  Remaining: `excalidraw.sh`, `overseer.sh`, and the `test-all.sh` row behind
  `run_self_check`.

* Every menu path to `doctor` goes through the dispatcher instead of running
  `tools/scripts/doctor.sh` itself. `docs/RUNTIME_AUTHORITY.md` names
  `dispatch_cli_command` as the single entry point, and the inventory below found
  twelve menu options with a second one.

  Three rows changed: the system menu's DOCTOR row, the tools menu's DOCTOR CHECK
  row, and the tools menu's DOCTOR JSON row. The first dropped its own
  `pause_enter` because the dispatcher already pauses, and doing both would stop
  twice. The JSON row keeps its pause, because the dispatcher deliberately skips
  it for `--json` so a piped caller is never left waiting on input. That row also
  loses an existence guard and a missing-script panel — the menu duplicating a
  decision the dispatcher owns.

  The pinned bypass count drops from twelve to nine, and the split is worth
  stating because only part of it is this change:

  ```text
  12 → 11   the inventory stopped misclassifying one row (see Fixed)
  11 →  9   the two pinned doctor rows now route through the dispatcher
  ```

  `test-all` is deliberately untouched. Its menu row goes through
  `run_self_check` in `mqlaunch/lib/diagnostics.sh`, a presentation wrapper with
  its own header, footer and pause, so rerouting it changes what the menu looks
  like rather than where the call goes. It belongs in its own slice.

### Fixed

* The command discovery inventory read past the end of a short handler. Function
  bodies were excerpted as a fixed 60 lines from the definition, so a 9-line
  handler's excerpt ran on into whichever function followed it in the file.

  That is how `ping_test`, `show_dns_gateway` and `open_network_settings` were all
  reported as running `pulse.sh`: none of them touch it, but all three sit in
  `tools/scripts/mqlaunch_desktop.sh` near a neighbour that does. The bypass list
  claimed four `pulse.sh` rows where there is one. Bodies are now cut at the
  function's closing brace, with the line count kept only as a safety cap.

  Worth stating plainly, because the slice that followed was scoped from the wrong
  number: `pulse.sh ×4` was an artifact.

* The command discovery inventory misclassified any arm that opens a submenu.
  `2) open_system_menu` was read by following the handler into its body — which is
  the system menu's own case statement — so the arm was labelled by whatever the
  first 60 lines of the child menu happened to invoke. It was reported as
  `dispatcher-bypass` because `network-ghost.sh` ran nearby, and it flipped to
  `via-dispatcher` when an unrelated row in that menu was rerouted.

  Neither label was true: the arm opens a menu. Submenu openers are now matched by
  name before the body is read, which moved 17 arms from `menu-local` to
  `navigation` and removed one row from the bypass list.

### Added

* `tools/scripts/inventory-command-surfaces.py` and
  `tests/command-discovery-inventory-smoke.sh`. First slice of P2 command
  discovery, and deliberately an inventory rather than polish: the menus are the
  one discovery surface with no comparison against the command registry.

  The registry already gates every machine-readable surface — `docs/COMMANDS.md`,
  the README, `--help` and the palette are all compared against
  `mqlaunch/lib/command-registry.json`, and the registry against the dispatcher.
  The 19 interactive menus, which is where an operator actually looks, had
  nothing. The inventory classifies all 243 numbered and letter-key options:

  ```text
  via-dispatcher     invokes `mqlaunch <command>` — the single authority
  outside-registry   invokes a word the registry does not declare (e.g. repl)
  navigation         opens another menu or launcher
  dispatcher-bypass  runs a script the dispatcher also routes — two ways in
  menu-only-tool     runs a script the dispatcher does not route at all
  menu-local         local UI or shell logic with no command equivalent
  ```

  Findings, to be acted on in later slices rather than this one: twelve options
  are `dispatcher-bypass`, giving `doctor.sh`, `network-ghost.sh`, `pulse.sh`,
  `test-all.sh`, `overseer.sh` and `excalidraw.sh` a second entry point beside
  the dispatcher that runtime authority names as the single one. Fifteen tools are
  menu-only. Of 74 registry commands, 45 are invoked somewhere in menu code and 29
  are CLI-only.

  The twelve are pinned, not fixed: `--max-bypass` fails the suite if the count
  rises, and the smoke test proves the ratchet is not vacuous by requiring one
  lower to fail. The classification is heuristic — it reads shell with regexes and
  follows an option one function deep — so the gate asserts the properties that
  make the report trustworthy rather than individual rows: every option classified,
  the counts summing to the option total, and output independent of filesystem
  order.

  Four measurements were wrong before they were right, which is the case for
  inventorying before polishing:

  * Handler names are defined in more than one file, and resolving them globally
    made the inventory shift with directory order — 4 dispatcher calls on one run,
    17 on the next. Resolution is now menu-local first.
  * The source list walked the filesystem, so a local gitignored
    `backups/scripts/` tree of old menu copies took part in that resolution. The
    inventory reported nine bypass options here and twelve on a clean CI runner.
    It now comes from `git ls-files`, and a step plants an untracked colliding
    handler to prove untracked files cannot move the numbers.
  * A numeric-only scan of case arms missed that the menus route most commands
    through letter keys (`r|R`), not numbers.
  * An invocation regex that did not strip comments read the menus' own prose
    about themselves ("mqlaunch owns …") as command calls.

* `tests/manifest.tsv` and `tests/test-inventory-smoke.sh`. Every file under
  `tests/` must now be classified — `active`, `broken`, `manual`, or
  `obsolete` — and the gate enforces four things: a new test file with no row
  fails, a row whose file is gone fails, anything classified `active` must be
  listed in `tools/scripts/test-all.sh`, and anything not `active` must not be.
  `broken` and `obsolete` additionally require a written reason.

  Eleven files had sat under `tests/` without ever being listed in the suite.
  Six of them were red. Nothing reported it, because a test nobody runs cannot
  fail — the repo looked better covered than it was. The suite now runs 47
  tests where it ran 40.

  The five still failing are classified `broken` with the specific reason, so
  they are visible as debt rather than as coverage. All five assert source text
  that has since been rewritten or moved: two against `ROADMAP.md`, one against
  the command dispatcher, and two against `terminal/launchers/mqlaunch.sh`.

  The gate was checked by breaking it five ways: an unclassified new file, a
  row pointing at a deleted file, an `active` test removed from the suite, a
  `broken` row with its reason stripped, and a `broken` test wired into the
  suite. All five were caught.

### Fixed

* `mqlaunch doctor` printed shell errors when `TERM` was unset — a GUI launch,
  cron, a nested launcher, a CI runner. `tools/cli/mq-ui.sh` drew its section
  separators with a bare `printf "%*s\n" "$(tput cols)"`, and with no terminal to
  ask, `tput` wrote its own complaint to stderr and returned nothing, leaving
  `printf` with an empty field width:

  ```text
  tput: No value for $TERM and no -T specified
  tools/cli/mq-ui.sh: line 44: printf: : invalid number
  ```

  Twelve such lines from the first command a new operator is told to run, with
  blank lines where the six separators belonged — and an exit status of 0
  throughout, which is why nothing reported it.

  `hr()` now takes its width from `surface_terminal_width` in
  `ui/terminal-ui/terminal-width.sh`, the helper the surface converged on. This
  was a fourth copy of that decision and the only one carrying no fallback at
  all. Verified against a stubbed `tput`: 200 columns clamps to 112, 40 clamps up
  to 60, 100 passes through, and a failing `tput` falls back to 92. Separators on
  a wide terminal now stop at 112 instead of spanning it, which is the same bound
  the rest of the surface already uses.

  Writing the test surfaced a second defect in the same line. `tr ' ' '─'` is
  byte-oriented, so under a C locale it mapped each space to `0xe2` — the first
  byte of `─` — and the separator arrived as 92 bytes of invalid UTF-8. A stripped
  environment drops `LANG` for the same reason it drops `TERM`, so both defects
  fire together; CI caught this one because its runner has no UTF-8 locale.
  `hr()` now builds the rule with parameter expansion, which substitutes the whole
  sequence.

  `tools/scripts/watch.sh` has the same `printf "%*s\n" "$(tput cols)" | tr` line
  and is deliberately left alone: it also calls `tput civis` and `tput cup`, so it
  cannot render without a terminal at all. A width fallback there would be
  unreachable code. The `repeat_char` helpers in `ui/terminal-ui/mq-ui.sh` and
  `terminal/launchers/gitlaunch.sh` share the `tr` hazard and are out of this
  slice.

* `tests/plain-output-contract-smoke.sh` could not see the defect above. Every
  check in it either sets `TERM=xterm-256color` or sends stderr to `DEVNULL`, so
  `doctor` could emit a screenful of shell errors and still pass the output
  contract. A step now runs it with `TERM` and `COLUMNS` unset, and under
  `LC_ALL=C`, requiring empty stderr and a separator that decodes as valid UTF-8
  at no less than the 60-column clamp. It asserts by decoding rather than grepping
  for `─`, because a grep for that glyph depends on the locale of whoever runs the
  suite — the same trap the rule itself fell into.

* The last three `broken` rows are closed, and the manifest is at zero. Each was
  run first and diagnosed from its actual output, because two of the first five
  reasons written into the manifest turned out to be wrong.

  All three shared a cause the manifest did not name: `ROADMAP.md` was rewritten
  from `| Done | ... |` tables to prose sections with `Status: Done`, so
  `grep -c '^|' ROADMAP.md` is now 0 and every verbatim table-row assertion had
  become unsatisfiable.

  `mq-agent-routing-smoke.sh` and `mq-obsidian-command-routes-smoke.sh` were
  rewritten. Their roadmap greps are gone; the live assertions they already
  carried stay. In the obsidian test the dropped rows claimed the release gate
  detects schema drift, so the replacement asserts the gate — that
  `check_mqobsidian_manifest_contract` is both defined and actually called in
  `terminal/release/mq-release-check.sh`, since a check nobody calls is not a
  gate either.

  `mq-memory-cochange-routing-smoke.sh` was replaced rather than rewritten. Its
  failing assertion looked for the literal `run_agent_command memory-cochange`,
  but the dispatcher resolves the verb through a variable — `cochange)` sets
  `_mem_verb`, then `run_agent_command "$_mem_verb"` runs it — so the string can
  never appear no matter how correct the routing is. The step now sources command
  mode, stubs the bridge, and calls `dispatch_cli_command memory cochange`,
  asserting the verb that arrives and that trailing arguments are forwarded
  untouched. Same harness as `tests/delegated-exit-code-smoke.sh`.

  A rule follows from this, written into the manifest header: tests do not assert
  `ROADMAP.md` text. A roadmap is a plan, and rewriting it is its job. Two active
  tests were still violating it — `mq-stack-contract-smoke.sh` matched three
  claims there and `mq-obsidian-menu-no-promotion-smoke.sh` one — so both were
  repointed at `docs/architecture/MQ_BOUNDARY.md`, which states the same
  prohibitions under `Must not own` and exists to be binding. No documentation
  changed; the claims were already there.

  52 active tests, zero classified out.

* `tests/brain-bridge-smoke.sh` and `tests/skills-repos-smoke.sh` asserted that
  `terminal/launchers/mqlaunch.sh` still contained the case arms
  `verified|systems` and `skills|skill`. It contains neither — the command
  surface moved into `terminal/launchers/mqlaunch-command-mode.sh`, which
  `mqlaunch.sh` sources at line 166.

  The `|` in those greps is deliberate: the tests match case-arm source text,
  not a regex alternation, so `-E` was never the missing piece. The file under
  assertion was the wrong one. Both steps now assert what they meant — the
  routing lives in command mode, which each test already checks one step
  earlier, and `mqlaunch.sh` reaches it by sourcing that module.

  Wiring `skills-repos-smoke.sh` into the suite then exposed a second reason it
  had never run: its last four assertions expect `mq-mcp`, `mq-ums`, and
  `mq-agent` to appear in `mq-repos.py list` output, which needs those repos
  checked out beside this one. CI clones `macos-scripts` alone, so they are now
  asserted only where there is something to find. The commands themselves still
  run unconditionally — a crash in `mq-skills.py` or `mq-repos.py` fails the
  suite everywhere.

  Reclassified `active` in `tests/manifest.tsv` and wired into
  `tools/scripts/test-all.sh`: 49 active tests, three `broken` rows left.

### Changed

* Terminal width had two implementations: `surface_terminal_width` in
  `ui/terminal-ui/mq-ui.sh`, used by 23 files, and `gitlaunch_terminal_width` in
  `terminal/launchers/gitlaunch.sh`, used only by gitlaunch. The comment on the
  second said it matched the first so nested panels line up.

  It did not. `mq-ui.sh` falls back to `${BOX_INNER:-92}` and also defaults
  `BOX_INNER` to 88, so the menus fell back to 88 while gitlaunch hardcoded 92 —
  and which value applied depended on whether `mq-ui.sh` had been sourced yet.
  The clamp bounds agreed; the fallback did not.

  Both now source `ui/terminal-ui/terminal-width.sh`. The fallback is a
  constant, so it no longer depends on sourcing order, and `BOX_INNER` is left
  to mean box width rather than terminal width. The helper is written for both
  shells because gitlaunch is zsh and everything else is bash. Driven for real:
  gitlaunch and `mq-git-menu` now render at the same 92 columns under identical
  conditions.

### Fixed

* `tests/mq-git-protected-push-smoke.sh` was never listed in
  `tools/scripts/test-all.sh`, so it had never run. It was also red: one
  assertion grepped gitlaunch.sh for the word `continue`, which appears in no
  commit reachable from `HEAD`. A test nobody runs cannot fail, so nothing
  reported it.

  It is wired in now, the dead assertion is gone, and its four width
  assertions — which grepped for the function name and the literals
  `width > 112` and `width < 60` — are replaced by
  `tests/terminal-width-smoke.sh` driving the clamp. Those four pinned the
  implementation rather than the behaviour: they passed for code that never ran
  and would have failed for a correct refactor.

  Eleven further files under `tests/` are still absent from `test-all.sh`, six
  of them failing when run by hand. That is left as its own piece of work
  rather than folded in here.

* The wiki Command Reference's banner rule had never fired once. Its grep
  pattern starts with `--`, so grep read the pattern as an option and exited 2
  before matching anything — every script whose only title is its header art
  was published with an em dash. `mission-control` looked like a
  counterexample, but it takes its title from rule 1's `APP_NAME`.

  Making the rule reachable was one `--`. Making it correct needed more: the
  pattern also matched inside `--- SECTION ---` separators and
  `<!-- BEGIN ... -->` markers, which would have published "COLORS (subtle)"
  for `mqlaunch-repl` and "BEGIN GENERATED SKILLS TABLE" for `check-skills`.
  Pinning the delimiter to exactly two dashes separates a banner from a
  separator. The rule's comment also said "banner comment line", but these are
  `printf`/`echo` calls in the scripts' header art, not comments — the fixtures
  match what the tree actually contains.

  Measured before and after against the real tree: 11 rows gain a description,
  all of them genuine banners, and nothing else on the page moves. The loose
  pattern would have changed 16 rows, 5 of them wrong.

* The published wiki Command Reference carried a literal `$dashboard` as the
  description for `ui/terminal-ui/mq-ui.sh`. `extract_meta` matched
  `print_dashboard_header "$dashboard"` with its `header "` rule and published
  the unexpanded variable.

  Rule 1 was meant to prevent exactly this for `APP_NAME`/`APP_TITLE`, and its
  comment said so — but the guard was written into a `sed` substitution, and on
  a value like `APP_NAME="$title"` that pattern simply fails to match. An
  unmatched `sed` prints the line unchanged, so the guard did not drop the
  value; it kept the entire `APP_NAME="$title"` line as the description. The
  check is now its own step applied to all four rules.

  `tests/wiki-command-ref-smoke.sh` runs one fixture per rule, asserts real
  descriptions still survive, and then generates the whole page against the
  real tree and fails if any description column contains a `$`.

  Found while auditing the regenerated page after the 2.0.1 release, not by a
  gate — hence the gate.

## [2.0.1] - 2026-07-29

### Changed

* `ROADMAP.md` still said `Current version: 1.0.1` two releases later, and the
  Definition of Done for v2.0.0 stood almost entirely unchecked — after v2.0.0
  had shipped and every P0 and P1 block below it was marked Done. A roadmap that
  disagrees with its own blocks is worse than no roadmap: it makes finished work
  look outstanding.

  The version is now 2.0.0 and the Definition of Done is closed against the tree,
  each box naming the test or document that proves it so the next reader can
  re-run the proof instead of trusting a checkmark. Everything cited runs in CI.

  Seven boxes stay unchecked on purpose. Five claim that `mq-agent`, `mq-mcp`,
  `mqobsidian`, `repo-signal`, and `mq-hal` still own their responsibilities —
  claims about other repositories' trees, which this one cannot verify and must
  not assert. Two name `contract-check` and `stack-preflight`, neither of which
  is a `mqlaunch` command; both return `Unknown command`. The reasons are written
  into the roadmap next to the boxes rather than left for someone to rediscover.

### Fixed

* `release.sh` pushed `main` directly while `.mq/repo-contract.json` declared
  `release_mode: pull_request`. `main` carries no branch protection on GitHub,
  so nothing outside the contract would have refused the push — and v2.0.0 was
  in fact released through PR #106 plus a hand-made tag, meaning the script was
  the one part of the flow that disagreed with how releases actually happen.

  The mode now comes from the contract rather than a flag; a flag would have
  left `./release.sh <version>` working as a direct-push path in a repo whose
  contract forbids one. Under `pull_request` the bump lands on a
  `release/v<version>` branch, the branch is pushed, a PR is opened via `gh`
  when available, the checkout returns to `main`, and no tag is created —
  tagging is a printed post-merge step, because the tag belongs on the merge
  commit. `release_mode: direct` keeps the previous behaviour for repos whose
  contract asks for it.

  `tests/release-pull-request-mode-smoke.sh` proves it against a real bare
  origin rather than a command log: `main`'s SHA is unchanged, the release
  branch exists and carries the bump, no tag was pushed, and the checkout is
  back on `main`. Dry-run is asserted to leave no branch, no commit, and a
  clean tree; `direct` is asserted to still advance `main` and push its tag.

* `release.sh` promised in its usage text that "if the script aborts before
  commit, VERSION, README.md and the contract are restored" — and never did so
  for any of its gates. Bash does not run an `ERR` trap for an explicit `exit`,
  and every gate exits rather than failing a command, so the CHANGELOG check,
  the contract re-gate, and the tag checks all skipped the rollback. Driving
  `./release.sh --dry-run 2.0.1` against this repo found it: three bumped files
  left on disk, no rollback line, no failure line.

  An `EXIT` trap now covers what `ERR` could not. It is guarded on a mutation
  flag rather than running unconditionally: before the first bump the tree still
  holds the operator's own work, and `git checkout --` there would discard it
  rather than restore anything — mistyping a flag must not clean the tree. The
  fix ships with the `release_mode` change rather than after it, because a gate
  tripping after the release branch is cut would otherwise strand the checkout
  on that branch.

* `docs/AUTHORITY_MAP.md` listed
  `terminal/menus/mq-hal-menu.sh.bak.20260519-115142` under *Dead — DEPRECATED*
  as a file awaiting deletion. It is not in the repository and never has been.
  `.gitignore` has matched `terminal/menus/*.bak.*` since 2026-04-12 and the file
  is dated 2026-05-19, so it could not have been committed: `git log --all` on
  the path is empty, and the path returns 404 on `main`. It is an untracked
  editor backup in a local working copy.

  The 2.0.0 entry that introduced the claim stays as written — a published
  changelog records what was believed then — and this is the correction. The
  error was reading a working directory and calling it the repository.
  `git ls-files` answers that question and was not asked.

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
