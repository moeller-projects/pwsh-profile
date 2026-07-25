# Initialize a stopwatch at the very beginning of the profile (verbose-only)
$profileStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Verbose "Profile loading started at $($profileStopwatch.ElapsedMilliseconds)ms"

# Essential and fast-loading configurations (these run immediately)
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'


Write-Verbose "Core configurations loaded at $($profileStopwatch.ElapsedMilliseconds)ms"


# --- Utility Functions (Keep synchronous as they are used early and are fast) ---

function Test-IsInteractive {
    if ($PSVersionTable.PSInteractiveSession -eq $true) { return $true }
    try { $null = $Host.UI.RawUI; return $true } catch { return $false }
}


function Resolve-SymlinkPath {
    param (
        [string]$Path
    )
    if (-not ([System.IO.File]::Exists($Path) -or [System.IO.Directory]::Exists($Path))) {
        Write-Warning "Path '$Path' does not exist. Cannot resolve symlink."
        return $null
    }

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            return $item.Target
        }
        else {
            return $Path
        }
    }
    catch {
        Write-Warning "Error resolving path '$Path': $($_.Exception.Message)"
        return $null
    }
}

# Determine profile repository path (needs to be synchronous to find scripts)
$ProfileSymlinkPath = $MyInvocation.MyCommand.Definition
$ProfileRepoFullPath = Resolve-SymlinkPath -Path $ProfileSymlinkPath
if ([string]::IsNullOrEmpty($ProfileRepoFullPath)) {
    Write-Error "Could not determine the repository path of the profile. Scripts cannot be loaded."
    return
}
$ProfileRepoPath = [System.IO.Path]::GetDirectoryName($ProfileRepoFullPath)
# Add the repository root for ad hoc module imports.
$modulesRoot = $ProfileRepoPath
$pathSep = [System.IO.Path]::PathSeparator
$pathEntries = $env:PSModulePath -split [System.Text.RegularExpressions.Regex]::Escape($pathSep)
$pathComparison = if ($IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')) {
    [System.StringComparison]::OrdinalIgnoreCase
} else {
    [System.StringComparison]::Ordinal
}
if ([System.IO.Directory]::Exists($modulesRoot) -and -not ($pathEntries | Where-Object { [string]::Equals($_, $modulesRoot, $pathComparison) })) {
    $env:PSModulePath = "$modulesRoot$pathSep$env:PSModulePath"
}

# Area modules autoload individual commands through the module path above.

# --- DEFERRED INITIALIZATION USING REGISTER-ENGINEEVENT (OnIdle) ---

