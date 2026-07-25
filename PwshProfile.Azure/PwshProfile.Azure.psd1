@{
    GUID              = '07915f98-05b5-478a-93cc-7baebb6352b6'
    Author            = 'moeller-projects'
    CompanyName       = 'moeller-projects'
    Description       = 'Azure CLI helpers and ACR integration for pwsh-profile'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RootModule = 'PwshProfile.Azure.psm1'
    ModuleVersion = '1.1.0'
    FunctionsToExport = @('New-MenuItem', 'Switch-AzureSubscription', 'Connect-ContainerRegistry')
    AliasesToExport = @('sas', 'lacr')
}
