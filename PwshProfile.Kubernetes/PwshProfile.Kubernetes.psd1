@{
    GUID              = '7c09ce40-792a-4af4-90b9-6d7680c1ea07'
    Author            = 'moeller-projects'
    CompanyName       = 'moeller-projects'
    Description       = 'Kubernetes context and namespace helpers for pwsh-profile'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RootModule = 'PwshProfile.Kubernetes.psm1'
    ModuleVersion = '1.1.0'
    FunctionsToExport = @('Select-KubeContext', 'Select-KubeNamespace')
    AliasesToExport = @('kubectx', 'kubens')
}
