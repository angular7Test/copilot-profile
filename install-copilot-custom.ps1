[CmdletBinding()]
param(
    [string]$ProfilePath = $PROFILE,
    [string]$RepoPath = (Join-Path $env:LOCALAPPDATA "copilot-custom\\repo"),
    [switch]$NoReload
)

$git = Get-Command -Name git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $git) {
    throw "git is required to install copilot-custom."
}

$bootstrapFile = Join-Path $PSScriptRoot "bootstrap.ps1"
$functionFile = Join-Path $PSScriptRoot "copilot-function.ps1"
if (-not (Test-Path $bootstrapFile) -or -not (Test-Path $functionFile)) {
    throw "Installer must run from the copilot-profile repository root."
}

$repoParent = Split-Path -Path $RepoPath -Parent
if (-not (Test-Path $repoParent)) {
    New-Item -Path $repoParent -ItemType Directory -Force | Out-Null
}

if (Test-Path (Join-Path $RepoPath ".git")) {
    & $git.Source -C $RepoPath pull --ff-only --quiet 2>$null | Out-Null
}
elseif (Test-Path $RepoPath) {
    throw "Repo path exists but is not a git repository: $RepoPath"
}
else {
    & $git.Source clone --quiet $PSScriptRoot $RepoPath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone repository into $RepoPath"
    }
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

$startMarker = "# >>> copilot-custom bootstrap >>>"
$endMarker = "# <<< copilot-custom bootstrap <<<"

$bootstrapBlock = @"
$startMarker
`$CopilotCustomRepoPath = Join-Path `$env:LOCALAPPDATA "copilot-custom\\repo"
`$CopilotCustomBootstrap = Join-Path `$CopilotCustomRepoPath "bootstrap.ps1"
if (Test-Path `$CopilotCustomBootstrap) {
    . `$CopilotCustomBootstrap
}
$endMarker
"@

$pattern = [regex]::Escape($startMarker) + "(?s).*?" + [regex]::Escape($endMarker)
if ([regex]::IsMatch($profileText, $pattern)) {
    $updatedText = [regex]::Replace($profileText, $pattern, $bootstrapBlock)
}
else {
    $updatedText = $profileText.TrimEnd() + "`r`n`r`n" + $bootstrapBlock + "`r`n"
}

Set-Content -Path $ProfilePath -Value $updatedText -Encoding UTF8

if (-not $NoReload) {
    . $ProfilePath
}

Write-Host "Installed copilot-custom bootstrap into: $ProfilePath" -ForegroundColor Green
Write-Host "Local repo path: $RepoPath" -ForegroundColor DarkCyan
Write-Host "Backup created: $backupPath" -ForegroundColor DarkCyan
Write-Host "Use 'copilot-custom' to launch." -ForegroundColor Cyan
