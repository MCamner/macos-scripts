# Read-only consumer pattern

Use this pattern when `macos-scripts` displays or copies outputs produced by
another MQ repo.

## Rule

```text
producer repo writes artifact -> macos-scripts reads/displays/copies -> no auto-execution
```

For recommendations, `mqobsidian` produces `recommended.json`.
`macos-scripts` may resolve it, validate it, show visible items, and copy a
selected command template. It must not rank recommendations, rewrite the source
artifact, or execute templates automatically.

## Good fit

* status dashboards
* recommended command templates
* context-pack visibility
* read-only repo or memory views

## Not a fit

* choosing actions on behalf of the operator
* promoting memory
* executing generated commands
* writing back to source-of-truth repos

If a consumer needs ranking, memory writes, or orchestration, move that behavior
to the producing MQ repo or route through `mq-agent`.
