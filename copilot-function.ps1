function copilot-custom {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$RemainingArgs
    )

    $hasRemainingArgs = $null -ne $RemainingArgs -and $RemainingArgs.Count -gt 0
    if ($hasRemainingArgs -and $RemainingArgs.Count -eq 1 -and [string]::IsNullOrWhiteSpace($RemainingArgs[0])) {
        $hasRemainingArgs = $false
        $RemainingArgs = @()
    }

    if (-not $script:CopilotCustomAutoUpdateInProgress) {
        $updateCommand = Get-Command -Name Update-CopilotCustom -CommandType Function -ErrorAction SilentlyContinue
        if ($updateCommand) {
            try {
                $updated = Update-CopilotCustom
            }
            catch {
                $updated = $false
                Write-Verbose "Update-CopilotCustom failed before launch: $($_.Exception.Message)"
            }

            if ($updated -and (Test-Path $script:CopilotCustomFunctionPath)) {
                $script:CopilotCustomAutoUpdateInProgress = $true
                try {
                    . $script:CopilotCustomFunctionPath
                    & copilot-custom @RemainingArgs
                    return
                }
                finally {
                    $script:CopilotCustomAutoUpdateInProgress = $false
                }
            }
        }
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
