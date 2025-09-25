param(
    [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'
if ($VerboseOutput) { $VerbosePreference = 'Continue' }

# Ensure module or functions are available
try {
    $repoRoot = Split-Path -Parent $PSCommandPath
    $repoRoot = Split-Path -Parent $repoRoot
    $modulePath = Join-Path $repoRoot 'PwshProfile/PwshProfile.psd1'
    if (Test-Path $modulePath) { Import-Module $modulePath -Force -ErrorAction Stop }
}
catch {
    Write-Verbose "Module import failed: $($_.Exception.Message). Proceeding with current session scope."
}

function New-TempWorkspace {
    $temp = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ("pwsh-profile-smoke-" + [System.Guid]::NewGuid()))
    Push-Location $temp.FullName
    return $temp
}

function Remove-TempWorkspace($temp) {
    Pop-Location
    Remove-Item -Recurse -Force -LiteralPath $temp.FullName -ErrorAction SilentlyContinue
}

$results = @()
function Test-Case($Name, [scriptblock]$Body) {
    Write-Host "[RUN] $Name" -ForegroundColor Cyan
    try {
        & $Body
        $results += [pscustomobject]@{ Name = $Name; Status = 'Pass' }
        Write-Host "[OK ] $Name" -ForegroundColor Green
    }
    catch {
        $results += [pscustomobject]@{ Name = $Name; Status = 'Fail'; Error = $_.Exception.Message }
        Write-Host "[ERR] $Name -> $($_.Exception.Message)" -ForegroundColor Red
    }
}

$ws = New-TempWorkspace
try {
    # Navigation helpers (parent/home)
    Test-Case 'goParent/goToParent2Levels' {
        New-Item -ItemType Directory -Name 'p1' | Out-Null
        Push-Location 'p1'
        New-Item -ItemType Directory -Name 'p2' | Out-Null
        Push-Location 'p2'
        goToParent2Levels
        if ((Split-Path -Leaf (Get-Location)) -ne (Split-Path -Leaf $ws.FullName)) { throw 'Did not return to workspace root' }
    }
    Test-Case 'goToHome (non-fatal)' {
        Push-Location (Get-Location)
        try { goToHome } catch {}
        Pop-Location
    }

    # Basic file helpers
    Test-Case 'touch creates file' { touch 'a.txt'; if (-not (Test-Path 'a.txt')) { throw 'File not created' } }
    Test-Case 'nf creates file' { nf 'b.txt'; if (-not (Test-Path 'b.txt')) { throw 'File not created' } }
    Test-Case 'Get-FileSize returns value' { touch 'c.txt'; (Get-FileSize -Path 'c.txt') | Out-Null }
    Test-Case 'head/tail work on file' { '1`n2`n3' | Set-Content -Path 'd.txt'; head -Path 'd.txt' -n 1 | Out-Null; tail -Path 'd.txt' -n 1 | Out-Null }
    Test-Case 'sed -WhatIf does not modify' { 'foo' | Set-Content 'e.txt'; sed -file 'e.txt' -find 'foo' -replace 'bar' -WhatIf; if ((Get-Content 'e.txt') -ne 'foo') { throw 'Content changed with -WhatIf' } }
    Test-Case 'mkcd changes directory' { mkcd 'dir1'; if ((Split-Path -Leaf (Get-Location)) -ne 'dir1') { throw 'Did not cd' } }
    Test-Case 'Find-File finds files' { touch 'findme.txt'; $res = Find-File 'findme'; if (-not $res) { throw 'No files found' } }
    Test-Case 'grep matches regex' { 'hello world' | Set-Content 'g.txt'; (grep 'world' (Get-Location)) | Out-Null }
    Test-Case 'trash -WhatIf guarded' { touch 'z.txt'; trash -path 'z.txt' -WhatIf }

    # Archive helpers
    Test-Case 'unzip extracts archive' {
        'data' | Set-Content 'u.txt'
        Compress-Archive -Path 'u.txt' -DestinationPath 'u.zip' -Force
        unzip 'u.zip'
        if (-not (Test-Path 'u.txt')) { throw 'Unzip did not extract' }
    }

    # Dev helpers
    Test-Case 'Get-RecentHistory runs' { Get-RecentHistory -Last 1 | Out-Null }
    Test-Case 'which/export run' { export TEST_SMOKE '1'; which pwsh | Out-Null }
    Test-Case 'uptime runs' { uptime }
    Test-Case 'pgrep/pkill harmless on unknown' { pgrep 'unlikely-proc-name' -ErrorAction SilentlyContinue | Out-Null; pkill 'unlikely-proc-name' }
    Test-Case 'Stop-ProcessForce harmless on unknown' { Stop-ProcessForce -Name 'unlikely-proc-name' }
    if ($IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')) {
        Test-Case 'flushdns non-fatal' { try { flushdns } catch {} }
        Test-Case 'sysinfo non-fatal' { try { sysinfo | Out-Null } catch {} }
    } else {
        Write-Host '[SKIP] Windows-only dev helpers' -ForegroundColor Yellow
    }

    # Git helpers (skip if not in a git repo)
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Test-Case 'gclean -WhatIf' { gclean -WhatIf }
    } else {
        Write-Host '[SKIP] git not found' -ForegroundColor Yellow
    }

    # df (platform dependent)
    if (Get-Command Get-Volume -ErrorAction SilentlyContinue) {
        Test-Case 'df runs' { df | Out-Null }
    } else {
        Write-Host '[SKIP] Get-Volume not available' -ForegroundColor Yellow
    }

    # Clipboard helpers (if available)
    if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue -CommandType Cmdlet) {
        Test-Case 'cpy/pst run' { cpy 'clip'; pst | Out-Null }
    } else {
        Write-Host '[SKIP] Clipboard cmdlets not available' -ForegroundColor Yellow
    }

    # AI helper basic checks
    if (Get-Command Invoke-ChatGpt -ErrorAction SilentlyContinue) {
        Test-Case 'Invoke-ChatGpt handles missing key' { $env:OPENAI_API_KEY=$null; Invoke-ChatGpt -Args @('ping') -ErrorAction SilentlyContinue }
    }
    Write-Host '[SKIP] Set-AIConfiguration is interactive' -ForegroundColor Yellow

    # Azure helpers
    Test-Case 'New-MenuItem returns typed object' {
        $m = New-MenuItem 'n' 'v'
        if ($null -eq $m -or $m.Name -ne 'n' -or $m.Value -ne 'v') { throw 'New-MenuItem failed' }
    }
    Write-Host '[SKIP] Switch-AzureSubscription/Connect-AcrRegistry require az/docker and UI' -ForegroundColor Yellow
    Write-Host '[SKIP] New-NetworkAccessExceptionForResources downloads and runs remote script' -ForegroundColor Yellow

    # Kubernetes helpers
    Write-Host '[SKIP] Select-KubeContext/Select-KubeNamespace require kubectl and fzf' -ForegroundColor Yellow

    # Network helper (external call)
    Write-Host '[SKIP] Get-PubIP performs network call' -ForegroundColor Yellow

    # Completions initializer
    Write-Host '[SKIP] Initialize-Completion depends on external tools' -ForegroundColor Yellow
}
finally {
    Remove-TempWorkspace $ws
}

Write-Host "\nSummary:" -ForegroundColor DarkCyan
$results | Sort-Object Status, Name | Format-Table -AutoSize
if ($results | Where-Object Status -eq 'Fail') { exit 1 } else { exit 0 }
