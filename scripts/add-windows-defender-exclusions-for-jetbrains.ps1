# PowerShell script to add Windows Defender exclusions for WSL2 and JetBrains IDE performance issues
#
# For context please read this thread:
# https://github.com/microsoft/WSL/issues/8995
#
# How to use?
# - Save the Script: Open a text editor like Notepad and paste the PowerShell script into it.
# - Save the file with a .ps1 extension, for example, Add_WindowsDefender_Exclusions.ps1.
# - Run PowerShell as Administrator: Search for "PowerShell" in the Start menu, right-click on it, and choose "Run as administrator".
# - Navigate to the Script's Location: Use the cd command to navigate to the directory where you saved the .ps1 file.
# - Run the Script: Type .\Add_WindowsDefender_Exclusions.ps1 and press Enter. This will execute the script.
# - You will be prompted to enter your WSL distro (tested only on Ubuntu), username and IDE of choice

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "This script must be run as Administrator. Exiting."
    return
}

# Display IDE choices and prompt user to pick one
$ides = @("PhpStorm", "IntelliJ", "PyCharm", "RubyMine", "WebStorm", "DataGrip", "GoLand", "Rider", "Other")
$idePrompt = "Please select your IDE by typing the corresponding number:`n"
for ($i=0; $i -lt $ides.Length; $i++) {
    $idePrompt += "$i. $($ides[$i])`n"
}
$ideIndexRaw = Read-Host $idePrompt
if (-not ($ideIndexRaw -match '^\d+$') -or [int]$ideIndexRaw -ge $ides.Length) { Write-Error "Invalid selection"; return }
$ideIndex = [int]$ideIndexRaw
$selectedIDE = $ides[$ideIndex]

# Determine process based on IDE choice
$process = switch ($selectedIDE) {
    'PhpStorm' { "phpstorm64.exe" }
    'IntelliJ' { "idea64.exe" }
    'PyCharm'  { "pycharm64.exe" }
    'RubyMine' { "rubymine64.exe" }
    'WebStorm' { "webstorm64.exe" }
    'DataGrip' { "datagrip64.exe" }
    'GoLand'   { "goland64.exe" }
    'Rider'    { "rider64.exe" }
    'Other'    { Read-Host "Please enter the process name for your IDE (e.g., webstorm64.exe)" }
}
# Prompt for WSL distro and Linux username (optional; leave blank to skip WSL path exclusions)
$linuxDistro = Read-Host "Enter your WSL distro name (e.g., Ubuntu). Leave blank to skip WSL path exclusions"
$linuxUsername = if ($linuxDistro) { Read-Host "Enter your Linux username (e.g., yourname)" } else { "" }

# Define folders to exclude, adjust if needed
$foldersToExclude = @(
    "C:\Users\$env:USERNAME\AppData\Local\JetBrains",
    "C:\Program Files\Docker",
    "C:\Program Files\JetBrains"
)

if ($linuxDistro -and $linuxUsername) {
    $wslPaths = @(
        "\\wsl$\$linuxDistro\home\$linuxUsername\src",
        "\\wsl.localhost\$linuxDistro\home\$linuxUsername\src"
    )
    $foldersToExclude += $wslPaths
}

# Define file types to exclude, adjust if needed
$fileTypesToExclude = @(
    "vhd",
    "vhdx"
)

# Define processes to exclude, adjust if needed
$processesToExclude = @(
    $process, # The process name based on the IDE choice
    "fsnotifier.exe",
    "jcef_helper.exe",
    "jetbrains-toolbox.exe",
    "docker.exe",
    "com.docker.*.*",
    "Desktop Docker.exe",
    "wsl.exe",
    "wslhost.exe",
    "vmmemWSL"
)

# Add Firewall Rule for WSL
# For details please read official documentation:
# https://www.jetbrains.com/help/idea/how-to-use-wsl-development-environment-in-product.html#debugging_system_settings
Write-Host "Adding firewall rules for WSL. This step may take a few minutes..."
try {
    $wslAdapter = Get-NetAdapter -IncludeHidden |
        Where-Object { $_.Status -ne 'Disconnected' -and ($_.Name -like 'vEthernet (WSL*' -or $_.InterfaceDescription -like '*WSL*') } |
        Select-Object -First 1

    if ($wslAdapter) {
        $alias = if ($wslAdapter.InterfaceAlias) { $wslAdapter.InterfaceAlias } else { $wslAdapter.Name }
        if (-not (Get-NetFirewallRule -DisplayName "WSL" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName "WSL" -Direction Inbound -InterfaceAlias $alias -Action Allow -Profile Any -Enabled True
        } else {
            Write-Host "Firewall rule 'WSL' already exists."
        }
    } else {
        Write-Host "WSL network adapter not found; skipping WSL-specific firewall rule."
    }

    Get-NetFirewallProfile -Name Public | Get-NetFirewallRule | Where-Object DisplayName -ILike "$($selectedIDE)*" | Disable-NetFirewallRule
} catch {
    Write-Host "Error adding firewall rule: $_"
}

# Add folder exclusions
Write-Host "Adding folder exclusions..."
foreach ($folder in $foldersToExclude) {
    Add-MpPreference -ExclusionPath $folder
}

# Add file type exclusions
Write-Host "Adding file type exclusions..."
foreach ($fileType in $fileTypesToExclude) {
    Add-MpPreference -ExclusionExtension $fileType
}

# Add process exclusions
Write-Host "Adding process exclusions..."
foreach ($process in $processesToExclude) {
    Add-MpPreference -ExclusionProcess $process
}

Write-Host "Script execution completed."
