# ai-functions.ps1
function Configure-AI {
    Write-Host "Configuring AI environment variables." -ForegroundColor Cyan
    $provider = Read-Host "Enter AI Provider"
    $apiKeySecure = Read-Host "Enter OpenAI API Key" -AsSecureString
    $model = Read-Host "Enter OpenAI Model"

    # Convert the secure string to plain for env var storage (user scope)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKeySecure)
    try { $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

    [System.Environment]::SetEnvironmentVariable('AI_PROVIDER', $provider, [System.EnvironmentVariableTarget]::User)
    [System.Environment]::SetEnvironmentVariable('OPENAI_API_KEY', $apiKey, [System.EnvironmentVariableTarget]::User)
    [System.Environment]::SetEnvironmentVariable('OPENAI_MODEL', $model, [System.EnvironmentVariableTarget]::User)
    Write-Host "AI environment variables configured for current user." -ForegroundColor Green
}

function Ask-ChatGpt {
    [CmdletBinding()]
    [Alias("ask")]
    param (
        [string[]]$Args,
        [switch]$UseShell
    )

    if (-not $env:OPENAI_API_KEY) {
        Write-Error "Error: The OPENAI_API_KEY environment variable is not set."
        return
    }

    $tgptArgs = @()
    if ($UseShell) { $tgptArgs += '-s' }
    $prompt = if ($Args) { ($Args -join ' ') } else { '' }
    if ($prompt -ne '') { $tgptArgs += '--'; $tgptArgs += $prompt }
    Write-Verbose ("Executing AI command: tgpt {0}" -f ($tgptArgs -join ' '))
    & tgpt @tgptArgs
}
