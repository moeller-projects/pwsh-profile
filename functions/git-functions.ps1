function gclean {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "git not found in PATH."
        return
    }

    $branchesToDelete = git branch --merged | ForEach-Object { $_.Trim() } | Where-Object {
        ($_ -notmatch '^\*') -and ($_ -notmatch '^(main|master|dev|develop)$')
    }

    if ($branchesToDelete.Count -eq 0) {
        Write-Host "No merged branches to delete." -ForegroundColor Cyan
        return
    }

    Write-Host "Deleting merged branches: $($branchesToDelete -join ', ')" -ForegroundColor Yellow
    foreach ($branch in $branchesToDelete) {
        if ($PSCmdlet.ShouldProcess($branch, "delete branch")) {
            try {
                git branch -d $branch
                Write-Verbose "Successfully deleted branch: $branch"
            }
            catch {
                Write-Warning "Failed to delete branch: $branch. Error: $($_.Exception.Message)"
            }
        }
    }
    Write-Host "Branch cleanup completed." -ForegroundColor Green
}

function Switch-GitBranch {
    [CmdletBinding()]
    [Alias('gg','Git-Go')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromRemainingArguments = $true)]
        [Object[]] $Arguments,
        [switch]$Fetch
    )

    begin {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Error "git not found in PATH."
            $script:exitEarly = $true
            return
        }
        if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
            Write-Error "fzf not found in PATH. Install fzf to use Git-Go."
            $script:exitEarly = $true
            return
        }
        if (-not ([System.IO.Directory]::Exists((Join-Path (Get-Location).Path ".git")))) {
            Write-Host "[ERROR] This is not a Git repository!" -ForegroundColor Red
            $script:exitEarly = $true
            return
        }

        if ($Fetch) {
            Write-Verbose "Fetching all git remotes..."
            git fetch --all | Out-Null
        }

        Write-Verbose "Getting local branches..."
        $localBranches = @(git branch --format='%(refname:short)')
        $localBranchSet = @{}
        foreach ($b in $localBranches) { $localBranchSet[$b.Trim()] = $true }

        $fzfQuery = ($Arguments -join ' ')
        Write-Verbose "Running fzf to select branch with query '$fzfQuery'..."
        # External call to fzf - inherent overhead
        $selectedBranch = (& git branch --all | fzf -q $fzfQuery) -replace '^\*', '' -replace 'remotes/origin/', ''
        $script:selectedBranch = $selectedBranch.Trim()
    }

    process {
        if ($script:exitEarly) { return }

        if ([string]::IsNullOrWhiteSpace($script:selectedBranch)) {
            Write-Host "[INFO] No branch selected. Exiting..." -ForegroundColor Yellow
            return
        }

        Write-Verbose "[INFO] Selected branch: $script:selectedBranch"

        if ($localBranchSet.ContainsKey($script:selectedBranch)) {
            Write-Host "[INFO] Checking out existing local branch: $script:selectedBranch" -ForegroundColor Cyan
            & git checkout $script:selectedBranch
        }
        else {
            Write-Host "[INFO] Creating and checking out new branch from origin/$script:selectedBranch" -ForegroundColor Cyan
            & git checkout -b $script:selectedBranch origin/$script:selectedBranch
        }

        Write-Host "[SUCCESS] Switched to branch: $script:selectedBranch" -ForegroundColor Green
    }
}
