@{
    RootModule = 'PwshProfile.Git.psm1'
    ModuleVersion = '1.0.0'
    FunctionsToExport = @('Remove-MergedGitBranches', 'Switch-GitBranch', 'Get-RepoSize', 'Format-FileSize', 'Get-BranchStatus', 'Optimize-GitRepository', 'Get-GitRepositoriesSummary', 'Invoke-AiCommit')
    AliasesToExport = @('gclean', 'gg', 'gitStandup', 'aicommit')
}
