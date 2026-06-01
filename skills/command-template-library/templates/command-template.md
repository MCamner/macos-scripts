# Command Contract Template

Full field reference for `mq-ums/docs/contracts/<id>.yaml`.

## Required fields

| Field | Type | Example |
|---|---|---|
| `id` | kebab-case string | `get-device` |
| `name` | string | `Get Devices` |
| `section` | string | `Devices` |
| `psCommand` | string | `Get-UMSDevice` |
| `description` | string | `Lists devices registered in UMS.` |
| `danger` | bool | `false` |

## Conditional fields

| Field | When required | Example |
|---|---|---|
| `confirmText` | `danger: true` | `RUN` |

## Optional fields

| Field | Type | Example |
|---|---|---|
| `inputs` | list | see below |
| `python_wrapper` | bool | `true` |

## inputs entry

```yaml
inputs:
  - name: Id            # PascalCase, matches PSIGEL arg
    required: true      # or false
    notes: "Numeric device ID from Get Devices"
```

## Full example

```yaml
id: "get-device"
name: "Get Devices"
section: "Devices"
psCommand: "Get-UMSDevice"
description: "Lists devices registered in UMS. Pass Id for a single device."
danger: false
inputs:
  - name: Id
    required: false
    notes: "Numeric device ID. Omit to list all devices."
  - name: Filter
    required: false
    notes: "short | details | online | shadow | deviceattributes | networkadapters"
python_wrapper: false
```

## Sections in use

* Status
* Devices
* Device Directories
* Profiles
* Profile Directories
* Assignments
