function copilot {
    [CmdletBinding()]
    param(
        [switch]$SkipRemoteSync,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    $realCopilot = Get-Command -Name copilot -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $realCopilot) {
        throw "Could not find the copilot executable in PATH."
    }

    $caller = (Get-PSCallStack | Select-Object -Skip 1 -First 1).Command
    if ($caller -in @("copilot-azure", "copilot-deepseek", "copilot-nvidia", "copilot-default")) {
        & $realCopilot.Source @Args
        return
    }

    if (-not $SkipRemoteSync -and $Args.Count -eq 0 -and -not $script:CopilotRemoteSyncInProgress) {
        $repoOwner = "angular7Test"
        $repoName = "copilot-profile"
        $remoteScriptPath = "copilot-function.ps1"
        $gh = Get-Command -Name gh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($gh) {
            $script:CopilotRemoteSyncInProgress = $true
            try {
                $null = & $gh.Source api "repos/$repoOwner/$repoName" --jq .private 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $content = & $gh.Source api "repos/$repoOwner/$repoName/contents/$remoteScriptPath" --jq .content 2>$null
                    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($content)) {
                        $decodedContent = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($content -replace '\s', '')))
                        if ($decodedContent -match "(?m)^function\s+copilot\s*\{") {
                            $downloadPath = Join-Path $env:TEMP "copilot-function.latest.ps1"
                            Set-Content -Path $downloadPath -Value $decodedContent -Encoding UTF8
                            . $downloadPath

                            $resolvedCopilot = Get-Command -Name copilot -CommandType Function -ErrorAction SilentlyContinue
                            if ($resolvedCopilot -and $resolvedCopilot.Parameters.ContainsKey("SkipRemoteSync")) {
                                & copilot -SkipRemoteSync @Args
                            }
                            else {
                                & copilot @Args
                            }
                            return
                        }
                    }
                }
            }
            catch {
                Write-Verbose "Remote copilot sync skipped: $($_.Exception.Message)"
            }
            finally {
                $script:CopilotRemoteSyncInProgress = $false
            }
        }
    }

    if ($Args.Count -gt 0) {
        & $realCopilot.Source @Args
        return
    }

    $providerFunctions = Get-Command -Name "copilot-*" -CommandType Function -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "copilot" } |
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
