function Get-CachedShellInit {
    <#
    .SYNOPSIS
        Returns a cached path to a generated shell-init script, regenerating when the tool version changes.
    .PARAMETER Tool
        Short name used as the cache file prefix.
    .PARAMETER Generator
        Script block that runs the tool and returns its init output as a string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Tool,
        [Parameter(Mandatory)][scriptblock]$Generator
    )

    # Determine cache directory
    if ($env:XDG_CACHE_HOME) {
        $cacheDir = Join-Path $env:XDG_CACHE_HOME 'pwsh-profile'
    }
    elseif ($IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')) {
        $cacheDir = Join-Path (if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME 'AppData\Local' }) 'pwsh-profile\cache'
    }
    else {
        $cacheDir = Join-Path $HOME '.cache/pwsh-profile'
    }

    if (-not (Test-Path -LiteralPath $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }

    # Key by tool name + sanitized version string
    $versionRaw = & $Tool --version 2>&1 | Select-Object -First 1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($versionRaw)) {
        $versionKey = 'unknown'
    }
    else {
        $versionKey = $versionRaw -replace '[^A-Za-z0-9._-]', '_'
    }

    $cacheFile = Join-Path $cacheDir "${Tool}_${versionKey}.ps1"

    if (-not (Test-Path -LiteralPath $cacheFile)) {
        Write-Verbose "Generating shell init for '$Tool' (version: $versionKey)..."
        try {
            $initContent = & $Generator
            if ($initContent) {
                Set-Content -LiteralPath $cacheFile -Value $initContent -Encoding UTF8
                Write-Verbose "Cached shell init for '$Tool' at '$cacheFile'."
            }
            else {
                Write-Verbose "Generator for '$Tool' returned empty output; not caching."
                return $null
            }
        }
        catch {
            Write-Verbose "Failed to generate shell init for '$Tool': $($_.Exception.Message)"
            return $null
        }
    }
    else {
        Write-Verbose "Using cached shell init for '$Tool' at '$cacheFile'."
    }

    return $cacheFile
}

function Initialize-Completion {
    if (Get-Command -Name volta -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing volta completions..."
        $file = Get-CachedShellInit -Tool 'volta' -Generator { volta completions powershell | Out-String }
        if ($file) { . $file }
    }
    if (Get-Command -Name pixi -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing pixi completions..."
        $file = Get-CachedShellInit -Tool 'pixi' -Generator { pixi completion --shell powershell | Out-String }
        if ($file) { . $file }
    }

    if (Get-Command -Name zoxide -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing zoxide completions..."
        Remove-Item -Path Alias:cd -Force -ErrorAction SilentlyContinue
        $file = Get-CachedShellInit -Tool 'zoxide' -Generator { zoxide init --cmd cd powershell | Out-String }
        if ($file) { . $file }
    }

    if (Get-Command -Name mise -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing mise completions..."
        $file = Get-CachedShellInit -Tool 'mise' -Generator { mise activate pwsh | Out-String }
        if ($file) { . $file }
    }

    if (Get-Command -Name kiro -ErrorAction SilentlyContinue) {
        Write-Verbose "Initializing kiro completions..."
        $file = Get-CachedShellInit -Tool 'kiro' -Generator { kiro --locate-shell-integration-path pwsh | Out-String }
        if ($file) { . $file }
    }

    Write-Verbose "All external completions initialized."
}
