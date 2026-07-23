function Initialize-Completion {
    if (Get-Command -Name volta -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing volta completions..."
        & ([ScriptBlock]::Create((volta completions powershell | Out-String)))
    }
    if (Get-Command -Name pixi -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing pixi completions..."
        & ([ScriptBlock]::Create((pixi completion --shell powershell | Out-String)))
    }

    if (Get-Command -Name zoxide -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing zoxide completions..."
        & ([ScriptBlock]::Create((zoxide init --cmd cd powershell | Out-String)))
    }

    if (Get-Command -Name mise -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing mise completions..."
        & ([ScriptBlock]::Create((mise activate pwsh | Out-String)))
    }

    if (Get-Command -Name kiro -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing kiro completions..."
        & ([ScriptBlock]::Create((kiro --locate-shell-integration-path pwsh | Out-String)))
    }


    Write-Verbose "All external completions initialized."
}
