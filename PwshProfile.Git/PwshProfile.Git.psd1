@{
    GUID              = '0b22cce7-2f13-4e90-b292-8e165d33c3f7'
    Author            = 'moeller-projects'
    CompanyName       = 'moeller-projects'
    Description       = 'Git helpers and repository management for pwsh-profile'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RootModule = 'PwshProfile.Git.psm1'
    ModuleVersion = '1.1.0'
    FunctionsToExport = @('Remove-MergedGitBranches', 'Switch-GitBranch', 'Get-RepoSize', 'Get-BranchStatus', 'Optimize-GitRepository', 'Get-GitRepositoriesSummary', 'Invoke-AiCommit')
    AliasesToExport = @('gclean', 'gg', 'gitStandup', 'aicommit')
}
