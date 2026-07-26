@{
    GUID              = '2c6da817-c1f5-4d16-9575-2666b5a7102c'
    Author            = 'moeller-projects'
    CompanyName       = 'moeller-projects'
    Description       = 'Shell integrations and completions loader for pwsh-profile'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RootModule = 'PwshProfile.Integrations.psm1'
    ModuleVersion = '1.1.0'
    FunctionsToExport = @('Import-RequiredModules', 'Initialize-Completion', 'Get-CachedShellInit')
}
