function Initialize-Completion {
    if (-not (Get-Command -Name Test-CommandExists -ErrorAction SilentlyContinue)) {
        function Test-CommandExists { param($command) try { $null -ne (Get-Command -Name $command -ErrorAction SilentlyContinue) } catch { $false } }
    }
    if (Test-CommandExists volta) {
        Write-Verbose "Initializing volta completions..."
        volta completions powershell | Out-String | Invoke-Expression
    }
    if (Test-CommandExists pixi) {
        Write-Verbose "Initializing pixi completions..."
        pixi completion --shell powershell | Out-String | Invoke-Expression
    }
    if (Test-CommandExists starship) {
        Write-Verbose "Initializing starship completions..."
        starship init powershell | Out-String | Invoke-Expression
    }

    if (Test-CommandExists zoxide) {
        Write-Verbose "Initializing zoxide completions..."
        zoxide init --cmd cd powershell | Out-String | Invoke-Expression
    }

    if (Test-CommandExists mise) {
        Write-Verbose "Initializing mise completions..."
        mise activate pwsh | Out-String | Invoke-Expression
    }
    Write-Verbose "All external completions initialized."
}