if (Test-IsInteractive) {
    if ($Env:PWSH_PROFILE_PSREADLINE -eq '1') {
    # Early PSReadLine initialization (for immediate editing experience)
    try {
        if (-not (Get-Module -Name PSReadLine -ErrorAction SilentlyContinue)) {
            Import-Module PSReadLine -ErrorAction SilentlyContinue | Out-Null
        }
        if (Get-Module -Name PSReadLine -ErrorAction SilentlyContinue) {
            $prediction = if ($Env:PWSH_PREDICTION -eq 'plugin') { 'HistoryAndPlugin' } else { 'History' }
            $psReadLineOptions = @{
                EditMode                      = 'Windows'
                HistoryNoDuplicates           = $true
                HistorySearchCursorMovesToEnd = $true
                Colors                        = @{
                    Command   = '#87CEEB'
                    Parameter = '#98FB98'
                    Operator  = '#FFB6C1'
                    Variable  = '#DDA0DD'
                    String    = '#FFDAB9'
                    Number    = '#B0E0E6'
                    Type      = '#F0E68C'
                    Comment   = '#D3D3D3'
                    Keyword   = '#8367c7'
                    Error     = '#FF6347'
                }
                PredictionSource              = $prediction
                PredictionViewStyle           = 'ListView'
                BellStyle                     = 'None'
            }
            Set-PSReadLineOption -PromptText ''
            Set-PSReadLineOption @psReadLineOptions

            $keyHandlers = @(
                @{ Key = 'UpArrow'; Function = 'HistorySearchBackward' },
                @{ Key = 'DownArrow'; Function = 'HistorySearchForward' },
                @{ Key = 'Tab'; Function = 'MenuComplete' },
                @{ Chord = 'Ctrl+d'; Function = 'DeleteChar' },
                @{ Chord = 'Ctrl+w'; Function = 'BackwardDeleteWord' },
                @{ Chord = 'Alt+d'; Function = 'DeleteWord' },
                @{ Chord = 'Ctrl+LeftArrow'; Function = 'BackwardWord' },
                @{ Chord = 'Ctrl+RightArrow'; Function = 'ForwardWord' },
                @{ Chord = 'Ctrl+z'; Function = 'Undo' },
                @{ Chord = 'Ctrl+y'; Function = 'Redo' },
                @{ Key = 'Ctrl+l'; Function = 'ClearScreen' },
                @{ Chord = 'Enter'; Function = 'ValidateAndAcceptLine' },
                @{ Chord = 'Ctrl+Enter'; Function = 'AcceptSuggestion' },
                @{ Chord = 'Alt+v'; Function = 'SwitchPredictionView' }
            )
            foreach ($handler in $keyHandlers) {
                if ($handler.ContainsKey('Key')) {
                    Set-PSReadLineKeyHandler -Key $handler.Key -Function $handler.Function
                }
                elseif ($handler.ContainsKey('Chord')) {
                    Set-PSReadLineKeyHandler -Chord $handler.Chord -Function $handler.Function
                }
            }
            Set-PSReadLineOption -AddToHistoryHandler {
                param($line)
                $sensitivePatterns = @('(?i)(password|passwd|secret|token|apikey|api_key|connectionstring)\s*[:=]')
                return -not ($sensitivePatterns | Where-Object { $line -match $_ })
            }
            Set-PSReadLineOption -MaximumHistoryCount 10000
        }
    }
    catch { Write-Verbose "PSReadLine configuration failed: $_" }
    }


    Write-Verbose "Interactive session detected; registering deferred initialization"

    # Stage 1: Load integrations module + prompt engine
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        try {
            # Load integrations module once so all stages can use Get-CachedShellInit
            $needsIntegrations = ($Env:PWSH_PROMPT -in @('starship','posh')) -or
                                  ($Env:PWSH_PROFILE_COMPLETIONS -eq '1') -or
                                  ($Env:PWSH_PROFILE_IMPORT_OPTIONAL -eq '1')
            if ($needsIntegrations) {
                Import-Module -Name PwshProfile.Integrations -Global -ErrorAction Stop
            }

            if ($Env:PWSH_PROMPT -eq 'starship' -and (Get-Command starship -ErrorAction SilentlyContinue)) {
                $file = Get-CachedShellInit -Tool 'starship' -Generator { starship init powershell | Out-String }
                if ($file) { . $file }
            }
            elseif ($Env:PWSH_PROMPT -eq 'posh' -and (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
                if ($env:POSH_THEMES_PATH) {
                    $file = Get-CachedShellInit -Tool 'oh-my-posh' -Generator {
                        oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/json.omp.json" | Out-String
                    }
                    if ($file) { . $file }
                }
                else {
                    Write-Verbose "oh-my-posh: POSH_THEMES_PATH is not set; skipping prompt init."
                }
            }
        }
        catch {
            Write-Verbose ("Deferred init stage 1 (prompt) error: {0}" -f $_.Exception.Message)
        }
    } | Out-Null

    # Stage 2: Completions + zoxide aliases
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        try {
            if ($Env:PWSH_PROFILE_COMPLETIONS -eq '1') {
                Initialize-Completion
            }

            # Register zoxide aliases after zoxide init (which runs inside Initialize-Completion)
            if (Get-Command __zoxide_z -ErrorAction SilentlyContinue) {
                Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
            }
            if (Get-Command __zoxide_zi -ErrorAction SilentlyContinue) {
                Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force
            }

            if (Get-Command dotnet -ErrorAction SilentlyContinue) {
                $dotnetCompleter = {
                    param($wordToComplete, $commandAst, $cursorPosition)
                    dotnet complete --position $cursorPosition $commandAst.ToString() |
                    ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
                }
                Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $dotnetCompleter
            }
        }
        catch {
            Write-Verbose ("Deferred init stage 2 (completions) error: {0}" -f $_.Exception.Message)
        }
    } | Out-Null

    # Stage 3: Optional modules
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        try {
            if ($Env:PWSH_PROFILE_IMPORT_OPTIONAL -eq '1') {
                Import-RequiredModules
            }
        }
        catch {
            Write-Verbose ("Deferred init stage 3 (optional modules) error: {0}" -f $_.Exception.Message)
        }
    } | Out-Null

    # Stage 4: Housekeeping (editor alias, git-wt)
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        try {
            $editor = if ($env:EDITOR) { $env:EDITOR } else { 'notepad' }
            if ($editor -ne 'vim') {
                Set-Alias -Name vim -Value $editor -Scope Global
            }

            if ($Env:PWSH_PROFILE_GIT_WT -eq '1' -and (Get-Command git-wt -ErrorAction SilentlyContinue)) {
                $file = Get-CachedShellInit -Tool 'git-wt' -Generator { git-wt config shell init powershell | Out-String }
                if ($file) { . $file }
            }
        }
        catch {
            Write-Verbose ("Deferred init stage 4 (housekeeping) error: {0}" -f $_.Exception.Message)
        }
    } | Out-Null
}

