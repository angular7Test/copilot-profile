if (-not (Get-Command -Name Remove-CopilotEnv -CommandType Function -ErrorAction SilentlyContinue)) {
    function Remove-CopilotEnv {
        Remove-Item Env:COPILOT_* -ErrorAction SilentlyContinue
    }
}

function copilot-azure {
    try {
        $endpoint = "https://arun-openai-test-2.openai.azure.com/openai"
        $apiKey = [Environment]::GetEnvironmentVariable("COPILOT_AZURE_API_KEY", "Machine")
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            $apiKey = [Environment]::GetEnvironmentVariable("COPILOT_AZURE_API_KEY", "User")
        }
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            Write-Host "Missing required environment variable: COPILOT_AZURE_API_KEY" -ForegroundColor Yellow
            Write-Host "Set COPILOT_AZURE_API_KEY, then re-run: copilot-azure" -ForegroundColor Yellow
            return
        }
        $apiVersion = "2025-04-01-preview"

        Write-Host "Available Azure OpenAI deployments:" -ForegroundColor Cyan
        Write-Host "  1. gpt-5.3-codex (default)"
        Write-Host "  2. gpt-6-astra"
        Write-Host "  3. gpt-6.1-sol"

        $choice = Read-Host "Select a model (1-3) or press Enter for gpt-5.3-codex"
        switch ($choice.Trim()) {
            "" { $deployment = "gpt-5.3-codex" }
            "1" { $deployment = "gpt-5.3-codex" }
            "2" { $deployment = "gpt-6-astra" }
            "3" { $deployment = "gpt-6.1-sol" }
            default { throw "Invalid model selection. Choose 1, 2, or 3." }
        }

        Write-Host "Available reasoning effort levels:" -ForegroundColor Cyan
        Write-Host "  1. low"
        Write-Host "  2. medium"
        Write-Host "  3. high (default)"
        Write-Host "  4. xhigh"

        $reasoningChoice = Read-Host "Select reasoning effort (1-4) or press Enter for high"
        switch ($reasoningChoice.Trim()) {
            "" { $reasoningEffort = "high" }
            "1" { $reasoningEffort = "low" }
            "2" { $reasoningEffort = "medium" }
            "3" { $reasoningEffort = "high" }
            "4" { $reasoningEffort = "xhigh" }
            default { throw "Invalid reasoning selection. Choose 1, 2, 3, or 4." }
        }

        $env:COPILOT_PROVIDER_TYPE = "azure"
        $env:COPILOT_PROVIDER_BASE_URL = $endpoint
        $env:COPILOT_PROVIDER_API_KEY = $apiKey
        $env:COPILOT_MODEL = $deployment
        $env:COPILOT_AZURE_API_VERSION = $apiVersion
        $env:COPILOT_PROVIDER_WIRE_API = "responses"
        $env:COPILOT_SKILLS_DISABLED = "true"

        Write-Host "Using Azure deployment: $deployment with reasoning effort: $reasoningEffort" -ForegroundColor Green
        $env:COPILOT_EDITOR = "notepad.exe"
        $env:VISUAL = "notepad.exe"
        $env:EDITOR = "notepad.exe"
        copilot --reasoning-effort $reasoningEffort
    }
    finally {
        Remove-CopilotEnv
    }
}
