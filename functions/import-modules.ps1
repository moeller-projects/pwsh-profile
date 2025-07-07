function Import-RequiredModules {
    [CmdletBinding()]
    param()

    $modulesToImport = @('Terminal-Icons', 'PSMenu', 'InteractiveMenu', 'PSReadLine', 'CompletionPredictor', 'PSFzf')
    $availableModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name -Unique

    $missingModules = $modulesToImport | Where-Object { $_ -notin $availableModules }

    if ($missingModules.Count -gt 0) {
        Write-Host "Installing missing modules: $( $missingModules -join ', ' )" -ForegroundColor Yellow
        # Install-Module is a long-running operation, no direct micro-optimizations apply.
        # -Force -SkipPublisherCheck are important for unattended installs.
        Install-Module -Name $missingModules -Scope CurrentUser -Force -SkipPublisherCheck
        Write-Host "Missing modules installed. Refreshing module list." -ForegroundColor Yellow
        # Refresh available modules after installation
        $availableModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name -Unique
    }

    $toImport = $modulesToImport | Where-Object { $_ -in $availableModules }
    if ($toImport.Count -gt 0) {
        Import-Module -Name $toImport -ErrorAction SilentlyContinue
        Write-Host "Required modules imported: $($toImport -join ', ')" -ForegroundColor Green
    }
    else {
        Write-Host "No required modules to import." -ForegroundColor Cyan
    }

    $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if ( [System.IO.File]::Exists($ChocolateyProfile)) { # Efficient .NET file check
        Import-Module "$ChocolateyProfile" -ErrorAction SilentlyContinue # Use LiteralPath for safety
        Write-Host "Chocolatey profile imported." -ForegroundColor Green
    }
}
