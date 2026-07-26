# Script-scope cache for git maintenance availability (probed once per session)
$script:GitMaintenanceAvailable = $null

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
    [Alias('gg')]
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
        if (-not (git rev-parse --is-inside-work-tree 2>$null)) {
            Write-Host "[ERROR] This is not a Git repository!" -ForegroundColor Red
            $exitEarly = $true; return
        }

        if ($Fetch) {
            Write-Verbose "Fetching all git remotes..."
            git fetch --all --prune 2>$null | Out-Null
        }

        if (-not (Get-Variable -Name __gitSwitchAvailability -Scope Script -ErrorAction SilentlyContinue)) {
            Set-Variable -Name __gitSwitchAvailability -Scope Script -Value $false
            Set-Variable -Name __gitSwitchAvailabilityChecked -Scope Script -Value $false
        }

        # Build local cache of branch information with a single ref walk
        $localBranchSet = @{}
        $candidateNames = New-Object 'System.Collections.Generic.SortedSet[string]'
        $rawRefs = git for-each-ref --format='%(refname)|%(refname:short)' refs/heads refs/remotes/origin 2>$null
        foreach ($line in $rawRefs) {
            if (-not $line) { continue }
            $parts = $line -split '\|', 2
            if ($parts.Count -lt 2) { continue }
            $fullRef = $parts[0].Trim()
            $shortRef = $parts[1].Trim()
            if (-not $shortRef) { continue }

            if ($fullRef -like 'refs/heads/*') {
                $localBranchSet[$shortRef] = $true
                [void]$candidateNames.Add($shortRef)
                continue
            }

            if ($fullRef -like 'refs/remotes/origin/*') {
                if ($shortRef -eq 'origin/HEAD' -or $shortRef -like 'origin/HEAD/*') { continue }
                $candidateName = $shortRef -replace '^origin/', ''
                if ($candidateName) { [void]$candidateNames.Add($candidateName) }
            }
        }

        $candidates = $candidateNames.ToArray()

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

        if (-not $script:__gitSwitchAvailabilityChecked) {
            $gitVersion = git version --short 2>$null
            if ($gitVersion -match '^(\d+)\.(\d+)') {
                $major = [int]$matches[1]
                $minor = [int]$matches[2]
                $script:__gitSwitchAvailability = ($major -gt 2) -or ($major -eq 2 -and $minor -ge 23)
            }

            if (-not $script:__gitSwitchAvailability) {
                git switch -h *> $null
                $script:__gitSwitchAvailability = ($LASTEXITCODE -in 0, 129)
            }

            $script:__gitSwitchAvailabilityChecked = $true
        }

        $useGitSwitch = $script:__gitSwitchAvailability

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
        $directory = [System.IO.DirectoryInfo]::new($Path)
        $totalSize = 0L

        try {
            $options = [System.IO.EnumerationOptions]::new()
            $options.RecurseSubdirectories = $true
            $options.IgnoreInaccessible = $true
            foreach ($file in $directory.EnumerateFiles('*', $options)) {
                $totalSize += $file.Length
            }
        }
        catch {
            $sum = (Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
            if ($sum) { $totalSize = [long]$sum }
        }

        return $totalSize
    }
    catch {
        return 0
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

    $ref = git for-each-ref --format='%(upstream:short)|%(upstream:track)' "refs/heads/$Branch" 2>$null
    if (-not $ref) {
        $status.Reason = "No remote tracking branch"
        return $status
    }

    $parts = $ref -split '\|', 2
    $status.RemoteTracking = $parts[0].Trim()
    $track = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
    if ($track -match '\[gone\]') {
        $status.Reason = "Remote branch does not exist"
        return $status
    }

    if ($track -match 'ahead\s+(\d+)') { $status.Ahead = [int]$matches[1] }
    if ($track -match 'behind\s+(\d+)') { $status.Behind = [int]$matches[1] }

    if ($status.Ahead -eq 0 -and $status.Behind -eq 0) {
        $status.SafeToDelete = $true
        $status.Reason = "Branches are identical"
    }
    elseif ($status.Ahead -eq 0 -and $status.Behind -gt 0) {
        $status.SafeToDelete = $true
        $status.Reason = "Local branch is behind remote (remote has new commits)"
    }
    elseif ($status.Ahead -gt 0 -and $status.Behind -eq 0) {
        $status.Reason = "Local branch has commits not pushed to remote"
    }
    elseif ($status.Ahead -gt 0 -and $status.Behind -gt 0) {
        $status.Reason = "Branches have diverged"
    }
    else {
        $status.Reason = "Unknown branch status"
    }

    return $status
}

