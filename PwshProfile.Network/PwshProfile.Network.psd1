@{
    GUID              = 'b7d8e660-ad34-4fa9-81c0-95ddd42fb07b'
    Author            = 'moeller-projects'
    CompanyName       = 'moeller-projects'
    Description       = 'Network utility helpers for pwsh-profile'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RootModule = 'PwshProfile.Network.psm1'
    ModuleVersion = '1.1.0'
    FunctionsToExport = @('Get-PubIP')
}
