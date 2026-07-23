. (Join-Path (Split-Path $PSScriptRoot -Parent) 'functions/ai-functions.ps1')
Export-ModuleMember -Function Set-AIConfiguration, Invoke-ChatGpt -Alias ask
