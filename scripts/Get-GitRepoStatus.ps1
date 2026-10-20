#Requires -Version 7.0
<#
.SYNOPSIS
    Recursively finds git repositories and reports uncommitted changes, unpushed
    commits, stashes and stale worktrees. Optionally prunes stale worktrees and
    deletes local branches that are fully pushed.

.PARAMETER Root
    Directory to scan (default: current directory).

.PARAMETER MaxDepth
    Maximum folder depth to descend while searching (default: 8).

.PARAMETER Exclude
    Folder names that are never descended into (node_modules etc.).

.PARAMETER Fetch
    Run `git fetch --all --prune` per repo first, so ahead/behind reflects
    fresh remote state. Slower, needs network.

.PARAMETER PruneWorktrees
    Run `git worktree prune`. Without it, stale worktrees are only reported.

.PARAMETER PruneBranches
    Delete local branches whose commits are ALL contained in a remote branch
    (i.e. nothing would be lost). Implies a fetch; a repo whose fetch fails is
    skipped. Never touches the current branch, branches checked out in any
    worktree, or branches listed in -Protect. Combine with -WhatIf to preview.

.PARAMETER Protect
    Branch names never deleted by -PruneBranches (the repo's default branch is
    always protected too).

.PARAMETER All
    Also list clean repos in the table (default: only repos needing attention).

.PARAMETER PassThru
    Emit result objects to the pipeline (e.g. for Export-Csv / ConvertTo-Json).

.EXAMPLE
    ./Get-GitRepoStatus.ps1 ~/src
    ./Get-GitRepoStatus.ps1 ~/src -Fetch -All
    ./Get-GitRepoStatus.ps1 ~/src -PruneBranches -WhatIf   # preview
    ./Get-GitRepoStatus.ps1 ~/src -PruneBranches -PruneWorktrees
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Root = '.',
    [int]$MaxDepth = 8,
    [string[]]$Exclude = @('node_modules', '.venv', 'venv', 'vendor', 'bin', 'obj', 'dist',
        'target', '.cache', '.terraform', '__pycache__', '.nuget', '.bun'),
    [switch]$Fetch,
    [switch]$PruneWorktrees,
    [switch]$PruneBranches,
    [string[]]$Protect = @('main', 'master', 'develop', 'dev', 'SystemService'),
    [switch]$All,
    [switch]$PassThru
)

$ErrorActionPreference = 'Continue'   # native stderr must never become a terminating error
$env:GIT_OPTIONAL_LOCKS = '0'         # status must not touch/lock the index
$env:GIT_TERMINAL_PROMPT = '0'        # never hang on credential prompts while fetching

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git not found in PATH.' }
$rootFull = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).ProviderPath

# ---------------------------------------------------------------- discovery
function Find-GitRepo {
    param([string]$Dir, [int]$Depth)

    $gitPath = Join-Path $Dir '.git'
    if (Test-Path -LiteralPath $gitPath) {
        $isLinkedWorktree = $false
        if (Test-Path -LiteralPath $gitPath -PathType Leaf) {
            # ".git" file: linked worktree (skip, reported via main repo) or submodule (keep)
            $content = Get-Content -LiteralPath $gitPath -Raw -ErrorAction SilentlyContinue
            if ($content -match 'gitdir:\s*.*[/\\]worktrees[/\\]') { $isLinkedWorktree = $true }
        }
        if (-not $isLinkedWorktree) { $Dir }
    }

    if ($Depth -ge $MaxDepth) { return }
    foreach ($sub in Get-ChildItem -LiteralPath $Dir -Directory -Force -ErrorAction SilentlyContinue) {
        if ($sub.Name -eq '.git' -or $sub.Name -in $Exclude) { continue }
        if ($sub.LinkType) { continue }   # skip symlinks / junctions (avoid loops)
        Find-GitRepo -Dir $sub.FullName -Depth ($Depth + 1)
    }
}

# ------------------------------------------------------------ per-repo scan
function Get-DefaultBranchName {
    param([string]$Path)
    $head = & git -C $Path symbolic-ref --short refs/remotes/origin/HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $head) { return ($head -replace '^origin/', '') }
    foreach ($c in 'main', 'master') {
        & git -C $Path show-ref --verify --quiet "refs/remotes/origin/$c" 2>$null
        if ($LASTEXITCODE -eq 0) { return $c }
    }
    return $null
}

