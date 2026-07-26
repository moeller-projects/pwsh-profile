. (Join-Path (Split-Path $PSScriptRoot -Parent) 'functions/dev-functions.ps1')
Export-ModuleMember -Function Get-RecentHistory, Clear-Cache, pkill, pgrep, Stop-ProcessForce, sysinfo, flushdns, which, export, uptime, Use-Env, kcinfo, Get-ProcessPort, Stop-ProcessPort -Alias k9, k, kctx
