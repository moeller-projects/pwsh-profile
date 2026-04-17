[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSCommandPath),
    [string]$ProfilePath = $PROFILE
)

<#
.SYNOPSIS
    Sets up a symbolic link for the PowerShell profile.
.DESCRIPTION
    Creates a symbolic link from the repository's profile.ps1 to the target PowerShell profile path.
    Supports -WhatIf/-Confirm for safe validation and can be dot-sourced in tests without executing the main routine.
#>

function Write-SetupLog {
    [CmdletBinding()]
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
        'WARNING'  { Write-Warning $Message }
        'ERROR'    { Write-Error $Message }
        'CRITICAL' { Write-Error "[CRITICAL] $Message" }
    }
}

function Get-SetupSourceProfilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RootPath
    )

    return (Join-Path -Path $RootPath -ChildPath 'profile.ps1')
}

function Ensure-SetupDirectory {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [string]$DirectoryPath
    )

    if (Test-Path -LiteralPath $DirectoryPath) {
        Write-SetupLog -Level DEBUG -Message "Target directory already exists: $DirectoryPath"
        return
    }

    Write-SetupLog -Level INFO -Message "Creating target directory for the PowerShell profile: $DirectoryPath"
    if ($PSCmdlet.ShouldProcess($DirectoryPath, 'Create directory')) {
        New-Item -ItemType Directory -Path $DirectoryPath -Force -ErrorAction Stop | Out-Null
        Write-SetupLog -Level DEBUG -Message "Target directory created successfully: $DirectoryPath"
    }
}

function Remove-SetupExistingProfile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [string]$ExistingProfilePath
    )

    if (-not (Test-Path -LiteralPath $ExistingProfilePath)) {
        Write-SetupLog -Level DEBUG -Message 'No existing profile file found at the target path.'
        return
    }

    Write-SetupLog -Level INFO -Message "Existing profile file or link found at '$ExistingProfilePath'. Removing it..."
    if ($PSCmdlet.ShouldProcess($ExistingProfilePath, 'Remove existing profile')) {
        Remove-Item -LiteralPath $ExistingProfilePath -Force -Confirm:$false -ErrorAction Stop
        Write-SetupLog -Level DEBUG -Message "Previous profile file/link removed: $ExistingProfilePath"
    }
}

function New-SetupProfileSymbolicLink {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$Target
    )

    Write-SetupLog -Level INFO -Message "Creating symbolic link from '$Source' to '$Target'..."
    if ($PSCmdlet.ShouldProcess($Target, "Create symbolic link to '$Source'")) {
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source -Force -ErrorAction Stop | Out-Null
        Write-SetupLog -Level INFO -Message 'Success! The symbolic link has been set up.'
        Write-SetupLog -Level INFO -Message 'Your PowerShell profile will now be loaded directly from your repository.'
        Write-SetupLog -Level INFO -Message 'Restart PowerShell to use the new profile.'
    }
}

function Invoke-ProfileSetup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$ResolvedRepositoryRoot,
        [Parameter(Mandatory)][string]$ResolvedProfilePath
    )

    Write-SetupLog -Level INFO -Message '--- Setting up the PowerShell profile symbolic link ---'

    $sourceProfile = Get-SetupSourceProfilePath -RootPath $ResolvedRepositoryRoot
    Write-SetupLog -Level INFO -Message "Source profile in repository: $sourceProfile"
    Write-SetupLog -Level INFO -Message "Target profile path (default): $ResolvedProfilePath"

    if (-not (Test-Path -LiteralPath $sourceProfile -PathType Leaf)) {
        throw "The source profile file in the repository was not found at: $sourceProfile"
    }

    $targetProfileDirectory = Split-Path -Parent $ResolvedProfilePath
    Ensure-SetupDirectory -DirectoryPath $targetProfileDirectory -WhatIf:$WhatIfPreference -Confirm:$false
    Remove-SetupExistingProfile -ExistingProfilePath $ResolvedProfilePath -WhatIf:$WhatIfPreference -Confirm:$false
    New-SetupProfileSymbolicLink -Source $sourceProfile -Target $ResolvedProfilePath -WhatIf:$WhatIfPreference -Confirm:$false

    Write-SetupLog -Level INFO -Message '--- Setup complete ---'
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ProfileSetup -ResolvedRepositoryRoot $RepositoryRoot -ResolvedProfilePath $ProfilePath -WhatIf:$WhatIfPreference -Confirm:$false
        exit 0
    }
    catch {
        Write-SetupLog -Level ERROR -Message $_.Exception.Message
        Write-SetupLog -Level CRITICAL -Message 'Ensure the repository path is correct and that you have sufficient permissions to create symbolic links.'
        exit 1
    }
}
