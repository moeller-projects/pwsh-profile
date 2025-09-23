function Initialize-Completion {
    if (Get-Command -Name volta -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing volta completions..."
        volta completions powershell | Out-String | Invoke-Expression
    }
    if (Get-Command -Name pixi -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing pixi completions..."
        pixi completion --shell powershell | Out-String | Invoke-Expression
    }
    if (Get-Command -Name starship -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing starship completions..."
        starship init powershell | Out-String | Invoke-Expression
    }

    if (Get-Command -Name zoxide -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing zoxide completions..."
        zoxide init --cmd cd powershell | Out-String | Invoke-Expression
    }

    if (Get-Command -Name mise -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing mise completions..."
        mise activate pwsh | Out-String | Invoke-Expression
    }
    Write-Verbose "All external completions initialized."
}
