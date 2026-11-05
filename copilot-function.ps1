function copilot-custom {
    [CmdletBinding()]
    param(
        [switch]$SkipRemoteSync,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$RemainingArgs
    )

    $hasRemainingArgs = $null -ne $RemainingArgs -and $RemainingArgs.Count -gt 0
    if ($hasRemainingArgs -and $RemainingArgs.Count -eq 1 -and [string]::IsNullOrWhiteSpace($RemainingArgs[0])) {
        $hasRemainingArgs = $false
        $RemainingArgs = @()
    }

    $realCopilot = Get-Command -Name copilot -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $realCopilot) {
        throw "Could not find the copilot executable in PATH."
    }

    $caller = (Get-PSCallStack | Select-Object -Skip 1 -First 1).Command
    if ($caller -in @("copilot-azure", "copilot-deepseek", "copilot-nvidia", "copilot-default")) {
        & $realCopilot.Source @RemainingArgs
        return
    }

    if (-not $SkipRemoteSync -and -not $hasRemainingArgs -and -not $script:CopilotRemoteSyncInProgress) {
        $repoOwner = "angular7Test"
        $repoName = "copilot-profile"
        $remoteScriptPath = "copilot-function.ps1"
        $syncDir = Join-Path $env:LOCALAPPDATA "copilot-custom"
        $downloadPath = Join-Path $syncDir "copilot-function.latest.ps1"
        $statePath = Join-Path $syncDir "sync-state.json"
        $gh = Get-Command -Name gh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($gh) {
            Write-Host "Checking GitHub for latest copilot-custom function..." -ForegroundColor DarkCyan
            $script:CopilotRemoteSyncInProgress = $true
            try {
                $null = & $gh.Source api "repos/$repoOwner/$repoName" --jq .private 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $remoteSha = & $gh.Source api "repos/$repoOwner/$repoName/contents/$remoteScriptPath" --jq .sha 2>$null
                    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($remoteSha)) {
                        $cachedSha = $null
                        if (Test-Path $statePath) {
                            try {
                                $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json -ErrorAction Stop
                                $cachedSha = $state.remoteSha
                            }
                            catch {
                                $cachedSha = $null
                            }
                        }

                        if ($cachedSha -eq $remoteSha -and (Test-Path $downloadPath)) {
                            Write-Host "Local cache is up to date. Skipping download." -ForegroundColor DarkGray
                            . $downloadPath
                            $resolvedCopilot = Get-Command -Name copilot-custom -CommandType Function -ErrorAction SilentlyContinue
                            if ($resolvedCopilot -and $resolvedCopilot.Parameters.ContainsKey("SkipRemoteSync")) {
                                & copilot-custom -SkipRemoteSync @RemainingArgs
                            }
                            else {
                                & copilot-custom @RemainingArgs
                            }
                            return
                        }

                        Write-Host "New version detected. Downloading latest function..." -ForegroundColor DarkCyan
                        $content = & $gh.Source api "repos/$repoOwner/$repoName/contents/$remoteScriptPath" --jq .content 2>$null
                        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($content)) {
                            $decodedContent = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($content -replace '\s', '')))
                            if ($decodedContent -match "(?m)^function\s+copilot-custom\s*\{") {
                                Write-Host "Latest function found. Applying updates..." -ForegroundColor Green
                                New-Item -Path $syncDir -ItemType Directory -Force | Out-Null
                                Set-Content -Path $downloadPath -Value $decodedContent -Encoding UTF8

                                $statePayload = [ordered]@{
                                    remoteSha = $remoteSha
                                    syncedAt = (Get-Date).ToString("o")
                                    repository = "$repoOwner/$repoName"
                                    scriptPath = $remoteScriptPath
                                }
                                $statePayload | ConvertTo-Json -Depth 4 | Set-Content -Path $statePath -Encoding UTF8

                                . $downloadPath
                                $resolvedCopilot = Get-Command -Name copilot-custom -CommandType Function -ErrorAction SilentlyContinue
                                if ($resolvedCopilot -and $resolvedCopilot.Parameters.ContainsKey("SkipRemoteSync")) {
                                    & copilot-custom -SkipRemoteSync @RemainingArgs
                                }
                                else {
                                    & copilot-custom @RemainingArgs
                                }
                                return
                            }
                            Write-Host "Remote function format is invalid. Continuing with local copilot-custom." -ForegroundColor Yellow
                        }
                        else {
                            Write-Host "Remote function content unavailable. Continuing with local copilot-custom." -ForegroundColor Yellow
                        }
                    }
                    else {
                        Write-Host "Remote function metadata unavailable. Continuing with local copilot-custom." -ForegroundColor Yellow
                    }
                }
                else {
                    Write-Host "Cannot access GitHub repository. Continuing with local copilot-custom." -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "GitHub sync failed. Continuing with local copilot-custom." -ForegroundColor Yellow
                Write-Verbose "Remote copilot sync skipped: $($_.Exception.Message)"
            }
            finally {
                $script:CopilotRemoteSyncInProgress = $false
            }
        }
        else {
            Write-Host "GitHub CLI not found. Continuing with local copilot-custom." -ForegroundColor Yellow
        }
    }

    if ($hasRemainingArgs) {
        & $realCopilot.Source @RemainingArgs
        return
    }

    $providerFunctions = Get-Command -Name "copilot-*" -CommandType Function -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "copilot-custom" } |
        Select-Object -ExpandProperty Name -Unique

    if (-not $providerFunctions) {
        & $realCopilot.Source
        return
    }

    $orderedFunctions = @()
    if ($providerFunctions -contains "copilot-azure") {
        $orderedFunctions += "copilot-azure"
    }
    $orderedFunctions += $providerFunctions |
        Where-Object { $_ -ne "copilot-azure" } |
        Sort-Object

    Write-Host "Available Copilot launch options:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $orderedFunctions.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $orderedFunctions[$i])
    }

    $defaultFunction = if ($orderedFunctions -contains "copilot-azure") { "copilot-azure" } else { $orderedFunctions[0] }
    $choice = Read-Host "Select an option (1-$($orderedFunctions.Count)) or press Enter for $defaultFunction"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        $selectedFunction = $defaultFunction
    }
    else {
        $index = 0
        if (-not [int]::TryParse($choice.Trim(), [ref]$index) -or $index -lt 1 -or $index -gt $orderedFunctions.Count) {
            throw "Invalid selection. Choose a number between 1 and $($orderedFunctions.Count), or press Enter for $defaultFunction."
        }
        $selectedFunction = $orderedFunctions[$index - 1]
    }

    & $selectedFunction
}