function Get-RepoReport {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Path)

    # --- fetch (required for safe branch pruning: stale remote refs could lie)
    $fetchError = $null
    if ($Fetch -or $PruneBranches) {
        $out = & git -C $Path fetch --all --prune --quiet 2>&1
        if ($LASTEXITCODE -ne 0) { $fetchError = ($out | Out-String).Trim() }
    }

    # --- working tree + current branch (ahead/behind of current branch)
    $branch = ''; $upstream = ''; $ahead = 0; $behind = 0
    $changed = 0; $untracked = 0; $conflicts = 0
    foreach ($l in (& git -C $Path status --porcelain=v2 --branch 2>$null)) {
        switch -Regex ($l) {
            '^# branch\.head (.+)$'           { $branch = $Matches[1] }
            '^# branch\.upstream (.+)$'       { $upstream = $Matches[1] }
            '^# branch\.ab \+(\d+) -(\d+)$'   { $ahead = [int]$Matches[1]; $behind = [int]$Matches[2] }
            '^[12] '                          { $changed++ }
            '^u '                             { $conflicts++ }
            '^\? '                            { $untracked++ }
        }
    }

    # --- stashes
    $stashes = @(& git -C $Path stash list 2>$null).Count

    # --- stale worktrees (dry run first, real prune only on request)
    $stale = @(& git -C $Path worktree prune --dry-run -v 2>&1 | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    $wtPruned = $false
    if ($PruneWorktrees -and $stale.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess($Path, 'git worktree prune')) {
            & git -C $Path worktree prune 2>&1 | Out-Null
            $wtPruned = ($LASTEXITCODE -eq 0)
        }
    }
    # list AFTER pruning so dead worktrees no longer block their branches
    $wtLines = @(& git -C $Path worktree list --porcelain 2>$null)
    $extraWorktrees = [Math]::Max(0, @($wtLines | Where-Object { $_ -like 'worktree *' }).Count - 1)
    $checkedOut = @($wtLines | Where-Object { $_ -like 'branch refs/heads/*' } |
        ForEach-Object { $_ -replace '^branch refs/heads/', '' })

    # --- delete fully pushed local branches
    $prunedBranches = [System.Collections.Generic.List[string]]::new()
    $wouldPrune = [System.Collections.Generic.List[string]]::new()
    if ($PruneBranches -and -not $fetchError) {
        $protected = @($Protect)
        $defaultName = Get-DefaultBranchName -Path $Path
        if ($defaultName) { $protected += $defaultName }

        foreach ($b in (& git -C $Path for-each-ref --format='%(refname:short)' refs/heads 2>$null)) {
            if ($b -eq $branch -or $b -in $protected -or $b -in $checkedOut) { continue }
            # commits of $b that are not contained in ANY remote branch
            $n = & git -C $Path rev-list --count "refs/heads/$b" --not --remotes 2>$null
            if ($LASTEXITCODE -ne 0 -or [int]$n -ne 0) { continue }
            if ($PSCmdlet.ShouldProcess("$Path [$b]", 'git branch -D')) {
                & git -C $Path branch -D $b 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) { $prunedBranches.Add($b) }
            }
            else { $wouldPrune.Add($b) }
        }
    }

    # --- all remaining local branches: unpushed / never pushed / upstream gone
    $unpushed = [System.Collections.Generic.List[string]]::new()
    $fmt = '%(refname:short)%09%(upstream:short)%09%(upstream:track)'
    foreach ($r in (& git -C $Path for-each-ref --format=$fmt refs/heads 2>$null)) {
        $name, $up, $track = $r -split "`t"
        if (-not $up) {
            $n = & git -C $Path rev-list --count "refs/heads/$name" --not --remotes 2>$null
            if ([int]$n -gt 0) { $unpushed.Add("$name ($n commits, no upstream)") }
        }
        elseif ($track -match 'gone') {
            # remote branch was deleted (usually after a PR merge): only a problem if
            # its commits are not contained in any other remote branch
            $n = & git -C $Path rev-list --count "refs/heads/$name" --not --remotes 2>$null
            if ([int]$n -gt 0) { $unpushed.Add("$name (upstream gone, $n commits on no remote)") }
        }
        elseif ($track -match 'ahead (\d+)') {
            $unpushed.Add("$name (ahead $($Matches[1]))")
        }
    }

    $dirty = ($changed + $untracked + $conflicts) -gt 0
    [pscustomobject]@{
        Repo             = [IO.Path]::GetRelativePath($rootFull, $Path)
        Path             = $Path
        Branch           = $branch
        Upstream         = $upstream
        Dirty            = $dirty
        Changed          = $changed
        Untracked        = $untracked
        Conflicts        = $conflicts
        Ahead            = $ahead
        Behind           = $behind
        UnpushedBranches = @($unpushed)
        PrunedBranches   = @($prunedBranches)
        WouldPruneBranches = @($wouldPrune)
        Stashes          = $stashes
        ExtraWorktrees   = $extraWorktrees
        StaleWorktrees   = $stale
        WorktreesPruned  = $wtPruned
        FetchError       = $fetchError
        NeedsAttention   = ($dirty -or $unpushed.Count -gt 0 -or $prunedBranches.Count -gt 0 -or
                            $wouldPrune.Count -gt 0 -or $stashes -gt 0 -or $stale.Count -gt 0 -or $behind -gt 0 -or [bool]$fetchError)
    }
}

