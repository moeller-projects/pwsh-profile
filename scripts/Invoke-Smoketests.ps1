param(
    [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'
if ($VerboseOutput) { $VerbosePreference = 'Continue' }

# Discover the split function-area modules without eagerly importing them.
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'PwshProfile.File'))) {
    throw "Profile modules not found under $repoRoot"
}
$separator = [System.IO.Path]::PathSeparator
if ($env:PSModulePath -notlike "*${repoRoot}*") {
    $env:PSModulePath = "$repoRoot$separator$env:PSModulePath"
}

function New-TempWorkspace {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $temp = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ("pwsh-profile-smoke-" + [System.Guid]::NewGuid()))
    Push-Location $temp.FullName
    return $temp
}

function Remove-TempWorkspace {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)]$Temp)
    Pop-Location
    Remove-Item -Recurse -Force -LiteralPath $Temp.FullName -ErrorAction SilentlyContinue
}

$script:results = @()
function Test-Case($Name, [scriptblock]$Body) {
    Write-Host "[RUN] $Name" -ForegroundColor Cyan
    try {
        & $Body
        $script:results += [pscustomobject]@{ Name = $Name; Status = 'Pass' }
        Write-Host "[OK ] $Name" -ForegroundColor Green
    }
    catch {
        $script:results += [pscustomobject]@{ Name = $Name; Status = 'Fail'; Error = $_.Exception.Message }
        Write-Host "[ERR] $Name -> $($_.Exception.Message)" -ForegroundColor Red
    }
}

