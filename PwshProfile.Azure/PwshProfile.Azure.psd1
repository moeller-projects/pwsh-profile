@{
    RootModule = 'PwshProfile.Azure.psm1'
    ModuleVersion = '1.0.0'
    FunctionsToExport = @('New-MenuItem', 'Switch-AzureSubscription', 'Connect-ContainerRegistry', 'New-NetworkAccessExceptionForResources')
    AliasesToExport = @('sas', 'lacr', 'cna')
}
