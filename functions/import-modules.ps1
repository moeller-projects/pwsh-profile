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

    if ($missingModules -and $env:PWSH_PROFILE_AUTO_INSTALL -eq '1') {
        Install-Module -Name $missingModules -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
    }

    Import-Module -Name $modulesToImport -ErrorAction SilentlyContinue

    $chocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if ([System.IO.File]::Exists($chocolateyProfile)) {
        Import-Module -LiteralPath $chocolateyProfile -ErrorAction SilentlyContinue
    }
}
