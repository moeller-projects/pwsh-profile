[CmdletBinding()]
param(
    [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'
if ($VerboseOutput) { $VerbosePreference = 'Continue' }

try {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    $modulePath = Join-Path $repoRoot 'PwshProfile/PwshProfile.psd1'
    if (Test-Path -LiteralPath $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    }
}
catch {
    Write-Verbose "Module import failed: $($_.Exception.Message). Proceeding with current session scope."
}

function New-SmokeWorkspace {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("pwsh-profile-smoke-" + [System.Guid]::NewGuid())
    if ($PSCmdlet.ShouldProcess($tempPath, 'Create smoke test workspace')) {
        $temp = New-Item -ItemType Directory -Path $tempPath -Force
        Push-Location $temp.FullName
        return $temp
    }
}

function Remove-SmokeWorkspace {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]$Workspace
    )

    Pop-Location
    if ($PSCmdlet.ShouldProcess($Workspace.FullName, 'Remove smoke test workspace')) {
        Remove-Item -Recurse -Force -LiteralPath $Workspace.FullName -ErrorAction SilentlyContinue
    }
}

function Invoke-SmokeCase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Body
    )

    Write-Host "[RUN] $Name" -ForegroundColor Cyan
    try {
        & $Body
        $script:Results.Add([pscustomobject]@{ Name = $Name; Status = 'Pass'; Error = $null }) | Out-Null
        Write-Host "[OK ] $Name" -ForegroundColor Green
    }
    catch {
        $script:Results.Add([pscustomobject]@{ Name = $Name; Status = 'Fail'; Error = $_.Exception.Message }) | Out-Null
        Write-Host "[ERR] $Name -> $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Write-SmokeSkip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Reason
    )

    $script:Results.Add([pscustomobject]@{ Name = $Name; Status = 'Skip'; Error = $Reason }) | Out-Null
    Write-Host "[SKIP] $Name -> $Reason" -ForegroundColor Yellow
}

$script:Results = [System.Collections.Generic.List[object]]::new()
$workspace = New-SmokeWorkspace