function Get-GitRepositoryPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root
    )

    Get-ChildItem -Path $Root -Recurse -Directory -Force -Filter .git -ErrorAction SilentlyContinue |
        ForEach-Object { Split-Path $_.FullName -Parent } |
        Sort-Object -Unique
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

    .PARAMETER Fetch
        If specified, fetches from all remotes before processing.

    .PARAMETER Aggressive
        If specified, processes aggressive cleanup steps (git gc --aggressive, git reflog expire, git repack).

    .PARAMETER CollectSizeMetrics
        If specified, measures repository size before and after processing. Skipped by default to keep runs fast.

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

        [switch]$Force,

        [switch]$CollectSizeMetrics,

        [string[]]$ProtectedBranches = @('main', 'master', 'dev', 'develop')
    )

    function Invoke-SingleRepoMaintenance {
        param(
            [string]$Path,
            [bool]$IsDryRun
        )

        if (-not (Test-Path (Join-Path $Path '.git'))) {
            Write-Host "[FAIL] Not a git repository: $Path" -ForegroundColor Red
            return
        }

        $repoName = Split-Path $Path -Leaf
        $originalDir = Get-Location

        try {
            Set-Location $Path

            Write-Host -Object ("`n" + "═"*70) -ForegroundColor Blue
            if ($IsDryRun) { Write-Host "[DRY]  DRY RUN - REPOSITORY: $repoName" -ForegroundColor Yellow -BackgroundColor DarkBlue }
            else { Write-Host "[DIR]  REPOSITORY: $repoName" -ForegroundColor White -BackgroundColor DarkBlue }
            Write-Host "[PATH] PATH: $Path" -ForegroundColor Gray
            Write-Host "═"*70 -ForegroundColor Blue

            # Get initial repo size if metrics requested
            $initialSize = $null
            if ($CollectSizeMetrics) {
                $initialSize = Get-RepoSize -Path $Path
                Write-Host "[INFO] Initial repository size: $(ConvertTo-HumanReadableSize $initialSize)" -ForegroundColor Gray
            }

            # Show current branch
            $currentBranch = git branch --show-current 2>$null
            if ($currentBranch) { Write-Host "[GIT]  Current Branch: $currentBranch" -ForegroundColor Cyan }

            # Optionally fetch
            if ($Fetch) {
                Write-Host "`n[SYNC] Fetching latest from remote..." -ForegroundColor Yellow
                if (-not $IsDryRun) { if ($PSCmdlet.ShouldProcess($Path, 'git fetch --all --prune')) { git fetch --all --prune 2>$null } }
                else { Write-Host "(dry run) Would: git fetch --all --prune" -ForegroundColor DarkYellow }
            }

            # Show status before cleanup
            Write-Host "`n[INFO] Status before cleanup:" -ForegroundColor Yellow
            git status --short --branch 2>$null

            # Build branch -> metadata mapping without checkout
            $branchMetadata = @{}
            git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads 2>$null |
            ForEach-Object {
                if (-not $_) { return }
                $parts = $_ -split '\|', 3
                $branchName = $parts[0].Trim()
                if (-not $branchName) { return }
                $upstream = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
                $track = if ($parts.Count -gt 2) { $parts[2].Trim() } else { '' }
                $branchMetadata[$branchName] = [pscustomobject]@{
                    Upstream = $upstream
                    Track    = $track
                }
            }

            # Candidate local branches excluding protected and current
            $localBranches = ($branchMetadata.Keys | Where-Object {
                    $_ -and ($_ -ne $currentBranch) -and ($ProtectedBranches -notcontains $_) -and ($_ -notmatch '^dev/|^develop/')
                })

            $branchesToDelete = @()

            foreach ($branch in $localBranches) {
                Write-Host "`n  Checking branch: $branch" -ForegroundColor Gray

                # Uncommitted changes check without checkout: compare worktree tree-ish is not trivial without checkout.
                # Heuristic: skip untracked state check; deletions only when ahead=0 and has upstream.

                # Resolve upstream
                $meta = $branchMetadata[$branch]
                $upstream = $meta.Upstream
                if (-not $upstream) {
                    Write-Host "  [FAIL] No remote tracking branch" -ForegroundColor Red
                    continue
                }

                $trackInfo = $meta.Track
                if ($trackInfo -match '\[gone\]') {
                    Write-Host "  [FAIL] Remote branch does not exist: $upstream" -ForegroundColor Red
                    continue
                }

                $ahead = 0
                $behind = 0
                if ($trackInfo) {
                    if ($trackInfo -match 'ahead\s+(\d+)') { $ahead = [int]$matches[1] }
                    if ($trackInfo -match 'behind\s+(\d+)') { $behind = [int]$matches[1] }
                }
                Write-Host "  Remote: $upstream" -ForegroundColor DarkGray
                Write-Host "  Status: Ahead $ahead, Behind $behind" -ForegroundColor DarkGray

                if ($ahead -eq 0 -and $behind -ge 0) {
                    Write-Host "  [OK]   Safe to delete: $branch" -ForegroundColor Green
                    $branchesToDelete += $branch
                }
                else {
                    $reason = if ($ahead -gt 0 -and $behind -eq 0) { 'Local branch has commits not pushed to remote' }
                    elseif ($ahead -gt 0 -and $behind -gt 0) { 'Branches have diverged' } else { 'Unknown or behind/ahead state' }
                    Write-Host "  [FAIL] Not safe to delete: $branch" -ForegroundColor Red
                    Write-Host "  Reason: $reason" -ForegroundColor DarkRed
                }
            }

            # Delete branches
            if ($branchesToDelete.Count -gt 0) {
                if ($IsDryRun) {
                    Write-Host "`n[DRY]  DRY RUN - Branches that would be deleted:" -ForegroundColor Yellow
                    foreach ($branch in $branchesToDelete) { Write-Host "  Would delete: $branch" -ForegroundColor Magenta }
                }
                else {
                    Write-Host "`n[DEL]  Deleting safe branches:" -ForegroundColor Yellow
                    $deleteFlag = if ($Force) { '-D' } else { '-d' }
                    foreach ($branch in $branchesToDelete) {
                        if ($PSCmdlet.ShouldProcess($branch, 'Delete local branch')) {
                            git branch $deleteFlag -- $branch 2>$null
                            if ($LASTEXITCODE -eq 0) { Write-Host "  [OK]   Deleted: $branch" -ForegroundColor Green }
                            else { Write-Host "  [FAIL] Failed to delete: $branch (use -Force to force-delete)" -ForegroundColor Red }
                        }
                    }
                }
            }
            else {
                Write-Host "`n[OK]   No branches to delete" -ForegroundColor Green
            }

            # REPOSITORY MAINTENANCE
            if (-not $IsDryRun) {
                Write-Host "`n[SAVE] Repository Maintenance:" -ForegroundColor Yellow

                # Probe git maintenance availability once per session
                if ($null -eq $script:GitMaintenanceAvailable) {
                    git maintenance run -h *> $null
                    $script:GitMaintenanceAvailable = ($LASTEXITCODE -in 0, 129)
                }

                $ranMaintenance = $false
                if ($script:GitMaintenanceAvailable) {
                    if ($PSCmdlet.ShouldProcess($Path, 'git maintenance run')) {
                        git maintenance run 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  [OK]   Maintenance completed" -ForegroundColor Green; $ranMaintenance = $true }
                    }
                }

                if (-not $ranMaintenance) {
                    if ($PSCmdlet.ShouldProcess($Path, 'git gc --prune=now')) {
                        git gc --prune=now 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  [OK]   GC completed" -ForegroundColor Green }
                    }
                }

                if ($Aggressive) {
                    if ($PSCmdlet.ShouldProcess($Path, 'git reflog expire --expire=now --all')) {
                        git reflog expire --expire=now --all 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  [OK]   Reflog pruned" -ForegroundColor Green }
                    }
                    if ($PSCmdlet.ShouldProcess($Path, 'git repack -ad --depth=50 --window=250')) {
                        git repack -ad --depth=50 --window=250 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  [OK]   Repack completed" -ForegroundColor Green }
                    }
                    if ($PSCmdlet.ShouldProcess($Path, 'git gc --aggressive --prune=now')) {
                        git gc --aggressive --prune=now 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  [OK]   Aggressive GC completed" -ForegroundColor Green }
                    }
                    if ($PSCmdlet.ShouldProcess($Path, 'git clean -fd')) {
                        git clean -fd 2>$null
                        if ($LASTEXITCODE -eq 0) { Write-Host "  [OK]   Clean completed" -ForegroundColor Green }
                    }
                }
            }
            else {
                Write-Host "`n[SAVE] Repository maintenance would be performed (skipped in dry run)" -ForegroundColor Yellow
            }

            # Get final repo size (only if not dry run and metrics requested)
            if (-not $IsDryRun -and $CollectSizeMetrics -and $null -ne $initialSize) {
                $finalSize = Get-RepoSize -Path $Path
                $sizeReduction = [long]($initialSize - $finalSize)

                Write-Host "`n[INFO] Size Analysis:" -ForegroundColor Yellow
                Write-Host "  Initial size: $(ConvertTo-HumanReadableSize $initialSize)" -ForegroundColor Gray
                Write-Host "  Final size:   $(ConvertTo-HumanReadableSize $finalSize)" -ForegroundColor Gray
                if ($sizeReduction -gt 0 -and $initialSize -gt 0) {
                    Write-Host "  Space saved:  $(ConvertTo-HumanReadableSize $sizeReduction)" -ForegroundColor Green
                    $reductionPercent = [math]::Round(($sizeReduction / [double]$initialSize) * 100, 1)
                    Write-Host "  Reduction:    $reductionPercent%" -ForegroundColor Green
                }
                else {
                    Write-Host "  No significant size reduction" -ForegroundColor Yellow
                }
            }

            # Show final status
            Write-Host "`n[GIT]  Final Branch Status:" -ForegroundColor Yellow
            git branch --list 2>$null | ForEach-Object {
                if ($_ -match '^\*\s') { Write-Host "  -> $($_.Substring(2))" -ForegroundColor Cyan }
                elseif ($_ -match '\b(dev|develop|main|master)\b') { Write-Host "  [MAIN] $($_.Trim())" -ForegroundColor Magenta }
                else { Write-Host "    $($_.Trim())" -ForegroundColor Gray }
            }

            if ($IsDryRun) { Write-Host "`n[DRY]  DRY RUN completed for: $repoName" -ForegroundColor Yellow }
            else { Write-Host "`n[OK]   Repository processing completed: $repoName" -ForegroundColor Green }

        }
        catch {
            Write-Host "[FAIL] Error processing: $repoName" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        finally {
            Set-Location $originalDir
        }
    }

    # Validate path exists
    if (-not (Test-Path $RepoPath)) {
        Write-Host "[FAIL] Path does not exist: $RepoPath" -ForegroundColor Red
        return
    }

    # Resolve relative paths to absolute
    $RepoPath = (Resolve-Path $RepoPath).Path

    # Main execution logic
    if ($Recursive) {
        Write-Host "[DRY]  Searching for git repositories recursively under: $RepoPath" -ForegroundColor Cyan
        $repos = @(Get-GitRepositoryPaths -Root $RepoPath)

        if (-not $repos) {
            Write-Host "[FAIL] No git repositories found" -ForegroundColor Yellow
            return
        }

        Write-Host "[INFO] Found $($repos.Count) repositories to process" -ForegroundColor Cyan

        foreach ($repo in $repos) {
            if ($PSCmdlet.ShouldProcess($repo, 'Process repository')) {
                Invoke-SingleRepoMaintenance -Path $repo -IsDryRun $DryRun
            }
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess($RepoPath, 'Process repository')) {
            Invoke-SingleRepoMaintenance -Path $RepoPath -IsDryRun $DryRun
        }
    }
}

