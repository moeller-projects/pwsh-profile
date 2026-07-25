function Get-RecentHistory {
    [CmdletBinding()]
    param (
        [Int32]$Last
    )
    # Get-PSReadLineOption is a cmdlet but typically fast.
    # Get-Content is fine for reading file content.
    $historyFilePath = (Get-PSReadLineOption).HistorySavePath
    if ([System.IO.File]::Exists($historyFilePath)) {
        $historyEntries = $(Get-Content $historyFilePath | Select-Object -Last $Last) -join "`n"
        Write-Output $historyEntries
        $historyEntries | Set-Clipboard # Using Set-Clipboard which is a cmdlet, but generally fast.
        Write-Information "Copied to Clipboard"
    }
    else {
        Write-Warning "PSReadLine history file not found at $historyFilePath."
    }
}

function Clear-Cache {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$IncludePrefetch
    )
    $isWindowsCompat = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')
    if (-not $isWindowsCompat) {
        Write-Warning "Clear-Cache currently supports Windows only."
        return
    }
    Write-Host "Clearing cache..." -ForegroundColor Cyan

    if ($IncludePrefetch -and $PSCmdlet.ShouldProcess("Windows Prefetch")) {
        Write-Verbose "Clearing Windows Prefetch..."
        Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue
    }
    if ($PSCmdlet.ShouldProcess("Windows Temp")) {
        Write-Verbose "Clearing Windows Temp..."
        Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($PSCmdlet.ShouldProcess("User Temp")) {
        Write-Verbose "Clearing User Temp..."
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($PSCmdlet.ShouldProcess("IE/Edge Cache")) {
        Write-Verbose "Clearing IE/Edge Cache..."
        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Cache clearing completed." -ForegroundColor Green
}

function pkill {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name)
    Get-Process $Name -ErrorAction SilentlyContinue | Stop-Process
}
function pgrep {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name)
    Get-Process $Name -ErrorAction SilentlyContinue
}
function Stop-ProcessForce {
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('k9')]
    param(
        [Parameter(Mandatory)][string]$Name
    )
    Stop-Process -Name $Name -Force -ErrorAction SilentlyContinue
}
function sysinfo {
    [CmdletBinding()]
    param()
    $isWindowsCompat = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')
    if (-not $isWindowsCompat) {
        Write-Warning "sysinfo currently supports Windows only."
        return
    }
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop |
            Select-Object Caption, Version, LastBootUpTime, @{N='TotalMemoryGB';E={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}}
        $os
    }
    catch {
        Write-Error "Failed to retrieve system info: $($_.Exception.Message)"
    }
}
function flushdns {
    Clear-DnsClientCache
    Write-Information "DNS has been flushed"
}
function which {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name)
    Get-Command $Name | Select-Object -ExpandProperty Definition
}
function export {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string]$Name,
        [Parameter(Position = 1)][AllowEmptyString()][string]$Value
    )
    # Support single-argument NAME=VALUE form
    if (-not $PSBoundParameters.ContainsKey('Value') -and $Name -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
        Set-Item -Force -Path "env:$($Matches[1])" -Value $Matches[2]
    }
    else {
        Set-Item -Force -Path "env:$Name" -Value $Value
    }
}

function uptime {
    [CmdletBinding()]
    param()
    $isWindowsCompat = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')
    try {
        if ($isWindowsCompat) {
            $dateFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.ShortDatePattern
            $timeFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.LongTimePattern
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $bootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
            }
            else {
                $lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
                $bootTime = $lastBoot
            }
            $formattedBootTime = $bootTime.ToString("dddd, MMMM dd,yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) + " [$($bootTime.ToString("$dateFormat $timeFormat"))]"
            Write-Host "System started on: $formattedBootTime" -ForegroundColor DarkGray
            $uptimeSpan = (Get-Date) - $bootTime
        }
        else {
            # Linux/macOS: read /proc/uptime
            $procUptime = [System.IO.File]::ReadAllText('/proc/uptime').Trim().Split()[0]
            $uptimeSeconds = [double]$procUptime
            $bootTime = (Get-Date).AddSeconds(-$uptimeSeconds)
            $uptimeSpan = New-TimeSpan -Seconds $uptimeSeconds
            Write-Host "System started on: $($bootTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor DarkGray
        }
        Write-Host ("Uptime: {0} days, {1} hours, {2} minutes, {3} seconds" -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes, $uptimeSpan.Seconds) -ForegroundColor Blue
    }
    catch {
        Write-Error "An error occurred while retrieving system uptime. $_"
    }
}

function Use-Env {
    <#
    .SYNOPSIS
    Loads environment variables from a .env file into the PowerShell session.
    .DESCRIPTION
    Reads a .env file and sets environment variables. Supports comments, blank lines,
    export prefixes, and single/double-quoted values. Does not force APP_ENV.
    .PARAMETER Path
    Path to the .env file. Defaults to '.env' in the current directory.
    .EXAMPLE
    Use-Env
    .EXAMPLE
    Use-Env -Path '.env.local'
    #>
    [CmdletBinding()]
    param(
        [string]$Path = '.env'
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Verbose "No .env file found at '$Path'."
        return
    }
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*#') { continue }
        # Strip optional 'export ' prefix
        $line = $line -replace '^\s*export\s+', ''
        if ($line -match '^\s*([^=]+?)\s*=(.*)$') {
            $varName = $Matches[1].Trim()
            $varValue = $Matches[2].Trim()
            # Strip surrounding single or double quotes
            if ($varValue -match "^'(.*)'$" -or $varValue -match '^"(.*)"$') {
                $varValue = $Matches[1]
            }
            Set-Item -Path "env:$varName" -Value $varValue
            Write-Verbose "Set $varName"
        }
    }
}

# Aliases moved to the end of the profile script for the main session.
# If these functions were slow, their aliases wouldn't be available immediately.
# These aliases will be loaded into the global scope by the main profile script.
# Set-Alias -Name c -Value Clear-Host
# Set-Alias -Name ls -Value Get-ChildItem

Set-Alias k kubectl
Set-Alias kctx kubectx

function kcinfo {
    kubectl cluster-info @args
}

function Get-ProcessPort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port
    )

    $isWindowsCompat = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')
    if (-not $isWindowsCompat) {
        Write-Warning "Get-ProcessPort requires Windows (uses Get-NetTCPConnection)."
        return
    }

    Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
        Where-Object OwningProcess -ne 0 |
        ForEach-Object {
            $process = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
            [pscustomobject]@{
                Port        = $_.LocalPort
                State       = $_.State
                ProcessId   = $_.OwningProcess
                ProcessName = $process.ProcessName
                Path        = $process.Path
            }
        }
}

function Stop-ProcessPort {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port
    )

    $isWindowsCompat = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')
    if (-not $isWindowsCompat) {
        Write-Warning "Stop-ProcessPort requires Windows (uses Get-NetTCPConnection)."
        return
    }

    Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
        Where-Object OwningProcess -ne 0 |
        Select-Object -ExpandProperty OwningProcess -Unique |
        ForEach-Object {
            if ($PSCmdlet.ShouldProcess("process ID $_ listening on port $Port", 'Stop')) {
                Stop-Process -Id $_ -Force
            }
        }
}