try {
    Invoke-SmokeCase -Name 'Set-LocationParentTwoLevels returns to workspace root' -Body {
        New-Item -ItemType Directory -Name 'p1' | Out-Null
        Push-Location 'p1'
        New-Item -ItemType Directory -Name 'p2' | Out-Null
        Push-Location 'p2'
        Set-LocationParentTwoLevels
        if ((Get-Location).Path -ne $workspace.FullName) { throw 'Did not return to workspace root' }
    }

    Invoke-SmokeCase -Name 'Set-LocationHome runs' -Body {
        Push-Location (Get-Location)
        try {
            Set-LocationHome
        }
        finally {
            Pop-Location
        }
    }

    Invoke-SmokeCase -Name 'New-EmptyFile creates file' -Body {
        touch 'a.txt'
        if (-not (Test-Path -LiteralPath 'a.txt')) { throw 'File not created' }
    }

    Invoke-SmokeCase -Name 'Get-FileSize returns value' -Body {
        'x' | Set-Content -LiteralPath 'c.txt'
        if (-not (Get-FileSize -Path 'c.txt')) { throw 'Expected a file size result' }
    }

    Invoke-SmokeCase -Name 'Get-FileHead/Get-FileTail work' -Body {
        "1`n2`n3" | Set-Content -LiteralPath 'd.txt'
        if ((Get-FileHead -Path 'd.txt' -LineCount 1)[0] -ne '1') { throw 'Head returned wrong content' }
        if ((Get-FileTail -Path 'd.txt' -LineCount 1)[0] -ne '3') { throw 'Tail returned wrong content' }
    }

    Invoke-SmokeCase -Name 'Update-FileText -WhatIf does not modify file' -Body {
        'foo' | Set-Content -LiteralPath 'e.txt'
        Update-FileText -Path 'e.txt' -Find 'foo' -Replace 'bar' -WhatIf
        if ((Get-Content -LiteralPath 'e.txt' -Raw).Trim() -ne 'foo') { throw 'Content changed with -WhatIf' }
    }

    Invoke-SmokeCase -Name 'Enter-NewDirectory changes directory' -Body {
        Enter-NewDirectory -Name 'dir1'
        if ((Split-Path -Leaf (Get-Location)) -ne 'dir1') { throw 'Did not change directory' }
    }

    Invoke-SmokeCase -Name 'Find-File finds files recursively' -Body {
        touch 'findme.txt'
        $result = Find-File -Name 'findme' -Recurse
        if (-not $result) { throw 'No files found' }
    }

    Invoke-SmokeCase -Name 'Find-Text matches regex' -Body {
        'hello world' | Set-Content -LiteralPath 'g.txt'
        if (-not (Find-Text -Pattern 'world' -Path (Get-Location).Path)) { throw 'No grep result' }
    }

    Invoke-SmokeCase -Name 'Remove-ToRecycleBin -WhatIf is guarded' -Body {
        touch 'z.txt'
        Remove-ToRecycleBin -Path 'z.txt' -WhatIf
    }

    Invoke-SmokeCase -Name 'Expand-ZipFile extracts archive' -Body {
        'data' | Set-Content -LiteralPath 'u.txt'
        Compress-Archive -Path 'u.txt' -DestinationPath 'u.zip' -Force
        Remove-Item -LiteralPath 'u.txt'
        Expand-ZipFile -Name 'u.zip'
        if (-not (Test-Path -LiteralPath 'u.txt')) { throw 'Archive was not extracted' }
    }

    Invoke-SmokeCase -Name 'Get-RecentHistory runs' -Body {
        Get-RecentHistory -Last 1 | Out-Null
    }

    Invoke-SmokeCase -Name 'export and which run' -Body {
        export TEST_SMOKE '1'
        if ((Get-Item Env:TEST_SMOKE).Value -ne '1') { throw 'export did not set environment variable' }
        which pwsh | Out-Null
    }

    Invoke-SmokeCase -Name 'uptime runs' -Body {
        uptime | Out-Null
    }

    Invoke-SmokeCase -Name 'pgrep/pkill harmless on unknown process' -Body {
        pgrep 'unlikely-proc-name' -ErrorAction SilentlyContinue | Out-Null
        pkill 'unlikely-proc-name'
    }

    Invoke-SmokeCase -Name 'Stop-ProcessForce -WhatIf is guarded' -Body {
        Stop-ProcessForce -Name 'unlikely-proc-name' -WhatIf
    }

    if ($IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')) {
        Invoke-SmokeCase -Name 'flushdns runs on Windows' -Body { flushdns }
        Invoke-SmokeCase -Name 'sysinfo runs on Windows' -Body { sysinfo | Out-Null }
    }
    else {
        Write-SmokeSkip -Name 'Windows-only dev helpers' -Reason 'requires Windows-only cmdlets'
    }

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Invoke-SmokeCase -Name 'Remove-MergedGitBranches -WhatIf runs' -Body { Remove-MergedGitBranches -WhatIf }
    }
    else {
        Write-SmokeSkip -Name 'Remove-MergedGitBranches' -Reason 'requires git'
    }

    if (Get-Command Get-Volume -ErrorAction SilentlyContinue) {
        Invoke-SmokeCase -Name 'Get-VolumeUsage runs' -Body { Get-VolumeUsage | Out-Null }
    }
    else {
        Write-SmokeSkip -Name 'Get-VolumeUsage' -Reason 'requires Get-Volume'
    }

    if ((Get-Command Set-Clipboard -ErrorAction SilentlyContinue) -and (Get-Command Get-Clipboard -ErrorAction SilentlyContinue)) {
        Invoke-SmokeCase -Name 'Set-ClipboardText/Get-ClipboardText run' -Body {
            Set-ClipboardText -Text 'clip'
            Get-ClipboardText | Out-Null
        }
    }
    else {
        Write-SmokeSkip -Name 'Clipboard helpers' -Reason 'requires clipboard cmdlets'
    }

    Invoke-SmokeCase -Name 'Invoke-ChatGpt handles missing key' -Body {
        $previousKey = $env:OPENAI_API_KEY
        try {
            $env:OPENAI_API_KEY = $null
            Invoke-ChatGpt -PromptArguments @('ping') -ErrorAction SilentlyContinue
        }
        finally {
            $env:OPENAI_API_KEY = $previousKey
        }
    }

    Invoke-SmokeCase -Name 'New-MenuItem returns typed object' -Body {
        $menuItem = New-MenuItem 'n' 'v'
        if ($null -eq $menuItem -or $menuItem.Name -ne 'n' -or $menuItem.Value -ne 'v') { throw 'New-MenuItem failed' }
    }

    Write-SmokeSkip -Name 'Switch-AzureSubscription/Connect-ContainerRegistry' -Reason 'requires az and Show-Menu'
    Write-SmokeSkip -Name 'New-NetworkAccessExceptionForResources' -Reason 'downloads and runs a remote script'
    Write-SmokeSkip -Name 'Select-KubeContext/Select-KubeNamespace' -Reason 'requires kubectl and fzf'
    Write-SmokeSkip -Name 'Get-PubIP' -Reason 'requires a network call'
    Write-SmokeSkip -Name 'Initialize-Completion' -Reason 'depends on optional external tools'

    if ($env:PWSH_PROFILE_SMOKE_FORCE_FAILURE -eq '1') {
        Invoke-SmokeCase -Name 'Forced failure sentinel' -Body { throw 'Forced failure sentinel triggered.' }
    }
}
finally {
    Remove-SmokeWorkspace -Workspace $workspace
}

Write-Host "`nSummary:" -ForegroundColor DarkCyan
$script:Results | Sort-Object Status, Name | Format-Table -AutoSize | Out-String | Write-Host

if ($script:Results.Where({ $_.Status -eq 'Fail' }).Count -gt 0) {
    exit 1
}

exit 0
