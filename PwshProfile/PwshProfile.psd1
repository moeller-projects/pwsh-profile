@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'PwshProfile.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop','Core')

    # ID used to uniquely identify this module
    GUID = 'b9d2db05-3a1b-4c0c-9b7d-0f7c2a9df0db'

    # Author of this module
    Author = 'moeller-projects'

    # Company or vendor of this module
    CompanyName = 'moeller-projects'

    # Copyright
    Copyright = '(c) moeller-projects. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Convenience commands and profile helpers extracted from the pwsh-profile repository.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = '*'

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = '*'

    PrivateData = @{
        PSData = @{
            ProjectUri = 'https://github.com/moeller-projects/pwsh-profile'
            LicenseUri = 'https://github.com/moeller-projects/pwsh-profile/blob/main/LICENSE'
        }
    }
}

