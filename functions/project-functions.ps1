# project-functions.ps1 — Project directory navigation helpers

# Script-scope cache for Get-ProjectPaths results (TTL 60 seconds)
$script:ProjectPathsCache = $null
$script:ProjectPathsCacheTime = [datetime]::MinValue

function Get-ProjectConfigPath {
    if ($env:PWSH_PROFILE_CONFIG_OVERRIDE) {
        return $env:PWSH_PROFILE_CONFIG_OVERRIDE
    }

    if ($IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')) {
        $base = $env:APPDATA
        if (-not $base) { $base = Join-Path $HOME 'AppData/Roaming' }
        return (Join-Path $base 'pwsh-profile/config.json')
    } else {
        return (Join-Path $HOME '.config/pwsh-profile/config.json')
    }
}

function Get-ProjectPaths {
    # Return cached result if still valid (TTL 60 s)
    if ($script:ProjectPathsCache -and ([datetime]::Now - $script:ProjectPathsCacheTime).TotalSeconds -lt 60) {
        return $script:ProjectPathsCache
    }

    $cfgPath = Get-ProjectConfigPath
    $result = $null
    if (Test-Path -LiteralPath $cfgPath) {
        try {
            $json = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($json.ProjectRoots -and $json.ProjectRoots.Count -gt 0) { $result = [string[]]$json.ProjectRoots }
        } catch {
            Write-Verbose "Failed to parse project config at ${cfgPath}: $($_.Exception.Message)"
        }
    }
    if (-not $result -and $env:PWSH_PROJECT_PATHS) {
        $result = [string[]]($env:PWSH_PROJECT_PATHS -split ';|,')
    }
    if (-not $result) { $result = @() }

    $script:ProjectPathsCache = $result
    $script:ProjectPathsCacheTime = [datetime]::Now
    return $result
}

function Set-ProjectPaths {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory)][string[]]$Paths)
    $cfgPath = Get-ProjectConfigPath
    $cfgDir = Split-Path -Parent $cfgPath
    if (-not (Test-Path -LiteralPath $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
    $obj = @{ ProjectRoots = $Paths }
    $json = $obj | ConvertTo-Json -Depth 3
    if ($PSCmdlet.ShouldProcess($cfgPath, 'write project paths config')) {
        Set-Content -LiteralPath $cfgPath -Value $json -Encoding UTF8
        # Invalidate cache
        $script:ProjectPathsCache = $null
        $script:ProjectPathsCacheTime = [datetime]::MinValue
        Write-Verbose "Saved project paths to $cfgPath"
    }
}

# Script-scope cache for completer directory listings (TTL 30 seconds per root)
$script:CompleterDirCache = @{}
$script:CompleterDirCacheTime = @{}

# Custom argument completer for substring matching
Register-ArgumentCompleter -CommandName Enter-ProjectDirectory -ParameterName ProjectName -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $projectPaths = Get-ProjectPaths
    $now = [datetime]::Now

    $completionMatches = foreach ($projectPath in $projectPaths) {
        if (Test-Path $projectPath) {
            if (-not $script:CompleterDirCache.ContainsKey($projectPath) -or
                ($now - $script:CompleterDirCacheTime[$projectPath]).TotalSeconds -ge 30) {
                $script:CompleterDirCache[$projectPath] = Get-ChildItem -Path $projectPath -Directory | Select-Object -ExpandProperty BaseName
                $script:CompleterDirCacheTime[$projectPath] = $now
            }
            foreach ($name in $script:CompleterDirCache[$projectPath]) {
                if ($name -like "*$wordToComplete*") {
                    [System.Management.Automation.CompletionResult]::new(
                        $name, $name, 'ParameterValue', $name
                    )
                }
            }
        }
    }

    return $completionMatches
}

function Enter-ProjectDirectory {
    [CmdletBinding()]
    [Alias("project", "p")]
    param(
        [string] $ProjectName
    )

    $projectPaths = Get-ProjectPaths
    foreach ($projectPath in $projectPaths) {
        $fullProjectPath = [System.IO.Path]::Combine($projectPath, $ProjectName)
        if ([System.IO.Directory]::Exists($fullProjectPath)) {
            Set-Location -Path $fullProjectPath
            Get-ChildItem
            return
        }
    }
    Write-Warning "Project '$ProjectName' not found under configured roots."
}
