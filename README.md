# Copilot Custom Launcher

This repository provides a maintainable `copilot-custom` launcher for PowerShell.

- `copilot` stays untouched (`copilot.exe` default behavior).
- `$PROFILE` only contains a small bootstrap block.
- Full launcher logic lives in this repo (`copilot-function.ps1`).
- `bootstrap.ps1` only loads commands at shell startup (no network check).
- Updates are checked once per day via git pull when `copilot-custom` is invoked.
- `copilot-providers.ps1` supplies provider functions (including `copilot-azure`) and refreshes stale local wrappers.

## First-time setup (any computer)

```powershell
git clone https://github.com/angular7Test/copilot-profile.git
cd copilot-profile
.\install-copilot-custom.ps1
copilot-custom
```

This works on clean machines too (no existing `copilot-azure` function required); providers are loaded from this repo.

## Manual update

After profile load, run:

```powershell
Update-CopilotCustom -Force
```
