# commands.json Entry Template

Shape of a single entry in `mq-ums/config/commands.json`.

## Schema

```json
{
  "id": "kebab-case-id",
  "section": "Section Name",
  "name": "Display Name",
  "psCommand": "Verb-UMSNoun",
  "allowedArgs": ["Id", "Filter"],
  "danger": false,
  "description": "One sentence describing what this command does."
}
```

For dangerous commands, add `confirmText`:

```json
{
  "id": "restart-device",
  "section": "Devices",
  "name": "Restart Device",
  "psCommand": "Restart-UMSDevice",
  "allowedArgs": ["Id"],
  "danger": true,
  "confirmText": "RUN",
  "description": "Restarts a device. Requires device Id."
}
```

## Rules

* `id` must be unique across all entries
* `allowedArgs` values must match `inputs[*].name` in the contract
* `danger: true` requires `confirmText`
* Do not add fields outside this schema — the generator produces the exact shape

## Do not hand-edit

Use the generator to append new entries:

```bash
python3 tools/generate-command-from-template.py docs/contracts/<id>.yaml --apply
```

The generator skips the entry if `id` already exists.
