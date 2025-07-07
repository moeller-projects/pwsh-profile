function Initialize-Completion {
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
    Write-Verbose "All external completions initialized."
}
