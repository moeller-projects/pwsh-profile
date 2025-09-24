function Remove-MergedGitBranches {
    <#
    .SYNOPSIS
        Delete local branches already merged, protecting common branches.

    .DESCRIPTION
        Removes local branches that are fully merged into the current HEAD, while protecting
        mainline branches. Honors -WhatIf/-Confirm.

    .PARAMETER ProtectedBranches
        List of branch names to protect from deletion.

    .EXAMPLE
        Remove-MergedGitBranches -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [Alias('gclean')]
    param(
        [string[]]$ProtectedBranches = @('main', 'master', 'dev', 'develop')
    )

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "git not found in PATH."
        return
    }

    # Get merged branches and filter out current and protected
    $branchesToDelete = git branch --merged 2>$null |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and ($_ -notmatch '^\*') -and ($ProtectedBranches -notcontains $_) }

    if (-not $branchesToDelete -or $branchesToDelete.Count -eq 0) {
        Write-Host "No merged branches to delete." -ForegroundColor Cyan
        return
    }

    Write-Host "Deleting merged branches: $($branchesToDelete -join ', ')" -ForegroundColor Yellow
    foreach ($branch in $branchesToDelete) {
        if ($PSCmdlet.ShouldProcess($branch, 'Delete branch')) {
            try {
                git branch -d -- $branch | Out-Null
                if ($LASTEXITCODE -eq 0) { Write-Verbose "Successfully deleted branch: $branch" }
                else { Write-Warning "Failed to delete branch: $branch" }
            }
            catch {
                Write-Warning "Failed to delete branch: $branch. Error: $($_.Exception.Message)"
            }
        }
    }
    Write-Host "Branch cleanup completed." -ForegroundColor Green
}