# --------------------------------------------------------------------- main
Write-Host "Scanning $rootFull ..." -ForegroundColor DarkGray
$repos = @(Find-GitRepo -Dir $rootFull -Depth 0 | Sort-Object -Unique)
Write-Host "Found $($repos.Count) repositories." -ForegroundColor DarkGray

$results = [System.Collections.Generic.List[object]]::new()
$i = 0
foreach ($repo in $repos) {
    $i++
    Write-Progress -Activity 'Checking repositories' -Status $repo -PercentComplete (($i / [Math]::Max(1, $repos.Count)) * 100)
    try { $results.Add((Get-RepoReport -Path $repo)) }
    catch { Write-Warning "Failed on ${repo}: $($_.Exception.Message)" }
}
Write-Progress -Activity 'Checking repositories' -Completed

$shown = @(if ($All) { $results } else { $results | Where-Object NeedsAttention })

if ($shown.Count -gt 0) {
    $shown | Sort-Object Repo | Format-Table -AutoSize @(
        @{ n = 'Repo';     e = { $_.Repo } }
        @{ n = 'Branch';   e = { $_.Branch } }
        @{ n = 'Dirty';    e = { if ($_.Dirty) { "$($_.Changed)M/$($_.Untracked)?" + $(if ($_.Conflicts) { "/$($_.Conflicts)!" }) } else { '-' } } }
        @{ n = 'Ahead';    e = { $_.Ahead } }
        @{ n = 'Behind';   e = { $_.Behind } }
        @{ n = 'Unpushed'; e = { $_.UnpushedBranches.Count } }
        @{ n = 'Pruned';   e = { $_.PrunedBranches.Count + $_.WouldPruneBranches.Count } }
        @{ n = 'Stash';    e = { $_.Stashes } }
        @{ n = 'WT';       e = { $_.ExtraWorktrees } }
        @{ n = 'StaleWT';  e = { $_.StaleWorktrees.Count } }
    ) | Out-Host

    foreach ($r in ($shown | Where-Object NeedsAttention | Sort-Object Repo)) {
        Write-Host $r.Repo -ForegroundColor Cyan
        if ($r.Dirty) {
            Write-Host "  uncommitted : $($r.Changed) changed, $($r.Untracked) untracked, $($r.Conflicts) conflicted" -ForegroundColor Yellow
        }
        if ($r.Behind -gt 0) { Write-Host "  behind      : $($r.Branch) is $($r.Behind) behind $($r.Upstream)" -ForegroundColor Yellow }
        foreach ($b in $r.UnpushedBranches) { Write-Host "  unpushed    : $b" -ForegroundColor Red }
        foreach ($b in $r.PrunedBranches)      { Write-Host "  branch      : deleted (fully pushed) - $b" -ForegroundColor Green }
        foreach ($b in $r.WouldPruneBranches)  { Write-Host "  branch      : would delete (fully pushed) - $b" -ForegroundColor DarkGreen }
        if ($r.Stashes -gt 0) { Write-Host "  stashes     : $($r.Stashes)" -ForegroundColor DarkYellow }
        foreach ($w in $r.StaleWorktrees) {
            $label = if ($r.WorktreesPruned) { 'pruned' } else { 'prunable' }
            Write-Host "  worktree    : $label - $w" -ForegroundColor DarkCyan
        }
        if ($r.FetchError) { Write-Host "  fetch failed: $($r.FetchError)" -ForegroundColor Red }
    }
}

$attention = @($results | Where-Object NeedsAttention).Count
Write-Host ''
Write-Host ("{0} repos, {1} need attention, {2} clean." -f $results.Count, $attention, ($results.Count - $attention)) -ForegroundColor Green
if (-not $PruneWorktrees -and ($results | Where-Object { $_.StaleWorktrees.Count })) {
    Write-Host 'Stale worktrees found. Re-run with -PruneWorktrees to remove them.' -ForegroundColor DarkGray
}

if ($PassThru) { $results }
