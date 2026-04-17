@{
    RootModule = 'PwshProfile.psm1'
    ModuleVersion = '0.2.0'
    CompatiblePSEditions = @('Desktop', 'Core')
    GUID = 'b9d2db05-3a1b-4c0c-9b7d-0f7c2a9df0db'
    Author = 'moeller-projects'
    CompanyName = 'moeller-projects'
    Copyright = '(c) moeller-projects. All rights reserved.'
    Description = 'Convenience commands and profile helpers extracted from the pwsh-profile repository.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
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
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @(
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
    PrivateData = @{
        PSData = @{
            Tags = @('powershell', 'profile', 'cli', 'module')
            ProjectUri = 'https://github.com/moeller-projects/pwsh-profile'
            LicenseUri = 'https://github.com/moeller-projects/pwsh-profile/blob/main/LICENSE'
            ReleaseNotes = 'Hardening, test coverage, packaging metadata, and publishing workflow improvements.'
        }
    }
}
