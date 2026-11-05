[CmdletBinding()]
param(
    [string]$ProfilePath = $PROFILE,
    [switch]$NoReload
)

$functionFile = Join-Path $PSScriptRoot "copilot-function.ps1"
if (-not (Test-Path $functionFile)) {
    throw "Missing function file: $functionFile"
}

$functionText = Get-Content -Path $functionFile -Raw
if ($functionText -notmatch "(?m)^function\s+copilot-custom\s*\{") {
    throw "copilot-function.ps1 must contain function copilot-custom."
}

$profileDir = Split-Path -Path $ProfilePath -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
}

if (-not (Test-Path $ProfilePath)) {
    New-Item -Path $ProfilePath -ItemType File -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = "$ProfilePath.bak-$timestamp"
Copy-Item -Path $ProfilePath -Destination $backupPath -Force

$profileText = Get-Content -Path $ProfilePath -Raw
if ($null -eq $profileText) {
    $profileText = ""
}

$updatedText = $profileText
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($profileText, [ref]$tokens, [ref]$parseErrors)

if (-not $parseErrors -or $parseErrors.Count -eq 0) {
    $existing = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq "copilot-custom"
    }, $true) | Sort-Object { $_.Extent.StartOffset } -Descending

    foreach ($fn in $existing) {
        $start = $fn.Extent.StartOffset
        $length = $fn.Extent.EndOffset - $fn.Extent.StartOffset
        $updatedText = $updatedText.Remove($start, $length)
    }
}

$updatedText = $updatedText.TrimEnd() + "`r`n`r`n" + $functionText.Trim() + "`r`n"
Set-Content -Path $ProfilePath -Value $updatedText -Encoding UTF8

if (-not $NoReload) {
    . $ProfilePath
}

Write-Host "Installed copilot-custom into: $ProfilePath" -ForegroundColor Green
Write-Host "Backup created: $backupPath" -ForegroundColor DarkCyan
Write-Host "Next: run 'copilot-custom'" -ForegroundColor Cyan
