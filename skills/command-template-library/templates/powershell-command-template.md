# PowerShell Command Naming Template

Reference for mapping PSIGEL PowerShell cmdlets to mq-ums contract `psCommand` values.

## Verb conventions

| Verb | Danger | Use case |
|---|---|---|
| `Get-` | false | Read-only list or detail |
| `New-` | true | Create a new object |
| `Update-` | true | Modify metadata or rename |
| `Move-` | true | Change parent/location |
| `Remove-` | true | Delete permanently |
| `Restart-` | true | Reboot device |
| `Reset-` | true | Factory reset (destructive) |
| `Start-` | true | Wake-on-LAN |
| `Stop-` | true | Shutdown |
| `Send-` | true | Push settings to device |

## Noun conventions

| Noun | Section |
|---|---|
| `UMSDevice` | Devices |
| `UMSDeviceDirectory` | Device Directories |
| `UMSProfile` | Profiles |
| `UMSProfileDirectory` | Profile Directories |
| `UMSDeviceAssignment` | Assignments |
| `UMSDeviceDirectoryAssignment` | Assignments |
| `UMSProfileAssignment` | Assignments |
| `UMSFirmware` | Status |
| `UMSStatus` | Status |

## Examples

```text
Get-UMSDevice           → get-device       danger: false
Restart-UMSDevice       → restart-device   danger: true  confirmText: RUN
New-UMSDeviceDirectory  → new-device-directory danger: true confirmText: RUN
Remove-UMSProfile       → remove-profile   danger: true  confirmText: RUN
```
