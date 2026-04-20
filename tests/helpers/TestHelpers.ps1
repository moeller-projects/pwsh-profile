function Get-RepoRoot {
    [CmdletBinding()]
    param()

    return (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
}

function Get-InventoryPath {
    [CmdletBinding()]
    param()

    return (Join-Path (Split-Path -Parent $PSScriptRoot) 'command-inventory.json')
}

function Get-CommandInventory {
    [CmdletBinding()]
    param()

    return (Get-Content -LiteralPath (Get-InventoryPath) -Raw | ConvertFrom-Json).entries
}

function Import-PwshProfileModuleForTest {
    [CmdletBinding()]
    param()

    $repoRoot = Get-RepoRoot
    $modulePath = Join-Path $repoRoot 'PwshProfile/PwshProfile.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
}

function Get-RepositoryFunctionDefinitions {
    [CmdletBinding()]
    param()

    $repoRoot = Get-RepoRoot
    $files = @(
        Get-ChildItem -LiteralPath (Join-Path $repoRoot 'functions') -Filter *.ps1 -File
        Get-Item -LiteralPath (Join-Path $repoRoot 'profile.ps1')
        Get-Item -LiteralPath (Join-Path $repoRoot 'setup.ps1')
        Get-Item -LiteralPath (Join-Path $repoRoot 'scripts/Invoke-Smoketests.ps1')
        Get-Item -LiteralPath (Join-Path $repoRoot 'scripts/add-database-firewall-rules.ps1')
    )

    foreach ($file in $files) {
        foreach ($match in [regex]::Matches((Get-Content -LiteralPath $file.FullName -Raw), '(?im)^function\s+([A-Za-z0-9_-]+)')) {
            [pscustomobject]@{
                Name   = $match.Groups[1].Value
                Source = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName).Replace('\', '/')
                Kind   = 'function'
            }
        }
    }
}

function Get-RepositoryScripts {
    [CmdletBinding()]
    param()

    @(
        'setup.ps1',
        'test-loading-time.ps1',
        'scripts/Invoke-Smoketests.ps1',
        'scripts/add-database-firewall-rules.ps1',
        'scripts/add-windows-defender-exclusions-for-jetbrains.ps1'
    ) | ForEach-Object {
        [pscustomobject]@{
            Name   = [System.IO.Path]::GetFileName($_)
            Source = $_
            Kind   = 'script'
        }
    }
}

function Invoke-PwshTestCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [hashtable]$Environment = @{},
        [string[]]$PowerShellArguments = @()
    )

    $envAssignments = foreach ($key in $Environment.Keys) {
        $value = $Environment[$key]
        if ($null -eq $value) {
            "Remove-Item Env:$key -ErrorAction SilentlyContinue"
        }
        else {
            $escapedValue = ([string]$value).Replace("'", "''")
            "`$env:$key = '$escapedValue'"
        }
    }

    $scriptBlock = @(
        '$ErrorActionPreference = ''Stop'''
        $envAssignments
        $Command
    ) -join '; '

    $output = & pwsh @PowerShellArguments -NoLogo -NoProfile -Command $scriptBlock 2>&1
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = @($output)
    }
}