$ws = New-TempWorkspace
try {
    # Navigation helpers (parent/home)
    Test-Case 'Set-LocationParentTwoLevels' {
        New-Item -ItemType Directory -Name 'p1' | Out-Null
        Push-Location 'p1'
        New-Item -ItemType Directory -Name 'p2' | Out-Null
        Push-Location 'p2'
        Set-LocationParentTwoLevels
        if ((Split-Path -Leaf (Get-Location)) -ne (Split-Path -Leaf $ws.FullName)) { throw 'Did not return to workspace root' }
    }
    Test-Case 'Set-LocationHome changes to HOME' {
        $homeDir = $HOME
        Push-Location (Split-Path $homeDir -Parent -ErrorAction SilentlyContinue) -ErrorAction SilentlyContinue
        try {
            Set-LocationHome
            if (-not ((Get-Location).Path -eq $homeDir)) { throw "Set-LocationHome did not navigate to HOME ($homeDir)" }
        }
        finally { Pop-Location -ErrorAction SilentlyContinue }
    }
    Test-Case 'Set-LocationParent changes up one level' {
        New-Item -ItemType Directory -Name 'nav1' | Out-Null
        Push-Location 'nav1'
        $parentPath = (Get-Location).Path
        Set-LocationParent
        if ((Get-Location).Path -eq $parentPath) { throw 'Set-LocationParent did not navigate up' }
        Pop-Location -ErrorAction SilentlyContinue
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
    if ($IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')) {
        Test-Case 'trash -WhatIf guarded' { touch 'z.txt'; trash -path 'z.txt' -WhatIf }
    } else {
        Write-Host '[SKIP] trash requires Windows Shell' -ForegroundColor Yellow
    }

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
    Test-Case 'export NAME=VALUE form' { export 'TEST_SMOKE_NV=hello'; if ($env:TEST_SMOKE_NV -ne 'hello') { throw "export NAME=VALUE did not set variable" } }
    Test-Case 'Use-Env loads quoted values' {
        $envFile = Join-Path (Get-Location) '.env'
        @"
SMOKE_FOO='bar baz'
SMOKE_BAR="qux"
export SMOKE_EXPORTED=yes
"@ | Set-Content -Path $envFile -Encoding UTF8
        Use-Env -Path $envFile
        if ($env:SMOKE_FOO -ne 'bar baz') { throw "SMOKE_FOO not set correctly: '$env:SMOKE_FOO'" }
        if ($env:SMOKE_BAR -ne 'qux') { throw "SMOKE_BAR not set correctly: '$env:SMOKE_BAR'" }
        if ($env:SMOKE_EXPORTED -ne 'yes') { throw "SMOKE_EXPORTED not set correctly: '$env:SMOKE_EXPORTED'" }
        if ($env:APP_ENV -eq 'DEV') { throw "Use-Env must not force APP_ENV=DEV" }
        Remove-Item $envFile -ErrorAction SilentlyContinue
    }
    Test-Case 'Enter-ProjectDirectory not-found warning' {
        $warnings = @()
        Enter-ProjectDirectory -ProjectName '__no_such_project_xyz__' -WarningVariable warnings -WarningAction SilentlyContinue
        if (-not ($warnings -match "Project '__no_such_project_xyz__' not found")) {
            throw 'Missing project warning was not emitted'
        }
    }

    Test-Case 'Set-ProjectPaths/Get-ProjectPaths round-trip' {
        $tempCfg = Join-Path ([System.IO.Path]::GetTempPath()) ("pwsh-profile-smoke-cfg-" + [System.Guid]::NewGuid() + ".json")
        try {
            $env:PWSH_PROFILE_CONFIG_OVERRIDE = $tempCfg
            $testPaths = @('/tmp/proj1', '/tmp/proj2')
            Set-ProjectPaths -Paths $testPaths
            $roundTrip = @(Get-ProjectPaths)
            if ($roundTrip.Count -ne $testPaths.Count -or
                (@($roundTrip) -join '|') -ne (@($testPaths) -join '|')) {
                throw "Config round-trip failed: $($roundTrip -join ', ')"
            }
        }
        finally {
            Remove-Item Env:\PWSH_PROFILE_CONFIG_OVERRIDE -ErrorAction SilentlyContinue
            Remove-Item $tempCfg -ErrorAction SilentlyContinue
        }
    }
    Test-Case 'Get-ProjectPaths returns array' {
        $paths = @(Get-ProjectPaths)
        # An empty array is valid when no project config exists; just verify it doesn't throw
        if ($null -eq $paths) { throw 'Get-ProjectPaths returned null' }
    }
    Test-Case 'uptime runs' { uptime }
    Test-Case 'pgrep/pkill harmless on unknown' { pgrep 'unlikely-proc-name' -ErrorAction SilentlyContinue | Out-Null; pkill 'unlikely-proc-name' }
    Test-Case 'Stop-ProcessForce harmless on unknown' { Stop-ProcessForce -Name 'unlikely-proc-name' }
    if ($IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')) {
        Test-Case 'flushdns non-fatal' { try { flushdns } catch { Write-Verbose "flushdns skipped: $_" } }
        Test-Case 'sysinfo non-fatal' { try { sysinfo | Out-Null } catch { Write-Verbose "sysinfo skipped: $_" } }
        Test-Case 'Get-ProcessPort and Stop-ProcessPort -WhatIf' {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
            $listener.Start()
            try {
                $port = $listener.LocalEndpoint.Port
                $connection = Get-ProcessPort -Port $port | Select-Object -First 1
                if ($connection.ProcessId -ne $PID) { throw "Expected PID $PID on port $port" }
                Stop-ProcessPort -Port $port -WhatIf
                if (-not $listener.Server.IsBound) { throw 'WhatIf stopped the listener' }
            }
            finally {
                $listener.Stop()
            }
        }
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
        Test-Case 'Invoke-ChatGpt handles missing key' { $env:OPENAI_API_KEY=$null; Invoke-ChatGpt -Prompts @('ping') -ErrorAction SilentlyContinue }
    }
    Write-Host '[SKIP] Set-AIConfiguration is interactive' -ForegroundColor Yellow

    # Azure helpers
    Test-Case 'New-MenuItem returns typed object' {
        $m = New-MenuItem 'n' 'v'
        if ($null -eq $m -or $m.Name -ne 'n' -or $m.Value -ne 'v') { throw 'New-MenuItem failed' }
    }
    Write-Host '[SKIP] Switch-AzureSubscription/Connect-AcrRegistry require az/docker and UI' -ForegroundColor Yellow

    # Kubernetes helpers
    Write-Host '[SKIP] Select-KubeContext/Select-KubeNamespace require kubectl and fzf' -ForegroundColor Yellow

    # Network helper (external call)
    Write-Host '[SKIP] Get-PubIP performs network call' -ForegroundColor Yellow

    # Completions initializer
    Write-Host '[SKIP] Initialize-Completion depends on external tools' -ForegroundColor Yellow
}
finally {
    Remove-TempWorkspace -Temp $ws
}

Write-Host "\nSummary:" -ForegroundColor DarkCyan
$script:results | Sort-Object Status, Name | Format-Table -AutoSize
if ($script:results | Where-Object Status -eq 'Fail') { exit 1 } else { exit 0 }