# --- Always available utility functions / aliases (fast and core to profile management) ---
# These are kept outside the deferred block because they are fundamental profile management tools and are fast to load.
function Invoke-ProfileReload { & $profile }
function Edit-Profile {
    [CmdletBinding()]
    param()
    $editor = if ($env:EDITOR) { $env:EDITOR } else { 'notepad' }
    & $editor $PROFILE
}
Set-Alias -Name ep -Value Edit-Profile
function admin {
    [CmdletBinding()]
    [Alias("su")]
    param ()
    if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        Write-Warning "admin: This function requires Windows."
        return
    }
    if ($args.Count -gt 0) {
        $argList = $args -join ' '
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    }
    else {
        Start-Process wt -Verb runAs
    }
}

# Common Aliases (move them here to ensure they are available immediately)
# These do not depend on external files or slow lookups.
Set-Alias -Name c -Value Clear-Host
Set-Alias -Name ls -Value Get-ChildItem

Set-Alias -Name g -Value git

# Git alias completer (registered synchronously; zoxide aliases registered in OnIdle after init)
if (Get-Command git -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName git -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $gitAliases = $script:GitAliases
        if (-not $gitAliases -or $env:GIT_COMPLETIONS_REFRESH -eq '1') {
            $script:GitAliases = git config --list | ForEach-Object { if ($_ -match '(?<=alias\.).*?(?==)') { $Matches[0] } }
            $gitAliases = $script:GitAliases
        }
        $gitAliases | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

Write-Verbose "End of synchronous profile execution at $($profileStopwatch.ElapsedMilliseconds)ms. Deferred tasks registered."

# Optional timing output (PWSH_PROFILE_TIMING=1)
if ($env:PWSH_PROFILE_TIMING -eq '1') {
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        try {
            $elapsed = $profileStopwatch.ElapsedMilliseconds
            Write-Host "[TIMING] Profile total elapsed at idle: ${elapsed}ms" -ForegroundColor DarkCyan
        }
        catch { Write-Verbose "TIMING stage failed: $_" }
    } | Out-Null
}
