. (Join-Path (Split-Path $PSScriptRoot -Parent) 'functions/project-functions.ps1')
Export-ModuleMember -Function Get-ProjectConfigPath, Get-ProjectPaths, Set-ProjectPaths, Enter-ProjectDirectory -Alias project, p
