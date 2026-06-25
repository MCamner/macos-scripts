# Command surface

`mqlaunch` commands are grouped by ownership and risk.

| Tier | Examples | Purpose |
| --- | --- | --- |
| Core | `mqlaunch`, `doctor`, `selftest`, `release-check` | Stable repo and launcher baseline |
| MQ bridge | `review`, `risk-review`, `repo-health`, `mcp-status` | Delegation into MQ stack tooling |
| HAL/operator | `hal`, `hal brief`, `hal audit`, `hal ci` | Operator status and local briefings |
| B2/Prompt OS | `mq b2`, `mq b2 compose`, `mq b2 route` | Prompt cockpit and read-only source use |
| Local utilities | `perf`, `network`, `scan`, `workspace` | Local macOS workflows |

## Safety classes

| Class | Meaning | Requirement |
| --- | --- | --- |
| A | Read-only status, docs, or previews | No mutation |
| B | Local generated output or copied text | Clear destination or clipboard behavior |
| C | Local mutating action | Explicit confirmation and no automatic push |
| D | Remote or irreversible action | Keep outside `mqlaunch` unless separately approved |

The command surface should stay small enough to scan. Add commands only when
they improve operator clarity, safety, or delegation into the correct MQ owner.
