# Bridges

A bridge is a routing shim: the launcher sources it, and it hands a command to
whatever actually implements it. It holds no business logic.

This folder existed for a migration off `terminal/mqlaunch-v1`. That tree was
deleted on 2026-08-02, so the compatibility half of the job is finished. What is
left routes to another repo or to a menu in this one.

## Files

```text
terminal/bridges/
├── hal-bridge.sh           # routes to mq-hal
├── brain-bridge.sh         # routes to the mqobsidian brain surface
├── performance-bridge.sh   # loads terminal/menus/mq-performance-menu.sh
├── dev-bridge.sh           # inert tombstone; legacy Dev routing retired in 12.1
└── README.md
```

## What changed when v1 went

* `tools-bridge.sh` is gone. It forwarded `tools` to the v1 launcher as a
  subprocess, and neither `open_v1_tools_menu` nor `run_v1_tools_command` had a
  caller anywhere in the tree.
* `performance-bridge.sh` kept its name and lost its bridging. It used to fall
  back to the v1 launcher when `mq-performance-menu.sh` was missing. A missing
  menu file is a broken checkout, and answering it by running a frozen launcher
  hid that; it reports and returns 1 now.
* `run_performance_command`, `open_v1_performance_menu` and
  `run_v1_performance_command` went with the fallback. None had a caller.

Performance was the one area genuinely dependent on v1, and not for the reason a
compat layer usually exists. The v1 performance module was 504 lines of working
`perf_*` readings — health score, process views, disk and network checks,
battery, snapshots, quick watch — so the frozen tree was being kept alive to
*supply code*, not to preserve an old route. Moving that file to
`mqlaunch/lib/performance.sh` is what made the deletion possible.

## Rules

* A bridge routes. New logic in a bridge is forbidden — see
  [docs/RUNTIME_AUTHORITY.md](../../docs/RUNTIME_AUTHORITY.md).
* Nothing here may name the deleted tree again.
  `scripts/check-runtime-authority.sh` is a tombstone gate now: it fails on any
  shell file that references it, so a second runtime cannot come back quietly.
* A bridge with no callers is deleted, not kept for symmetry. That is how both
  the dev and the tools bridge ended.

## Relationship to the rest of `terminal/`

* `launchers/` — user-facing entry points
* `menus/` — the implementations
* `bridges/` — the handoff between them, and to other repos in the stack
