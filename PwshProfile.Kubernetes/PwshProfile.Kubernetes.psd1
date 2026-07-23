@{
    RootModule = 'PwshProfile.Kubernetes.psm1'
    ModuleVersion = '1.0.0'
    FunctionsToExport = @('Select-KubeContext', 'Select-KubeNamespace')
    AliasesToExport = @('kubectx', 'kubens')
}
