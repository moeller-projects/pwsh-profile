@{
    RootModule = 'PwshProfile.AI.psm1'
    ModuleVersion = '1.0.0'
    FunctionsToExport = @('Set-AIConfiguration', 'Invoke-ChatGpt')
    AliasesToExport = @('ask')
}
