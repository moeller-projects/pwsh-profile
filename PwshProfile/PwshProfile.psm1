$moduleRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $moduleRoot
$functionsPath = Join-Path $repoRoot 'functions'

$script:PwshProfilePublicFunctions = @(
    'Set-AIConfiguration',
    'Invoke-ChatGpt',
    'New-MenuItem',
    'Switch-AzureSubscription',
    'Connect-ContainerRegistry',
    'New-NetworkAccessExceptionForResources',
    'Get-ProjectConfigPath',
    'Get-ProjectPaths',
    'Set-ProjectPaths',
    'Enter-ProjectDirectory',
    'Get-RecentHistory',
    'Clear-Cache',
    'pkill',
    'pgrep',
    'Stop-ProcessForce',
    'sysinfo',
    'flushdns',
    'which',
    'export',
    'uptime',
    'ConvertFrom-DotEnvLine',
    'Use-Env',
    'gdev',
    'gmain',
    'gup',
    'gsave',
    'kcinfo',
    'gsw',
    'ConvertTo-HumanReadableSize',
    'Get-FileSize',
    'Publish-FileShare',
    'Watch-File',
    'New-EmptyFile',
    'Find-File',
    'Expand-ZipFile',
    'Get-FileHead',
    'Get-FileTail',
    'Enter-NewDirectory',
    'Remove-ToRecycleBin',
    'Set-ClipboardText',
    'Get-ClipboardText',
    'Publish-Hastebin',
    'Find-Text',
    'Get-VolumeUsage',
    'Update-FileText',
    'Set-LocationParent',
    'Set-LocationParentTwoLevels',
    'Set-LocationHome',
    'Invoke-Eza',
    'Invoke-EzaLs',
    'Remove-MergedGitBranches',
    'Switch-GitBranch',
    'Get-RepoSize',
    'Format-FileSize',
    'Get-BranchStatus',
    'Optimize-GitRepository',
    'Get-GitRepositoriesSummary',
    'Invoke-AiCommit',
    'Import-RequiredModules',
    'Select-KubeContext',
    'Select-KubeNamespace',
    'Get-PubIP',
    'Initialize-Completion'
)

$script:PwshProfilePublicAliases = @(
    'aicommit',
    'ask',
    'cna',
    'cpy',
    'df',
    'ff',
    'gclean',
    'gg',
    'gitStandup',
    'grep',
    'hb',
    'head',
    'k',
    'k9',
    'kctx',
    'kubectx',
    'kubens',
    'lacr',
    'lss',
    'mkcd',
    'nf',
    'p',
    'project',
    'pst',
    'sas',
    'sed',
    'sf',
    'tail',
    'touch',
    'trash',
    'unzip',
    'wf',
    '..',
    '...',
    '~'
)

if (-not (Test-Path -LiteralPath $functionsPath)) {
    Write-Verbose "Functions directory not found at: $functionsPath"
    return
}

Get-ChildItem -LiteralPath $functionsPath -Filter *.ps1 | Sort-Object Name | ForEach-Object {
    $functionScript = $_
    try {
        . $functionScript.FullName
    }
    catch {
        Write-Warning "Failed to load function script '$($functionScript.FullName)': $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function $script:PwshProfilePublicFunctions -Alias $script:PwshProfilePublicAliases
