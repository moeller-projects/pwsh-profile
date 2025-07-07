# ai-functions.ps1
function Configure-AI {
    Write-Host "Configuring AI environment variables." -ForegroundColor Cyan
    $provider = Read-Host "Enter AI Provider"
    $apiKey = Read-Host "Enter OpenAI API Key"
    $model = Read-Host "Enter OpenAI Model"

    [System.Environment]::SetEnvironmentVariable('AI_PROVIDER', $provider, [System.EnvironmentVariableTarget]::Machine)
    [System.Environment]::SetEnvironmentVariable('OPENAI_API_KEY', $apiKey, [System.EnvironmentVariableTarget]::Machine)
    [System.Environment]::SetEnvironmentVariable('OPENAI_MODEL', $model, [System.EnvironmentVariableTarget]::Machine) # Fixed typo OPENAI_MODEL
    Write-Host "AI environment variables configured." -ForegroundColor Green
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

    $argsString = $Args -join ' '
    $shellOption = if ($UseShell) { '-s' } else { '' }
    $command = "tgpt $shellOption `"$argsString`""
    Write-Verbose "Executing AI command: $command"
    Invoke-Expression $command # External call to tgpt - inherent overhead
}
