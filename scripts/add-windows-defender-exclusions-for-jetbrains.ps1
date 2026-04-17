<#PSScriptInfo

.VERSION 0.2.0
.GUID 425bb0f7-42ee-4ed8-8f5d-4a6fcd805dd9
.AUTHOR moeller-projects
.COMPANYNAME moeller-projects
.COPYRIGHT (c) moeller-projects. All rights reserved.
.TAGS powershell windows defender jetbrains wsl
.LICENSEURI https://github.com/moeller-projects/pwsh-profile/blob/main/LICENSE
.PROJECTURI https://github.com/moeller-projects/pwsh-profile
.RELEASENOTES Added WhatIf support and safer platform/admin validation.

#>
<#
.SYNOPSIS
    Adds Windows Defender exclusions and WSL firewall adjustments for JetBrains IDE workflows.
.DESCRIPTION
    Interactively selects an IDE and optional WSL paths, then adds Defender exclusions and firewall changes with -WhatIf/-Confirm support.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param()

if (-not $IsWindows) {
    Write-Error 'This script is only supported on Windows.'
    exit 1
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Error 'This script must be run as Administrator.'
    exit 1
}

$ides = @('PhpStorm', 'IntelliJ', 'PyCharm', 'RubyMine', 'WebStorm', 'DataGrip', 'GoLand', 'Rider', 'Other')
$idePrompt = "Please select your IDE by typing the corresponding number:`n"
for ($i = 0; $i -lt $ides.Length; $i++) {
    $idePrompt += "$i. $($ides[$i])`n"
}

$ideIndexRaw = Read-Host $idePrompt
if (-not ($ideIndexRaw -match '^\d+$') -or [int]$ideIndexRaw -ge $ides.Length) {
    Write-Error 'Invalid selection.'
    exit 1
}

$selectedIDE = $ides[[int]$ideIndexRaw]
$processName = switch ($selectedIDE) {
    'PhpStorm' { 'phpstorm64.exe' }
    'IntelliJ' { 'idea64.exe' }
    'PyCharm'  { 'pycharm64.exe' }
    'RubyMine' { 'rubymine64.exe' }
    'WebStorm' { 'webstorm64.exe' }
    'DataGrip' { 'datagrip64.exe' }
    'GoLand'   { 'goland64.exe' }
    'Rider'    { 'rider64.exe' }
    'Other'    { Read-Host 'Please enter the process name for your IDE (e.g., webstorm64.exe)' }
}

$linuxDistro = Read-Host 'Enter your WSL distro name (e.g., Ubuntu). Leave blank to skip WSL path exclusions'
$linuxUsername = if ($linuxDistro) { Read-Host 'Enter your Linux username (e.g., yourname)' } else { '' }

$foldersToExclude = @(
    "C:\Users\$env:USERNAME\AppData\Local\JetBrains",
    'C:\Program Files\Docker',
    'C:\Program Files\JetBrains'
)

if ($linuxDistro -and $linuxUsername) {
    $foldersToExclude += @(
        "\\wsl$\$linuxDistro\home\$linuxUsername\src",
        "\\wsl.localhost\$linuxDistro\home\$linuxUsername\src"
    )
}

$fileTypesToExclude = @('vhd', 'vhdx')
$processesToExclude = @(
    $processName,
    'fsnotifier.exe',
    'jcef_helper.exe',
    'jetbrains-toolbox.exe',
    'docker.exe',
    'com.docker.*.*',
    'Desktop Docker.exe',
    'wsl.exe',
    'wslhost.exe',
    'vmmemWSL'
)

Write-Host 'Adding firewall rules for WSL. This step may take a few minutes...'
try {
    $wslAdapter = Get-NetAdapter -IncludeHidden |
        Where-Object { $_.Status -ne 'Disconnected' -and ($_.Name -like 'vEthernet (WSL*' -or $_.InterfaceDescription -like '*WSL*') } |
        Select-Object -First 1

    if ($wslAdapter) {
        $alias = if ($wslAdapter.InterfaceAlias) { $wslAdapter.InterfaceAlias } else { $wslAdapter.Name }
        if (-not (Get-NetFirewallRule -DisplayName 'WSL' -ErrorAction SilentlyContinue) -and $PSCmdlet.ShouldProcess('WSL firewall rule', 'Create firewall rule')) {
            New-NetFirewallRule -DisplayName 'WSL' -Direction Inbound -InterfaceAlias $alias -Action Allow -Profile Any -Enabled True | Out-Null
        }
    }
    else {
        Write-Host 'WSL network adapter not found; skipping WSL-specific firewall rule.'
    }

    if ($PSCmdlet.ShouldProcess($selectedIDE, 'Disable public firewall rules for selected IDE')) {
        Get-NetFirewallProfile -Name Public | Get-NetFirewallRule | Where-Object DisplayName -ILike "$($selectedIDE)*" | Disable-NetFirewallRule
    }
}
catch {
    Write-Error "Error adding firewall rule: $($_.Exception.Message)"
}

Write-Host 'Adding folder exclusions...'
foreach ($folder in $foldersToExclude) {
    if ($PSCmdlet.ShouldProcess($folder, 'Add Defender path exclusion')) {
        Add-MpPreference -ExclusionPath $folder
    }
}

Write-Host 'Adding file type exclusions...'
foreach ($fileType in $fileTypesToExclude) {
    if ($PSCmdlet.ShouldProcess($fileType, 'Add Defender extension exclusion')) {
        Add-MpPreference -ExclusionExtension $fileType
    }
}

Write-Host 'Adding process exclusions...'
foreach ($process in $processesToExclude) {
    if ($PSCmdlet.ShouldProcess($process, 'Add Defender process exclusion')) {
        Add-MpPreference -ExclusionProcess $process
    }
}

Write-Host 'Script execution completed.'
