. (Join-Path (Split-Path $PSScriptRoot -Parent) 'functions/azure-functions.ps1')
Export-ModuleMember -Function New-MenuItem, Switch-AzureSubscription, Connect-ContainerRegistry -Alias sas, lacr
