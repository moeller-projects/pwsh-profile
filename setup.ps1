#Requires -Version 5.1

<#
.SYNOPSIS
    Sets up the PowerShell profile, dependencies, and local environment.

.DESCRIPTION
    Creates a symbolic link to profile.ps1 or a one-line loader file.
    Installs required PowerShell modules and optionally installs optional
    modules. Configures profile environment variables for the current user.

    On Windows, environment variables are persisted in the user environment.
    On Unix-like systems, they are written to:
        ~/.config/pwsh-profile/environment.ps1

.PARAMETER NoSymlink
    Write a one-line loader instead of creating a symbolic link.

.PARAMETER Prompt
    Prompt engine: None, Starship, or OhMyPosh.

.PARAMETER EnablePSReadLine
    Enable PSReadLine configuration.

.PARAMETER EnableCompletions
    Enable shell completions.

.PARAMETER EnableOptionalModules
    Import optional PowerShell modules.

.PARAMETER EnableGitWorktree
    Enable git-wt shell integration.

.PARAMETER Prediction
    PSReadLine prediction source: History or Plugin.

.PARAMETER SkipDependencyInstallation
    Do not install missing PowerShell modules.

.PARAMETER Force
    Reinstall or update dependencies where supported.
#>

[CmdletBinding()]
param(
    [switch]$NoSymlink,

    [ValidateSet('None', 'Starship', 'OhMyPosh')]
    [string]$Prompt = 'Starship',

    [bool]$EnablePSReadLine = $true,

    [bool]$EnableCompletions = $true,

    [bool]$EnableOptionalModules = $true,

    [bool]$EnableGitWorktree = $false,

    [ValidateSet('History', 'Plugin')]
    [string]$Prediction = 'Plugin',

    [switch]$SkipDependencyInstallation,

    [switch]$Force
)

$ScriptPath = $MyInvocation.MyCommand.Path

$RequiredModules = @(
    'PSReadLine'
)

$OptionalModules = @(
    'PSMenu'
    'InteractiveMenu'
    'CompletionPredictor'
    'ImportDotEnv'
    'Terminal-Icons'
    'PSFzf'
)

$ExternalTools = @(
    'git'
    'fzf'
    'starship'
    'oh-my-posh'
    'zoxide'
    'mise'
    'volta'
    'pixi'
    'kiro'
    'kubectl'
    'az'
    'dotnet'
    'eza'
    'lumen'
    'git-wt'
)

function Write-SetupLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    switch ($Level) {
        'DEBUG' {
            Write-Host "[DEBUG] $Message" -ForegroundColor DarkGray
        }
        'INFO' {
            Write-Host "[INFO]  $Message" -ForegroundColor Green
        }
        'WARNING' {
            Write-Warning $Message
        }
        'ERROR' {
            Write-Error $Message
        }
        'CRITICAL' {
            Write-Error "[CRITICAL] $Message"
        }
    }
}

function New-DirectoryIfMissing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DirectoryPath
    )

    if (Test-Path -LiteralPath $DirectoryPath -PathType Container) {
        Write-SetupLog -Level DEBUG -Message "Directory already exists: $DirectoryPath"
        return
    }

    try {
        New-Item -ItemType Directory -Path $DirectoryPath -Force |
            Out-Null

        Write-SetupLog -Level INFO -Message "Created directory: $DirectoryPath"
    }
    catch {
        throw "Could not create directory '$DirectoryPath': $($_.Exception.Message)"
    }
}

function Install-PowerShellModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$Required
    )

    $installedModule = Get-Module -ListAvailable -Name $Name |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($installedModule -and -not $Force) {
        Write-SetupLog -Level DEBUG -Message "PowerShell module '$Name' is already installed."
        return $true
    }

    if ($SkipDependencyInstallation) {
        $level = if ($Required) { 'WARNING' } else { 'INFO' }
        Write-SetupLog -Level $level -Message "Skipping installation of PowerShell module '$Name'."
        return [bool]$installedModule
    }

    if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
        $message = "Install-Module is unavailable; cannot install '$Name'."

        if ($Required) {
            throw $message
        }

        Write-SetupLog -Level WARNING -Message $message
        return $false
    }

    try {
        if (-not (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
            Register-PSRepository -Default -ErrorAction Stop
        }

        $installParams = @{
            Name        = $Name
            Scope       = 'CurrentUser'
            Repository  = 'PSGallery'
            ErrorAction = 'Stop'
            Force       = $Force.IsPresent
        }

        if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            $installParams['AllowClobber'] = $true
        }

        Write-SetupLog -Level INFO -Message "Installing PowerShell module '$Name'..."
        Install-Module @installParams

        Write-SetupLog -Level INFO -Message "Installed PowerShell module '$Name'."
        return $true
    }
    catch {
        $message = "Failed to install PowerShell module '$Name': $($_.Exception.Message)"

        if ($Required) {
            throw $message
        }

        Write-SetupLog -Level WARNING -Message $message
        return $false
    }
}

