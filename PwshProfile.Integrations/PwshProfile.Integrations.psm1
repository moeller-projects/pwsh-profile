. (Join-Path (Split-Path $PSScriptRoot -Parent) 'functions/import-modules.ps1')
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'functions/setup-autocompletions.ps1')
Export-ModuleMember -Function Import-RequiredModules, Initialize-Completion, Get-CachedShellInit
