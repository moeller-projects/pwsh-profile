function Import-RequiredModules {
    [CmdletBinding()]
    param()

    $modulesToImport = @('Terminal-Icons', 'PSMenu', 'InteractiveMenu', 'PSReadLine', 'CompletionPredictor', 'PSFzf')
    $availableModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name -Unique

    $missingModules = $modulesToImport | Where-Object { $_ -notin $availableModules }

    if ($missingModules.Count -gt 0) {
        if ($env:PWSH_PROFILE_AUTO_INSTALL -eq '1') {
            Write-Verbose "Installing missing modules: $( $missingModules -join ', ' )"
            # Install-Module is a long-running operation, no direct micro-optimizations apply.
            # -Force -SkipPublisherCheck are important for unattended installs.
            Install-Module -Name $missingModules -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
            Write-Verbose "Missing modules installed. Refreshing module list."
            # Refresh available modules after installation
            $availableModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name -Unique
        }
        else {
            Write-Verbose "Missing modules not installed (PWSH_PROFILE_AUTO_INSTALL != '1'): $( $missingModules -join ', ' )"
        }
    }

    $toImport = $modulesToImport | Where-Object { $_ -in $availableModules }
    if ($toImport.Count -gt 0) {
        Import-Module -Name $toImport -ErrorAction SilentlyContinue
        Write-Verbose "Required modules imported: $($toImport -join ', ')"
    }
    else {
        Write-Verbose "No required modules to import."
    }

    $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if ( [System.IO.File]::Exists($ChocolateyProfile)) { # Efficient .NET file check
        Import-Module "$ChocolateyProfile" -ErrorAction SilentlyContinue # Use LiteralPath for safety
        Write-Verbose "Chocolatey profile imported."
    }
}
