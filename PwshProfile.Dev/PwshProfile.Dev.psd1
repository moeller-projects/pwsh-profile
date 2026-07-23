@{
    RootModule = 'PwshProfile.Dev.psm1'
    ModuleVersion = '1.0.0'
    FunctionsToExport = @('Get-ProjectConfigPath', 'Get-ProjectPaths', 'Set-ProjectPaths', 'Enter-ProjectDirectory', 'Get-RecentHistory', 'Clear-Cache', 'pkill', 'pgrep', 'Stop-ProcessForce', 'sysinfo', 'flushdns', 'which', 'export', 'uptime', 'Use-Env', 'gdev', 'gmain', 'gup', 'gsave', 'kcinfo', 'Get-ProcessPort', 'Stop-ProcessPort')
    AliasesToExport = @('project', 'p', 'k9', 'k', 'kctx')
}
