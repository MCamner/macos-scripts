# Python Wrapper Template

Pattern for mq-ums Python wrapper functions, generated when `python_wrapper: true` in the contract.

## Generated shape

```python
def restart_device(id: str) -> dict:
    """
    Restarts a device. Requires device Id.
    """
    return run_command(
        command_id="restart-device",
        args={"Id": id},
        confirm_text="RUN",
    )
```

## Naming rules

* Function name: contract `id` with `-` replaced by `_`
* Parameters: contract `inputs[*].name` lowercased, typed as `str`
* `args` dict keys: original PascalCase `inputs[*].name`
* `confirm_text` only present when `danger: true`

## Multi-arg example

Contract:
```yaml
id: "update-device"
inputs:
  - name: Id
    required: true
  - name: Name
    required: false
  - name: Site
    required: false
python_wrapper: true
```

Generated:
```python
def update_device(id: str, name: str, site: str) -> dict:
    """
    Updates device metadata. Requires device Id.
    """
    return run_command(
        command_id="update-device",
        args={"Id": id, "Name": name, "Site": site},
        confirm_text="RUN",
    )
```

## Generate

```bash
python3 tools/generate-command-from-template.py docs/contracts/<id>.yaml
```

Set `python_wrapper: true` in the contract to include this output.