function Install-ProfileDependencies {
    [CmdletBinding()]
    param()

    Write-SetupLog -Level INFO -Message 'Checking required PowerShell modules...'

    foreach ($moduleName in $RequiredModules) {
        $installed = Install-PowerShellModule -Name $moduleName -Required

        if (-not $installed) {
            throw "Required PowerShell module '$moduleName' is unavailable."
        }
    }

    if ($EnableOptionalModules) {
        Write-SetupLog -Level INFO -Message 'Checking optional PowerShell modules...'

        foreach ($moduleName in $OptionalModules) {
            Install-PowerShellModule -Name $moduleName |
                Out-Null
        }
    }

    Write-SetupLog -Level INFO -Message 'Checking external command-line tools...'

    $missingTools = @(
        foreach ($toolName in $ExternalTools) {
            if (-not (Get-Command $toolName -ErrorAction SilentlyContinue)) {
                $toolName
            }
        }
    )

    if ($missingTools.Count -gt 0) {
        Write-SetupLog -Level WARNING -Message (
            'The following external tools were not found in PATH: ' +
            ($missingTools -join ', ')
        )

        Write-SetupLog -Level INFO -Message (
            'Install these tools using your preferred package manager. ' +
            'The setup script does not install external CLI tools automatically.'
        )
    }
    else {
        Write-SetupLog -Level INFO -Message 'All checked external tools are available.'
    }
}

function Get-ProfileConfiguration {
    [CmdletBinding()]
    param()

    $configuration = [ordered]@{
        PWSH_PROMPT                 = $null
        PWSH_PREDICTION             = $null
        PWSH_PROFILE_PSREADLINE     = $null
        PWSH_PROFILE_COMPLETIONS    = $null
        PWSH_PROFILE_IMPORT_OPTIONAL = $null
        PWSH_PROFILE_GIT_WT         = $null
    }

    switch ($Prompt) {
        'Starship' {
            $configuration.PWSH_PROMPT = 'starship'
        }
        'OhMyPosh' {
            $configuration.PWSH_PROMPT = 'posh'
        }
        'None' {
            $configuration.PWSH_PROMPT = $null
        }
    }

    if ($Prediction -eq 'Plugin') {
        $configuration.PWSH_PREDICTION = 'plugin'
    }

    if ($EnablePSReadLine) {
        $configuration.PWSH_PROFILE_PSREADLINE = '1'
    }

    if ($EnableCompletions) {
        $configuration.PWSH_PROFILE_COMPLETIONS = '1'
    }

    if ($EnableOptionalModules) {
        $configuration.PWSH_PROFILE_IMPORT_OPTIONAL = '1'
    }

    if ($EnableGitWorktree) {
        $configuration.PWSH_PROFILE_GIT_WT = '1'
    }

    return $configuration
}

