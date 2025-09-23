$global:ProjectPaths = @(
    "D:\projects\aveato",
    "D:\projects\laekkerai",
    "D:\projects\private",
    "D:\projects\research"
)

# Custom argument completer for substring matching
Register-ArgumentCompleter -CommandName Enter-ProjectDirectory -ParameterName ProjectName -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $matches = foreach ($projectPath in $global:ProjectPaths) {
        if (Test-Path $projectPath) {
            Get-ChildItem -Path $projectPath -Directory | ForEach-Object {
                $relativePath = $_.BaseName
                if ($relativePath -like "*$wordToComplete*") {
                    [System.Management.Automation.CompletionResult]::new(
                        $relativePath, $relativePath, 'ParameterValue', $relativePath
                    )
                }
            }
        }
    }

    return $matches
}

function Enter-ProjectDirectory {
    [CmdletBinding()]
    [Alias("project", "p")]
    param(
        [string] $ProjectName
    )

    foreach ($projectPath in $global:ProjectPaths) {
        # Use .NET Path.Combine for performance
        $fullProjectPath = [System.IO.Path]::Combine($projectPath, $ProjectName)
        if ([System.IO.Directory]::Exists($fullProjectPath)) {
            # Use .NET for directory check
            Set-Location -Path $fullProjectPath
            Get-ChildItem # Keep Get-ChildItem as it's a common interactive action here
            return
        }
    }
}

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
    param()
    Write-Host "Clearing cache..." -ForegroundColor Cyan

    $isWindowsCompat = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')
    if (-not $isWindowsCompat) {
        Write-Warning "Clear-Cache currently supports Windows only."
        return
    }

    # Using Remove-Item (cmdlet) with confirmation support
    if ($PSCmdlet.ShouldProcess("Windows Prefetch")) {
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

function pkill($name) { Get-Process $name -ErrorAction SilentlyContinue | Stop-Process }
function pgrep($name) { Get-Process $name -ErrorAction SilentlyContinue }
function Stop-ProcessForce {
    [CmdletBinding()]
    [Alias('k9')]
    param(
        [Parameter(Mandatory)][string]$Name
    )
    Stop-Process -Name $Name -Force -ErrorAction SilentlyContinue
}
function sysinfo { Get-ComputerInfo }
function flushdns {
    Clear-DnsClientCache
    Write-Information "DNS has been flushed"
}
function which($name) { Get-Command $name | Select-Object -ExpandProperty Definition }
function export($name, $value) { set-item -force -path "env:$name" -value $value }

function uptime {
    [CmdletBinding()]
    param()
    try {
        # Using .NET for DateTimeFormat properties to avoid locale issues
        $dateFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.ShortDatePattern
        $timeFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.LongTimePattern

        # Prefer Get-CimInstance for system info over Get-WmiObject for PowerShell 6+
        # However, win32_operatingsystem is common, so keeping WMI for PS 5 compatibility check.
        # For PS 7+, (Get-CimInstance Win32_OperatingSystem).LastBootUpTime is more direct
        # and avoids parsing 'net statistics workstation' string.
        $bootTime = $null
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            # Optimized for PS6+
            $bootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        }
        else {
            # For PS5, use WMI
            $lastBoot = (Get-WmiObject win32_operatingsystem).LastBootUpTime
            $bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastBoot)
        }

        $formattedBootTime = $bootTime.ToString("dddd, MMMM dd,yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) + " [$($bootTime.ToString("$dateFormat $timeFormat"))]"
        Write-Host "System started on: $formattedBootTime" -ForegroundColor DarkGray

        $uptime = (Get-Date) - $bootTime
        Write-Host ("Uptime: {0} days, {1} hours, {2} minutes, {3} seconds" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds) -ForegroundColor Blue
    }
    catch {
        Write-Error "An error occurred while retrieving system uptime. $_"
    }
}

# Aliases moved to the end of the profile script for the main session.
# If these functions were slow, their aliases wouldn't be available immediately.
# These aliases will be loaded into the global scope by the main profile script.
# Set-Alias -Name c -Value Clear-Host
# Set-Alias -Name ls -Value Get-ChildItem
# Set-Alias -Name .. -Value goToParent
# Set-Alias -Name ... -Value goToParent2Levels
# Set-Alias -Name ~ -Value goToHome
