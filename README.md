# Copilot Custom Launcher

This repository provides a maintainable `copilot-custom` launcher for PowerShell.

- `copilot` stays untouched (`copilot.exe` default behavior).
- `$PROFILE` only contains a small bootstrap block.
- Full launcher logic lives in this repo (`copilot-function.ps1`).
- Updates are checked once per day via git pull in `bootstrap.ps1`.

## First-time setup (any computer)

```powershell
git clone https://github.com/angular7Test/copilot-profile.git
cd copilot-profile
.\install-copilot-custom.ps1
copilot-custom
```

## Manual update

After profile load, run:

```powershell
Update-CopilotCustom -Force
```