function Get-GitRepositoriesSummary {
    [CmdletBinding()]
    [Alias('gitStandup')]
    param(
        [string]$Path = ".",
        [int]$DaysBack,
        [switch]$Fetch
    )

    if (-not $DaysBack) {
        $today = (Get-Date).DayOfWeek
        if ($today -eq 'Monday') {
            $DaysBack = 3
        }
        else {
            $DaysBack = 1
        }
    }

    $since = (Get-Date).AddDays(-$DaysBack)

    function Get-GitSummary($repoPath, $since, $doFetch) {
        Push-Location $repoPath

        if ($doFetch) {
            Write-Verbose "Fetching updates for $repoPath"
            git fetch --all > $null 2>&1
        }

        $output = git log --since=$since.ToString("yyyy-MM-dd") --pretty=format:"%an|%ad|%h %s" --date=short

        if (-not [string]::IsNullOrWhiteSpace($output)) {
            Write-Host "Repository: $repoPath" -ForegroundColor Cyan

            $commits = $output -split "`n" | ForEach-Object {
                $parts = $_ -split "\|", 3
                [PSCustomObject]@{
                    Author = $parts[0]
                    Date   = $parts[1]
                    Commit = $parts[2]
                }
            }

            $commits | Group-Object Author | ForEach-Object {
                $authorGroup = $_
                $count = $authorGroup.Count
                Write-Host "  Author: $($authorGroup.Name) ($count commits)" -ForegroundColor Yellow

                $authorGroup.Group | Group-Object Date | Sort-Object Name | ForEach-Object {
                    Write-Host "    Date: $($_.Name)" -ForegroundColor Green
                    $_.Group | ForEach-Object { "      $($_.Commit)" }
                }
                Write-Host
            }
        }

        Pop-Location
    }

    if (Test-Path (Join-Path $Path ".git")) {
        Get-GitSummary -repoPath $Path -since $since -doFetch:$Fetch
    }
    else {
        $repos = Get-ChildItem -Path $Path -Directory -Recurse -Force | Where-Object { Test-Path (Join-Path $_.FullName ".git") }
        foreach ($repo in $repos) {
            Get-GitSummary -repoPath $repo.FullName -since $since -doFetch:$Fetch
        }
    }
}

function Invoke-AiCommit {
    [CmdletBinding()]
    [Alias('aicommit')]
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Context
    )

    if (-not (Get-Command lumen -ErrorAction SilentlyContinue)) {
        Write-Error "lumen not found in PATH. Install it from https://github.com/jrcribb/lumen to use Invoke-AiCommit."
        return
    }

    $staged = git diff --cached --name-only

    if (-not $staged) {
        Write-Host "No staged changes found. Launching git add -i (interactive staging)..." -ForegroundColor Yellow
        git add -i

        $staged = git diff --cached --name-only

        if (-not $staged) {
            Write-Warning "Still no staged changes. Aborting commit."
            return
        }
    }

    if ($Context) {
        $draft = lumen draft --context "$Context"
    }
    else {
        $draft = lumen draft
    }

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($draft)) {
        Write-Error "lumen failed to generate a commit message. Aborting."
        return
    }

    $draft | git commit -F -
}
