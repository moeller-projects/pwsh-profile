. (Join-Path (Split-Path $PSScriptRoot -Parent) 'functions/kubernetes-functions.ps1')
Export-ModuleMember -Function Select-KubeContext, Select-KubeNamespace -Alias kubectx, kubens
