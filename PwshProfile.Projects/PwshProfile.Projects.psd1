@{
    RootModule        = 'PwshProfile.Projects.psm1'
    ModuleVersion     = '1.1.0'
    GUID              = 'fb6e047a-ae39-4ad6-bc35-73f2021c090e'
    Author            = 'moeller-projects'
    CompanyName       = 'moeller-projects'
    Description       = 'Project directory navigation helpers for the pwsh-profile.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport = @('Get-ProjectConfigPath', 'Get-ProjectPaths', 'Set-ProjectPaths', 'Enter-ProjectDirectory')
    AliasesToExport   = @('project', 'p')
}