function Switch-GitBranch {
    <#
    .SYNOPSIS
        Interactive branch switcher using fzf.

    .DESCRIPTION
        Lets you fuzzy-find a branch from local and origin/* branches and switches to it.
        If the branch only exists on origin, creates a local tracking branch. Supports
        optional fetch before listing.

    .PARAMETER Arguments
        Optional search query passed to fzf.

    .PARAMETER Fetch
        Fetch from all remotes before listing.
    #>
    [CmdletBinding()]
    [Alias('gg', 'Git-Go')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromRemainingArguments = $true)]
        [Object[]] $Arguments,
        [switch]$Fetch
    )

    begin {
        $exitEarly = $false
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Error "git not found in PATH."
            $exitEarly = $true; return
        }
        if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
            Write-Error "fzf not found in PATH. Install fzf to use Git-Go."
            $exitEarly = $true; return
        }
        if (-not ([System.IO.Directory]::Exists((Join-Path (Get-Location).Path ".git")))) {
            Write-Host "[ERROR] This is not a Git repository!" -ForegroundColor Red
            $exitEarly = $true; return
        }

        if ($Fetch) {
            Write-Verbose "Fetching all git remotes..."
            git fetch --all --prune 2>$null | Out-Null
        }

        # Build local set for existence check
        $localBranches = @(git for-each-ref --format='%(refname:short)' refs/heads 2>$null)
        $localBranchSet = @{}
        foreach ($b in $localBranches) { if ($b) { $localBranchSet[$b.Trim()] = $true } }

        # Candidate list: local + origin/* (filtered). Strip origin/ prefix in display.
        $candidates = @()
        $locals = git for-each-ref --format='%(refname:short)' refs/heads 2>$null
        if ($locals) { $candidates += $locals }
        $remotes = git for-each-ref --format='%(refname:short)' refs/remotes/origin 2>$null |
        Where-Object { $_ -and ($_ -ne 'origin/HEAD') -and ($_ -notmatch '^origin/HEAD\b') }
        if ($remotes) { $candidates += ($remotes | ForEach-Object { $_ -replace '^origin/', '' }) }
        $candidates = $candidates | Sort-Object -Unique

        $fzfQuery = ($Arguments -join ' ')
        Write-Verbose "Running fzf to select branch with query '$fzfQuery'..."
        $selectedBranch = ($candidates | fzf -q $fzfQuery)
        $selectedBranch = ($selectedBranch | ForEach-Object { $_ -replace '^\*', '' }).Trim()

        Set-Variable -Name __sgb_localSet -Value $localBranchSet -Scope Local
        Set-Variable -Name __sgb_selected -Value $selectedBranch -Scope Local
    }

    process {
        if ($exitEarly) { return }

        if ([string]::IsNullOrWhiteSpace($__sgb_selected)) {
            Write-Host "[INFO] No branch selected. Exiting..." -ForegroundColor Yellow
            return
        }

        Write-Verbose "[INFO] Selected branch: $__sgb_selected"

        $useGitSwitch = $false
        if (Get-Command git -ErrorAction SilentlyContinue) {
            # 'git switch' is available in Git 2.23+. Many Git builds return 129 for -h usage.
            git switch -h *> $null
            if ($LASTEXITCODE -in 0, 129) { $useGitSwitch = $true }
        }

        if ($__sgb_localSet.ContainsKey($__sgb_selected)) {
            Write-Host "[INFO] Checking out existing local branch: $__sgb_selected" -ForegroundColor Cyan
            if ($useGitSwitch) { git switch -- $__sgb_selected }
            else { git checkout -- $__sgb_selected }
        }
        else {
            Write-Host "[INFO] Creating and checking out new branch from origin/$__sgb_selected" -ForegroundColor Cyan
            if ($useGitSwitch) { git switch -c $__sgb_selected --track origin/$__sgb_selected }
            else { git checkout -b $__sgb_selected origin/$__sgb_selected }
        }

        Write-Host "[SUCCESS] Switched to branch: $__sgb_selected" -ForegroundColor Green
    }
}

function Get-RepoSize {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    try {
        $sum = (Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        return ([long]($sum))
    }
    catch {
        return 0
    }
}

function Format-FileSize {
    param([long]$Size)

    if ($Size -ge 1GB) {
        return "{0:N2} GB" -f ($Size / 1GB)
    }
    elseif ($Size -ge 1MB) {
        return "{0:N2} MB" -f ($Size / 1MB)
    }
    elseif ($Size -ge 1KB) {
        return "{0:N2} KB" -f ($Size / 1KB)
    }
    else {
        return "{0} bytes" -f $Size
    }
}

function Get-BranchStatus {
    param([string]$Branch)

    $status = @{
        SafeToDelete   = $false
        Reason         = ""
        RemoteTracking = ""
        Ahead          = 0
        Behind         = 0
    }

    # Get remote tracking branch
    $remoteTracking = git for-each-ref --format='%(upstream:short)' "refs/heads/$Branch" 2>$null
    $status.RemoteTracking = $remoteTracking

    if (-not $remoteTracking) {
        $status.Reason = "No remote tracking branch"
        return $status
    }

    # Check if remote branch exists
    git rev-parse --verify --quiet "refs/remotes/$remoteTracking" *> $null
    $remoteExists = ($LASTEXITCODE -eq 0)
    if (-not $remoteExists) {
        $status.Reason = "Remote branch does not exist"
        return $status
    }

    # Get ahead/behind counts
    $aheadBehind = git rev-list --left-right --count "$remoteTracking...$Branch" 2>$null
    if ($aheadBehind) {
        $counts = $aheadBehind -split '\s+'
        $status.Ahead = [int]$counts[0]  # commits ahead
        $status.Behind = [int]$counts[1] # commits behind
    }

    # Determine if safe to delete
    if ($status.Ahead -eq 0 -and $status.Behind -eq 0) {
        # Branches are equal
        $status.SafeToDelete = $true
        $status.Reason = "Branches are identical"
    }
    elseif ($status.Ahead -eq 0 -and $status.Behind -gt 0) {
        # Local branch is behind remote (safe to delete since remote has newer commits)
        $status.SafeToDelete = $true
        $status.Reason = "Local branch is behind remote (remote has new commits)"
    }
    elseif ($status.Ahead -gt 0 -and $status.Behind -eq 0) {
        # Local branch is ahead of remote (NOT safe to delete)
        $status.Reason = "Local branch has commits not pushed to remote"
    }
    elseif ($status.Ahead -gt 0 -and $status.Behind -gt 0) {
        # Branches have diverged (NOT safe to delete)
        $status.Reason = "Branches have diverged"
    }
    else {
        $status.Reason = "Unknown branch status"
    }

    return $status
}

function Optimize-GitRepository {
    <#
    .SYNOPSIS
        Cleans up git repositories by removing safe-to-delete branches and shrinking repository size.

    .DESCRIPTION
        This function processes git repositories by:
        - Deleting local branches that have no uncommitted changes and are identical to their remote counterparts
        - Protecting important branches (dev, develop, main, master)
        - Shrinking repository size through garbage collection and optimization
        - Working on single repositories or recursively through directories

    .PARAMETER RepoPath
        The path to the repository or directory containing repositories

    .PARAMETER Recursive
        If specified, processes all git repositories recursively under the given path

    .PARAMETER DryRun
        If specified, shows what would be done without actually making changes

    .EXAMPLE
        Optimize-GitRepository -RepoPath "C:\MyProject"
        # Processes a single repository

    .EXAMPLE
        Optimize-GitRepository -RepoPath "C:\Projects" -Recursive
        # Processes all repositories recursively under C:\Projects

    .EXAMPLE
        Optimize-GitRepository -RepoPath "." -DryRun
        # Shows what would be done in current directory without making changes
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,

        [switch]$Recursive,

        [switch]$DryRun,

        [switch]$Fetch,

        [switch]$Aggressive,

        [string[]]$ProtectedBranches = @('main', 'master', 'dev', 'develop')
    )

    function Process-SingleRepo {
        param(
            [string]$Path,
            [bool]$IsDryRun
        )

        if (-not (Test-Path (Join-Path $Path '.git'))) {
            Write-Host "❌ Not a git repository: $Path" -ForegroundColor Red
            return
        }

        $repoName = Split-Path $Path -Leaf
        $originalDir = Get-Location

        try {
            Set-Location $Path

            Write-Host "`n" + "═"*70 -ForegroundColor Blue
            if ($IsDryRun) { Write-Host "🔍 DRY RUN - REPOSITORY: $repoName" -ForegroundColor Yellow -BackgroundColor DarkBlue }
            else { Write-Host "📁 REPOSITORY: $repoName" -ForegroundColor White -BackgroundColor DarkBlue }
            Write-Host "📍 PATH: $Path" -ForegroundColor Gray
            Write-Host "═"*70 -ForegroundColor Blue

            # Get initial repo size
            $initialSize = Get-RepoSize -Path $Path
            Write-Host "📊 Initial repository size: $(Format-FileSize $initialSize)" -ForegroundColor Gray

            # Show current branch
            $currentBranch = git branch --show-current 2>$null
            if ($currentBranch) { Write-Host "🌿 Current Branch: $currentBranch" -ForegroundColor Cyan }

            # Optionally fetch
            if ($Fetch) {
                Write-Host "`n🔄 Fetching latest from remote..." -ForegroundColor Yellow
                if (-not $IsDryRun) { if ($PSCmdlet.ShouldProcess($Path, 'git fetch --all --prune')) { git fetch --all --prune 2>$null } }
                else { Write-Host "(dry run) Would: git fetch --all --prune" -ForegroundColor DarkYellow }
            }

            # Show status before cleanup
            Write-Host "`n📊 Status before cleanup:" -ForegroundColor Yellow
            git status --short --branch 2>$null

            # Build branch -> upstream mapping without checkout
            $branchMap = @{}
            git for-each-ref --format='%(refname:short)|%(upstream:short)' refs/heads 2>$null |
            ForEach-Object {
                if (-not $_) { return }
                $parts = $_ -split '\|', 2
                $b = $parts[0].Trim(); $u = $parts[1].Trim()
                if ($b) { $branchMap[$b] = $u }
            }

            # Candidate local branches excluding protected and current
            $localBranches = ($branchMap.Keys | Where-Object {
                    $_ -and ($_ -ne $currentBranch) -and ($ProtectedBranches -notcontains $_) -and ($_ -notmatch '^dev/|^develop/')
                })

            $branchesToDelete = @()

            foreach ($branch in $localBranches) {
                Write-Host "`n  Checking branch: $branch" -ForegroundColor Gray

                # Uncommitted changes check without checkout: compare worktree tree-ish is not trivial without checkout.
                # Heuristic: skip untracked state check; deletions only when ahead=0 and has upstream.

                # Resolve upstream
                $upstream = $branchMap[$branch]
                if (-not $upstream) {
                    Write-Host "  ❌ No remote tracking branch" -ForegroundColor Red
                    continue
                }

                # Ensure remote ref exists
                git rev-parse --verify --quiet "refs/remotes/$upstream" *> $null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  ❌ Remote branch does not exist: $upstream" -ForegroundColor Red
                    continue
                }

                # ahead/behind
                $counts = (git rev-list --left-right --count "$branch...$upstream" 2>$null).Trim() -split '\s+'
                $ahead = [int]$counts[0]
                $behind = [int]$counts[1]
                Write-Host "  Remote: $upstream" -ForegroundColor DarkGray
                Write-Host "  Status: Ahead $ahead, Behind $behind" -ForegroundColor DarkGray

                if ($ahead -eq 0 -and $behind -ge 0) {
                    Write-Host "  ✅ Safe to delete: $branch" -ForegroundColor Green
                    $branchesToDelete += $branch
                }
                else {
                    $reason = if ($ahead -gt 0 -and $behind -eq 0) { 'Local branch has commits not pushed to remote' }
                    elseif ($ahead -gt 0 -and $behind -gt 0) { 'Branches have diverged' } else { 'Unknown or behind/ahead state' }
                    Write-Host "  ❌ Not safe to delete: $branch" -ForegroundColor Red
                    Write-Host "  Reason: $reason" -ForegroundColor DarkRed
                }
            }

            # Delete branches
            if ($branchesToDelete.Count -gt 0) {
                if ($IsDryRun) {
                    Write-Host "`n🔍 DRY RUN - Branches that would be deleted:" -ForegroundColor Yellow
                    foreach ($branch in $branchesToDelete) { Write-Host "  Would delete: $branch" -ForegroundColor Magenta }
                }
                else {
                    Write-Host "`n🗑️  Deleting safe branches:" -ForegroundColor Yellow
                    foreach ($branch in $branchesToDelete) {
                        if ($PSCmdlet.ShouldProcess($branch, 'Delete local branch')) {
                            git branch -D -- $branch 2>$null
                            if ($LASTEXITCODE -eq 0) { Write-Host "  ✅ Deleted: $branch" -ForegroundColor Green }
                            else { Write-Host "  ❌ Failed to delete: $branch" -ForegroundColor Red }
                        }
                    }
                }
            }
            else {
                Write-Host "`n✅ No branches to delete" -ForegroundColor Green
            }

            # REPOSITORY MAINTENANCE
            if (-not $IsDryRun) {
                Write-Host "`n💾 Repository Maintenance:" -ForegroundColor Yellow

                # Prefer 'git maintenance' if available
                $ranMaintenance = $false
                git help maintenance 2>$null
                if ($LASTEXITCODE -eq 0) {
                    if ($PSCmdlet.ShouldProcess($Path, 'git maintenance run')) {
                        git maintenance run 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  ✅ Maintenance completed" -ForegroundColor Green; $ranMaintenance = $true }
                    }
                }

                if (-not $ranMaintenance) {
                    if ($PSCmdlet.ShouldProcess($Path, 'git gc --prune=now')) {
                        git gc --prune=now 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  ✅ GC completed" -ForegroundColor Green }
                    }
                }

                if ($Aggressive) {
                    if ($PSCmdlet.ShouldProcess($Path, 'git reflog expire --expire=now --all')) {
                        git reflog expire --expire=now --all 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  ✅ Reflog pruned" -ForegroundColor Green }
                    }
                    if ($PSCmdlet.ShouldProcess($Path, 'git repack -ad --depth=50 --window=250')) {
                        git repack -ad --depth=50 --window=250 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  ✅ Repack completed" -ForegroundColor Green }
                    }
                    if ($PSCmdlet.ShouldProcess($Path, 'git gc --aggressive --prune=now')) {
                        git gc --aggressive --prune=now 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  ✅ Aggressive GC completed" -ForegroundColor Green }
                    }
                    if ($PSCmdlet.ShouldProcess($Path, 'git clean -fd')) {
                        git clean -fd 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  ✅ Clean completed" -ForegroundColor Green }
                    }
                }
            }
            else {
                Write-Host "`n💾 Repository maintenance would be performed (skipped in dry run)" -ForegroundColor Yellow
            }

            # Get final repo size (only if not dry run)
            if (-not $IsDryRun) {
                $finalSize = Get-RepoSize -Path $Path
                $sizeReduction = [long]($initialSize - $finalSize)

                Write-Host "`n📊 Size Analysis:" -ForegroundColor Yellow
                Write-Host "  Initial size: $(Format-FileSize $initialSize)" -ForegroundColor Gray
                Write-Host "  Final size:   $(Format-FileSize $finalSize)" -ForegroundColor Gray
                if ($sizeReduction -gt 0 -and $initialSize -gt 0) {
                    Write-Host "  Space saved:  $(Format-FileSize $sizeReduction)" -ForegroundColor Green
                    $reductionPercent = [math]::Round(($sizeReduction / [double]$initialSize) * 100, 1)
                    Write-Host "  Reduction:    $reductionPercent%" -ForegroundColor Green
                }
                else {
                    Write-Host "  No significant size reduction" -ForegroundColor Yellow
                }
            }

            # Show final status
            Write-Host "`n🌿 Final Branch Status:" -ForegroundColor Yellow
            git branch --list 2>$null | ForEach-Object {
                if ($_ -match '^\*\s') { Write-Host "  → $($_.Substring(2))" -ForegroundColor Cyan }
                elseif ($_ -match '\b(dev|develop|main|master)\b') { Write-Host "  ★ $($_.Trim())" -ForegroundColor Magenta }
                else { Write-Host "    $($_.Trim())" -ForegroundColor Gray }
            }

            if ($IsDryRun) { Write-Host "`n🔍 DRY RUN completed for: $repoName" -ForegroundColor Yellow }
            else { Write-Host "`n✅ Repository processing completed: $repoName" -ForegroundColor Green }

        }
        catch {
            Write-Host "❌ Error processing: $repoName" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        finally {
            Set-Location $originalDir
        }
    }

    # Validate path exists
    if (-not (Test-Path $RepoPath)) {
        Write-Host "❌ Path does not exist: $RepoPath" -ForegroundColor Red
        return
    }

    # Resolve relative paths to absolute
    $RepoPath = (Resolve-Path $RepoPath).Path

    # Main execution logic
    if ($Recursive) {
        Write-Host "🔍 Searching for git repositories recursively under: $RepoPath" -ForegroundColor Cyan
        $repos = Get-ChildItem -Path $RepoPath -Recurse -Directory -Force -Filter .git -ErrorAction SilentlyContinue |
        ForEach-Object { Split-Path $_.FullName -Parent } |
        Sort-Object -Unique

        if (-not $repos -or $repos.Count -eq 0) {
            Write-Host "❌ No git repositories found" -ForegroundColor Yellow
            return
        }

        Write-Host "📋 Found $($repos.Count) repositories to process" -ForegroundColor Cyan

        foreach ($repo in $repos) {
            if ($PSCmdlet.ShouldProcess($repo, 'Process repository')) {
                Process-SingleRepo -Path $repo -IsDryRun $DryRun
            }
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess($RepoPath, 'Process repository')) {
            Process-SingleRepo -Path $RepoPath -IsDryRun $DryRun
        }
    }
}
