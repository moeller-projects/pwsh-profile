function Import-RequiredModules {
    [CmdletBinding()]
    param()

    if ($env:PWSH_PROFILE_IMPORT_OPTIONAL -ne '1') {
        return
    }

    $modulesToImport = @(
        'PSMenu', 'InteractiveMenu', 'CompletionPredictor', 'ImportDotEnv',
        'Terminal-Icons', 'PSFzf'
    )
    $missingModules = @(
        foreach ($moduleName in $modulesToImport) {
            if (-not (Get-Module -ListAvailable -Name $moduleName)) {
                $moduleName
            }
        }
    )

    if ($missingModules) {
        Write-Warning "The following optional modules are not installed: $($missingModules -join ', '). Run: Install-Module -Name $($missingModules -join ', ') -Scope CurrentUser"
    }

    Import-Module -Name $modulesToImport -Global -ErrorAction SilentlyContinue

    $chocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if ([System.IO.File]::Exists($chocolateyProfile)) {
        Import-Module -LiteralPath $chocolateyProfile -Global -ErrorAction SilentlyContinue
    }
}
