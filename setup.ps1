# Setup-PowerShellProfile.ps1

<#
.SYNOPSIS
    Sets up a symbolic link for the PowerShell profile.
    Assumes the repository has already been cloned.

.DESCRIPTION
    This script creates a symbolic link from the profile file
    in your cloned repository to the default PowerShell profile path ($PROFILE).
    It ensures that the target directory exists and removes any
    existing profile file before creating the link.

.NOTES
    Must be run with administrator privileges to create symbolic links.
    The path to the repository profile may need to be adjusted.
#>
$ScriptPath = $MyInvocation.MyCommand.Path

function Write-Log {
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
    param (
        [Parameter(Mandatory)]
        [string]$DirectoryPath
    )
    if (-not (Test-Path $DirectoryPath)) {
        Write-Log -Level INFO -Message "Creating target directory for the PowerShell profile: $DirectoryPath"
        try {
            New-Item -ItemType Directory -Path $DirectoryPath -Force | Out-Null
            Write-Log -Level DEBUG -Message "Target directory created successfully: $DirectoryPath"
        }
        catch {
            Write-Log -Level ERROR -Message "Error creating target directory '$DirectoryPath': $($_.Exception.Message)"
            Write-Log -Level CRITICAL -Message "Ensure you have the necessary permissions."
            exit 1
        }
    } else {
        Write-Log -Level DEBUG -Message "Target directory already exists: $DirectoryPath"
    }
}

function Remove-ExistingProfile {
    param (
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )
    if (Test-Path $ProfilePath) {
        Write-Log -Level INFO -Message "Existing profile file or link found at '$ProfilePath'. Removing it..."
        try {
            Remove-Item $ProfilePath -Force -Confirm:$false
            Write-Log -Level DEBUG -Message "Previous profile file/link removed: $ProfilePath"
        }
        catch {
            Write-Log -Level ERROR -Message "Error removing existing profile file '$ProfilePath': $($_.Exception.Message)"
            Write-Log -Level CRITICAL -Message "The file may still be in use or you may not have sufficient permissions."
            exit 1
        }
    } else {
        Write-Log -Level DEBUG -Message "No existing profile file found at the target path."
    }
}

function New-ProfileSymbolicLink {
    param (
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$Target
    )
    Write-Log -Level INFO -Message "Creating symbolic link from '$Source' to '$Target'..."
    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source -Force | Out-Null
        Write-Log -Level INFO -Message "Success! The symbolic link has been set up."
        Write-Log -Level INFO -Message "Your PowerShell profile will now be loaded directly from your repository."
        Write-Log -Level INFO -Message "Restart PowerShell to use the new profile."
    }
    catch {
        Write-Log -Level ERROR -Message "Error creating symbolic link: $($_.Exception.Message)"
        Write-Log -Level CRITICAL -Message "Ensure you are running the script with administrator privileges."
        exit 1
    }
}

function Main {
    param($ScriptPath)
    if (-not $ScriptPath) {
        Write-Error "This script must be run, not dot-sourced or pasted. Please execute it as a file."
        exit 1
    }

    Write-Log -Level INFO -Message "--- Setting up the PowerShell profile symbolic link ---"

    $RepoRoot = Split-Path -Parent $ScriptPath
    $SourceProfile = Join-Path -Path $RepoRoot -ChildPath "profile.ps1" # Adjust "Profile" if needed
    $TargetProfile = $PROFILE

    Write-Log -Level INFO -Message "Source profile in repository: $SourceProfile"
    Write-Log -Level INFO -Message "Target profile path (default): $TargetProfile"
    Write-Log -Level DEBUG -Message "Checking existence of source profile file..."

    if (-not (Test-Path $SourceProfile -PathType Leaf)) {
        Write-Log -Level ERROR -Message "Error: The source profile file in the repository was not found at: $SourceProfile"
        Write-Log -Level CRITICAL -Message "Please ensure the repository is cloned and the path '$SourceProfile' is correct."
        exit 1
    }

    $TargetProfileDirectory = Split-Path $TargetProfile -Parent
    New-DirectoryIfMissing -DirectoryPath $TargetProfileDirectory
    Remove-ExistingProfile -ProfilePath $TargetProfile
    New-ProfileSymbolicLink -Source $SourceProfile -Target $TargetProfile

    Write-Log -Level INFO -Message "--- Setup complete ---"
}

Main $ScriptPath
