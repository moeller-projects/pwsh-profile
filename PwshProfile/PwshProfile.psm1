# Re-export helper commands from the repository's functions directory

$moduleRoot = $PSScriptRoot
$repoRoot   = Split-Path -Parent $moduleRoot
$functionsPath = Join-Path $repoRoot 'functions'

if (-not (Test-Path -LiteralPath $functionsPath)) {
    Write-Verbose "Functions directory not found at: $functionsPath"
    return
}

Get-ChildItem -LiteralPath $functionsPath -Filter *.ps1 | ForEach-Object {
    try {
        . $_.FullName
    }
    catch {
        Write-Warning "Failed to load function script '$($_.FullName)': $($_.Exception.Message)"
    }
}

# Export all functions and aliases defined by the sourced scripts
Export-ModuleMember -Function * -Alias *

