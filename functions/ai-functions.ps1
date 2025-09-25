# ai-functions.ps1
function Set-AIConfiguration {
    [CmdletBinding()]
    param()
    Write-Host "Configuring AI settings" -ForegroundColor Cyan
    $provider = Read-Host "Enter AI Provider (e.g., openai)"
    $apiKeySecure = Read-Host "Enter OpenAI API Key" -AsSecureString
    $model = Read-Host "Enter OpenAI Model (e.g., gpt-4o-mini)"

    # Convert secure string safely
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKeySecure)
    try { $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

    # Prefer SecretManagement if available
    if (Get-Command -Name Set-Secret -ErrorAction SilentlyContinue) {
        try {
            Set-Secret -Name OPENAI_API_KEY -Secret $apiKey -ErrorAction Stop
            Write-Host "Stored API key in SecretManagement (name: OPENAI_API_KEY)." -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to store secret via SecretManagement: $($_.Exception.Message). Falling back to user env var."
            [System.Environment]::SetEnvironmentVariable('OPENAI_API_KEY', $apiKey, [System.EnvironmentVariableTarget]::User)
        }
    } else {
        [System.Environment]::SetEnvironmentVariable('OPENAI_API_KEY', $apiKey, [System.EnvironmentVariableTarget]::User)
        Write-Host "Stored API key in user environment (OPENAI_API_KEY)." -ForegroundColor Yellow
    }

    [System.Environment]::SetEnvironmentVariable('AI_PROVIDER', $provider, [System.EnvironmentVariableTarget]::User)
    [System.Environment]::SetEnvironmentVariable('OPENAI_MODEL', $model, [System.EnvironmentVariableTarget]::User)
    Write-Host "AI provider/model configured for current user." -ForegroundColor Green
}

function Invoke-ChatGpt {
    [CmdletBinding()]
    [Alias("ask")]
    param (
        [string[]]$Args,
        [switch]$UseShell
    )

    if (-not $env:OPENAI_API_KEY) {
        # Try SecretManagement fallback
        if (Get-Command -Name Get-Secret -ErrorAction SilentlyContinue) {
            try { $secret = Get-Secret -Name OPENAI_API_KEY -ErrorAction Stop } catch { $secret = $null }
            if ($secret) { $env:OPENAI_API_KEY = [string]$secret }
        }
    }
    if (-not $env:OPENAI_API_KEY) {
        Write-Error "Error: OPENAI_API_KEY not available. Use Set-AIConfiguration to set it."
        return
    }

    $tgptArgs = @()
    if ($UseShell) { $tgptArgs += '-s' }
    $prompt = if ($Args) { ($Args -join ' ') } else { '' }
    if ($prompt -ne '') { $tgptArgs += '--'; $tgptArgs += $prompt }
    Write-Verbose ("Executing AI command: tgpt {0}" -f ($tgptArgs -join ' '))
    & tgpt @tgptArgs
}
