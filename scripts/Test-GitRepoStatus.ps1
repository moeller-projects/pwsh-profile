# Focused integration checks for clean linked-worktree pruning.
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'Get-GitRepoStatus.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("git-repo-status-" + [guid]::NewGuid())
$repoPath = Join-Path $tempRoot 'repo'
$remotePath = Join-Path $tempRoot 'remote.git'
$worktreePath = Join-Path $tempRoot 'feature'
$unpublishedPath = Join-Path $tempRoot 'unpublished'
$dirtyPath = Join-Path $tempRoot 'dirty'

function Test-SamePath {
    param([string]$Left, [string]$Right)
    ([System.IO.Path]::GetFullPath($Left).Replace('/', '\\')) -eq ([System.IO.Path]::GetFullPath($Right).Replace('/', '\\'))
}

function Invoke-Git {
    param([string[]]$GitArguments)
    & git @GitArguments
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArguments -join ' ') failed" }
}

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    Invoke-Git @('init', '--bare', $remotePath)
    Invoke-Git @('init', '-b', 'main', $repoPath)
    Invoke-Git @('-C', $repoPath, 'config', 'user.name', 'Test')
    Invoke-Git @('-C', $repoPath, 'config', 'user.email', 'test@example.invalid')
    'base' | Set-Content -LiteralPath (Join-Path $repoPath 'file.txt')
    Invoke-Git @('-C', $repoPath, 'add', 'file.txt')
    Invoke-Git @('-C', $repoPath, 'commit', '-m', 'base')
    Invoke-Git @('-C', $repoPath, 'remote', 'add', 'origin', $remotePath)
    Invoke-Git @('-C', $repoPath, 'push', '-u', 'origin', 'main')
    Invoke-Git @('-C', $repoPath, 'worktree', 'add', '-b', 'feature', $worktreePath, 'main')
    Invoke-Git @('-C', $worktreePath, 'push', '-u', 'origin', 'feature')
    Invoke-Git @('-C', $repoPath, 'worktree', 'add', '-b', 'unpublished', $unpublishedPath, 'main')
    'local only' | Set-Content -LiteralPath (Join-Path $unpublishedPath 'local.txt')
    Invoke-Git @('-C', $unpublishedPath, 'add', 'local.txt')
    Invoke-Git @('-C', $unpublishedPath, 'commit', '-m', 'unpublished')
    Invoke-Git @('-C', $repoPath, 'worktree', 'add', '-b', 'dirty', $dirtyPath, 'main')
    'untracked' | Set-Content -LiteralPath (Join-Path $dirtyPath 'untracked.txt')

    $scan = @(& $scriptPath -Root $repoPath -All -PassThru)
    if (-not (Test-Path -LiteralPath $worktreePath)) { throw 'Worktree was removed without -PruneWorktrees.' }

    $preview = @(& $scriptPath -Root $repoPath -PruneWorktrees -WhatIf -All -PassThru)
    if (-not (Test-Path -LiteralPath $worktreePath)) { throw 'WhatIf removed the live worktree.' }
    if (@($preview | Where-Object { @($_.WouldPruneWorktrees | Where-Object { Test-SamePath $_ $worktreePath }).Count -gt 0 }).Count -ne 1) {
        throw 'WhatIf did not report the eligible worktree.'
    }
    if (-not (Test-Path -LiteralPath $unpublishedPath)) { throw 'WhatIf removed an unpublished worktree.' }
    if (-not (Test-Path -LiteralPath $dirtyPath)) { throw 'WhatIf removed a dirty worktree.' }

    $removed = @(& $scriptPath -Root $repoPath -PruneWorktrees -All -PassThru)
    if (Test-Path -LiteralPath $worktreePath) { throw 'Eligible worktree was not removed.' }
    if (@($removed | Where-Object { @($_.PrunedWorktrees | Where-Object { Test-SamePath $_ $worktreePath }).Count -gt 0 }).Count -ne 1) {
        throw 'Removal was not reported.'
    }
    if (-not (Test-Path -LiteralPath $unpublishedPath)) { throw 'Unpublished worktree was removed.' }
    if (-not (Test-Path -LiteralPath $dirtyPath)) { throw 'Dirty worktree was removed.' }
    Write-Host 'GitRepoStatus worktree checks passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
