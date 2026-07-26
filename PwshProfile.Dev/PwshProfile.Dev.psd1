@{
    GUID              = '6f0d3a55-6005-4f80-a0f6-3512b6bb0fd8'
    Author            = 'moeller-projects'
    CompanyName       = 'moeller-projects'
    Description       = 'Developer productivity helpers for pwsh-profile'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RootModule = 'PwshProfile.Dev.psm1'
    ModuleVersion = '1.1.0'
    FunctionsToExport = @('Get-RecentHistory', 'Clear-Cache', 'pkill', 'pgrep', 'Stop-ProcessForce', 'sysinfo', 'flushdns', 'which', 'export', 'uptime', 'Use-Env', 'kcinfo', 'Get-ProcessPort', 'Stop-ProcessPort')
    AliasesToExport = @('k9', 'k', 'kctx')
}
