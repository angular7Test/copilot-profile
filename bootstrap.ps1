$script:CopilotCustomBootstrapLoaded = $true
$script:CopilotCustomRepoPath = $PSScriptRoot
$script:CopilotCustomStatePath = Join-Path $env:LOCALAPPDATA "copilot-custom\\state.json"
$script:CopilotCustomProvidersPath = Join-Path $script:CopilotCustomRepoPath "copilot-providers.ps1"
$script:CopilotCustomFunctionPath = Join-Path $script:CopilotCustomRepoPath "copilot-function.ps1"

function Update-CopilotCustom {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    $git = Get-Command -Name git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $git) {
        Write-Host "git not found. Skipping copilot-custom update check." -ForegroundColor Yellow
        return $false
    }

    if (-not (Test-Path (Join-Path $script:CopilotCustomRepoPath ".git"))) {
        return $false
    }

    $shouldCheck = $true
    if (-not $Force -and (Test-Path $script:CopilotCustomStatePath)) {
        try {
            $state = Get-Content -Path $script:CopilotCustomStatePath -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($state.lastCheckAt) {
                $lastCheck = [DateTimeOffset]::Parse($state.lastCheckAt)
                if ($lastCheck.AddHours(24) -gt [DateTimeOffset]::UtcNow) {
                    $shouldCheck = $false
                }
            }
        }
        catch {
            $shouldCheck = $true
        }
    }

    if (-not $shouldCheck) {
        return $false
    }

    Write-Host "Checking for copilot-custom updates..." -ForegroundColor DarkCyan

    $previousCommit = & $git.Source -C $script:CopilotCustomRepoPath rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    & $git.Source -C $script:CopilotCustomRepoPath pull --ff-only --quiet 2>$null
    $pulled = $LASTEXITCODE -eq 0

    $currentCommit = & $git.Source -C $script:CopilotCustomRepoPath rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    $stateDir = Split-Path -Path $script:CopilotCustomStatePath -Parent
    if (-not (Test-Path $stateDir)) {
        New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
    }

    $statePayload = [ordered]@{
        lastCheckAt = [DateTimeOffset]::UtcNow.ToString("o")
        lastKnownCommit = $currentCommit
    }
    $statePayload | ConvertTo-Json -Depth 3 | Set-Content -Path $script:CopilotCustomStatePath -Encoding UTF8

    if (-not $pulled) {
        Write-Host "Update check skipped (pull failed). Using local copilot-custom copy." -ForegroundColor Yellow
        return $false
    }

    if ($previousCommit -ne $currentCommit) {
        Write-Host "copilot-custom updated from repository." -ForegroundColor Green
        return $true
    }

    Write-Host "copilot-custom is already up to date." -ForegroundColor DarkGray
    return $false
}

if (Test-Path $script:CopilotCustomProvidersPath) {
    . $script:CopilotCustomProvidersPath
}
else {
    Write-Host "Missing copilot-providers.ps1 in $script:CopilotCustomRepoPath" -ForegroundColor Yellow
}

if (Test-Path $script:CopilotCustomFunctionPath) {
    . $script:CopilotCustomFunctionPath
}
else {
    Write-Host "Missing copilot-function.ps1 in $script:CopilotCustomRepoPath" -ForegroundColor Yellow
}
