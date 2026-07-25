@{
    GUID              = '10a35f87-e660-4403-90c3-7053ef991a30'
    Author            = 'moeller-projects'
    CompanyName       = 'moeller-projects'
    Description       = 'AI integration helpers for pwsh-profile (ChatGPT, lumen)'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RootModule = 'PwshProfile.AI.psm1'
    ModuleVersion = '1.1.0'
    FunctionsToExport = @('Set-AIConfiguration', 'Invoke-ChatGpt')
    AliasesToExport = @('ask')
}
