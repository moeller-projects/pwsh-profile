# Setup-PowerShellProfile.ps1

<#
.SYNOPSIS
    Sets up a symbolic link (or loader file) for the PowerShell profile.

.DESCRIPTION
    Creates a symbolic link from the profile file in your cloned repository to
    the default PowerShell profile path ($PROFILE). If symlink creation fails
    (e.g. due to missing admin rights), it automatically falls back to writing
    a one-line loader file.

    Use -NoSymlink to skip symlink creation and always write the loader file.

.PARAMETER NoSymlink
    Write a one-line loader (`. <repo>\profile.ps1`) instead of creating a
    symbolic link. Works without administrator rights.

.NOTES
    Symlink creation on Windows typically requires administrator privileges.
    Any existing $PROFILE file is backed up with a .bak-<timestamp> suffix.
#>
param(
    [switch]$NoSymlink
)

$ScriptPath = $MyInvocation.MyCommand.Path

function Write-SetupLog {
    param (
        [Parameter(Mandatory)]
        [ValidateSet('DEBUG','INFO','WARNING','ERROR','CRITICAL')]
        [string]$Level,
        [Parameter(Mandatory)]
        [string]$Message
    )
    switch ($Level) {
        'DEBUG'    { Write-Host "[DEBUG] $Message" -ForegroundColor DarkGray }
        'INFO'     { Write-Host "[INFO]  $Message" -ForegroundColor Green }
        'WARNING'  { Write-Warning "$Message" }
        'ERROR'    { Write-Error "$Message" }
        'CRITICAL' { Write-Error "[CRITICAL] $Message" }
    }
}

function New-DirectoryIfMissing {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$DirectoryPath
    )
    if (-not (Test-Path $DirectoryPath)) {
        Write-SetupLog -Level INFO -Message "Creating target directory for the PowerShell profile: $DirectoryPath"
        try {
            New-Item -ItemType Directory -Path $DirectoryPath -Force | Out-Null
            Write-SetupLog -Level DEBUG -Message "Target directory created successfully: $DirectoryPath"
        }
        catch {
            Write-SetupLog -Level ERROR -Message "Error creating target directory '$DirectoryPath': $($_.Exception.Message)"
            Write-SetupLog -Level CRITICAL -Message "Ensure you have the necessary permissions."
            exit 1
        }
    } else {
        Write-SetupLog -Level DEBUG -Message "Target directory already exists: $DirectoryPath"
    }
}

function Backup-ExistingProfile {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )
    if (Test-Path $ProfilePath) {
        $timestamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
        $backupPath = "$ProfilePath.bak-$timestamp"
        Write-SetupLog -Level INFO -Message "Backing up existing profile to '$backupPath'..."
        try {
            Copy-Item -Path $ProfilePath -Destination $backupPath -Force
            Write-SetupLog -Level DEBUG -Message "Backup created: $backupPath"
        }
        catch {
            Write-SetupLog -Level WARNING -Message "Could not back up existing profile: $($_.Exception.Message)"
        }
        try {
            Remove-Item $ProfilePath -Force -Confirm:$false
            Write-SetupLog -Level DEBUG -Message "Previous profile file/link removed: $ProfilePath"
        }
        catch {
            Write-SetupLog -Level ERROR -Message "Error removing existing profile file '$ProfilePath': $($_.Exception.Message)"
            Write-SetupLog -Level CRITICAL -Message "The file may still be in use or you may not have sufficient permissions."
            exit 1
        }
    } else {
        Write-SetupLog -Level DEBUG -Message "No existing profile file found at the target path."
    }
}

function New-ProfileSymbolicLink {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$Target
    )
    Write-SetupLog -Level INFO -Message "Creating symbolic link from '$Source' to '$Target'..."
    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source -Force | Out-Null
        Write-SetupLog -Level INFO -Message "Success! The symbolic link has been set up."
        Write-SetupLog -Level INFO -Message "Your PowerShell profile will now be loaded directly from your repository."
        Write-SetupLog -Level INFO -Message "Restart PowerShell to use the new profile."
        return $true
    }
    catch {
        Write-SetupLog -Level WARNING -Message "Symlink creation failed: $($_.Exception.Message)"
        return $false
    }
}

function New-ProfileLoaderFile {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$Target
    )
    Write-SetupLog -Level INFO -Message "Writing loader file to '$Target'..."
    try {
        ". `"$Source`"" | Set-Content -Path $Target -Encoding UTF8
        Write-SetupLog -Level INFO -Message "Loader file created at '$Target'."
        Write-SetupLog -Level INFO -Message "Restart PowerShell to use the new profile."
    }
    catch {
        Write-SetupLog -Level ERROR -Message "Error creating loader file '$Target': $($_.Exception.Message)"
        exit 1
    }
}

function Main {
    param($ScriptPath)
    if (-not $ScriptPath) {
        Write-Error "This script must be run, not dot-sourced or pasted. Please execute it as a file."
        exit 1
    }

    Write-SetupLog -Level INFO -Message "--- Setting up the PowerShell profile symbolic link ---"

    $RepoRoot = Split-Path -Parent $ScriptPath
    $SourceProfile = Join-Path -Path $RepoRoot -ChildPath "profile.ps1"
    $TargetProfile = $PROFILE

    Write-SetupLog -Level INFO -Message "Source profile in repository: $SourceProfile"
    Write-SetupLog -Level INFO -Message "Target profile path (default): $TargetProfile"

    if (-not (Test-Path $SourceProfile -PathType Leaf)) {
        Write-SetupLog -Level ERROR -Message "Error: The source profile file was not found at: $SourceProfile"
        Write-SetupLog -Level CRITICAL -Message "Please ensure the repository is cloned and the path '$SourceProfile' is correct."
        exit 1
    }

    $TargetProfileDirectory = Split-Path $TargetProfile -Parent
    New-DirectoryIfMissing -DirectoryPath $TargetProfileDirectory
    Backup-ExistingProfile -ProfilePath $TargetProfile

    if (-not $NoSymlink) {
        $symSuccess = New-ProfileSymbolicLink -Source $SourceProfile -Target $TargetProfile
        if (-not $symSuccess) {
            Write-SetupLog -Level WARNING -Message "Falling back to loader file (no admin rights required)."
            New-ProfileLoaderFile -Source $SourceProfile -Target $TargetProfile
        }
    }
    else {
        New-ProfileLoaderFile -Source $SourceProfile -Target $TargetProfile
    }

    Write-SetupLog -Level INFO -Message "--- Setup complete ---"
}

Main $ScriptPath