function Set-ProfileEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Configuration
    )

    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
        foreach ($entry in $Configuration.GetEnumerator()) {
            $name = [string]$entry.Key
            $value = $entry.Value

            if ($null -eq $value) {
                [Environment]::SetEnvironmentVariable(
                    $name,
                    $null,
                    [EnvironmentVariableTarget]::User
                )

                Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
                continue
            }

            [Environment]::SetEnvironmentVariable(
                $name,
                [string]$value,
                [EnvironmentVariableTarget]::User
            )

            Set-Item -Path "Env:$name" -Value ([string]$value)
        }

        Write-SetupLog -Level INFO -Message 'Profile environment variables configured for the current Windows user.'
        return
    }

    $configDirectory = Join-Path $HOME '.config/pwsh-profile'
    $configPath = Join-Path $configDirectory 'environment.ps1'

    New-DirectoryIfMissing -DirectoryPath $configDirectory

    $lines = @(
        '# Generated by setup.ps1. Do not edit manually.'
        '# Local machine configuration for pwsh-profile.'
        ''
    )

    foreach ($entry in $Configuration.GetEnumerator()) {
        $name = [string]$entry.Key
        $value = $entry.Value

        if ($null -eq $value) {
            $lines += "Remove-Item -Path 'Env:$name' -ErrorAction SilentlyContinue"
            continue
        }

        $escapedValue = ([string]$value).Replace("'", "''")
        $lines += "`$env:$name = '$escapedValue'"
    }

    Set-Content -LiteralPath $configPath -Value $lines -Encoding UTF8

    foreach ($entry in $Configuration.GetEnumerator()) {
        $name = [string]$entry.Key
        $value = $entry.Value

        if ($null -eq $value) {
            Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
        }
        else {
            Set-Item -Path "Env:$name" -Value ([string]$value)
        }
    }

    Write-SetupLog -Level INFO -Message "Profile environment written to '$configPath'."
}

function Backup-ExistingProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        Write-SetupLog -Level DEBUG -Message 'No existing profile found to back up.'
        return
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "$ProfilePath.bak-$timestamp"

    try {
        Copy-Item -LiteralPath $ProfilePath -Destination $backupPath -Force
        Write-SetupLog -Level INFO -Message "Backed up existing profile to '$backupPath'."
    }
    catch {
        throw "Could not back up existing profile: $($_.Exception.Message)"
    }

    try {
        Remove-Item -LiteralPath $ProfilePath -Force -ErrorAction Stop
    }
    catch {
        throw "Could not remove existing profile '$ProfilePath': $($_.Exception.Message)"
    }
}

function New-ProfileSymbolicLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Target
    )

    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source -Force -ErrorAction Stop |
            Out-Null

        Write-SetupLog -Level INFO -Message "Created profile symbolic link: '$Target' -> '$Source'."
        return $true
    }
    catch {
        Write-SetupLog -Level WARNING -Message "Could not create symbolic link: $($_.Exception.Message)"
        return $false
    }
}

function New-ProfileLoaderFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Target
    )

    try {
        $escapedSource = $Source.Replace("'", "''")
        ". '$escapedSource'" |
            Set-Content -LiteralPath $Target -Encoding UTF8 -ErrorAction Stop

        Write-SetupLog -Level INFO -Message "Created profile loader: '$Target'."
    }
    catch {
        throw "Could not create profile loader '$Target': $($_.Exception.Message)"
    }
}

function Main {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    $repoRoot = Split-Path -Parent $ScriptPath
    $sourceProfile = Join-Path $repoRoot 'profile.ps1'
    $targetProfile = $PROFILE

    Write-SetupLog -Level INFO -Message '--- Setting up PowerShell profile ---'
    Write-SetupLog -Level INFO -Message "Repository profile: $sourceProfile"
    Write-SetupLog -Level INFO -Message "Target profile:     $targetProfile"

    if (-not (Test-Path -LiteralPath $sourceProfile -PathType Leaf)) {
        throw "Repository profile not found: '$sourceProfile'."
    }

    Install-ProfileDependencies

    $configuration = Get-ProfileConfiguration
    Set-ProfileEnvironment -Configuration $configuration

    $targetDirectory = Split-Path -Parent $targetProfile
    New-DirectoryIfMissing -DirectoryPath $targetDirectory

    Backup-ExistingProfile -ProfilePath $targetProfile

    if (-not $NoSymlink) {
        $linkCreated = New-ProfileSymbolicLink `
            -Source $sourceProfile `
            -Target $targetProfile

        if (-not $linkCreated) {
            Write-SetupLog -Level WARNING -Message 'Falling back to a loader file.'
            New-ProfileLoaderFile -Source $sourceProfile -Target $targetProfile
        }
    }
    else {
        New-ProfileLoaderFile -Source $sourceProfile -Target $targetProfile
    }

    Write-SetupLog -Level INFO -Message 'Setup complete. Restart PowerShell to apply all changes.'
}

try {
    if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
        throw 'Run this script as a file; do not dot-source it.'
    }

    Main -ScriptPath $ScriptPath
}
catch {
    Write-SetupLog -Level CRITICAL -Message $_.Exception.Message
    exit 1
}
