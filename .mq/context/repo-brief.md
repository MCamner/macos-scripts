# macos-scripts repo brief

`macos-scripts` is the public terminal entrypoint for local MQ workflows.

It owns `mqlaunch` menus, launcher UX, safe local shortcuts, and operator-facing
command discovery. It should stay thin: orchestration belongs in `mq-agent`,
cognition and review execution belong in `mq-mcp`, durable memory belongs in
`mqobsidian`, and publish-readiness scoring belongs in `repo-signal`.

Use this repo to make workflows easier to find and safer to run. Do not add
private MQ operating context, machine-specific paths, secrets, or internal agent
memory here.
