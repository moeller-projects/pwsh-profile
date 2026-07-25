. (Join-Path (Split-Path $PSScriptRoot -Parent) 'functions/git-functions.ps1')
Export-ModuleMember -Function Remove-MergedGitBranches, Switch-GitBranch, Get-RepoSize, Get-BranchStatus, Optimize-GitRepository, Get-GitRepositoriesSummary, Invoke-AiCommit -Alias gclean, gg, gitStandup, aicommit
