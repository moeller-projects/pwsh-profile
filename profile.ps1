# Initialize a stopwatch at the very beginning of the profile (verbose-only)
$profileStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Verbose "Profile loading started at $($profileStopwatch.ElapsedMilliseconds)ms"

# Essential and fast-loading configurations (these run immediately)
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'

# Opt-out of telemetry if running as SYSTEM
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

Write-Verbose "Core configurations loaded at $($profileStopwatch.ElapsedMilliseconds)ms"

# Admin Check (can stay synchronous as it's fast)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# --- Utility Functions (Keep synchronous as they are used early and are fast) ---

function Test-IsInteractive {
    if ($PSVersionTable.PSInteractiveSession -eq $true) { return $true }
    try { $null = $Host.UI.RawUI; return $true } catch { return $false }
}

function Test-CommandExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command
    )
    try { $null -ne (Get-Command -Name $Command -ErrorAction SilentlyContinue) }
    catch { $false }
}

function Resolve-SymlinkPath {
    param (
        [string]$Path
    )
    if (-not ([System.IO.File]::Exists($Path) -or [System.IO.Directory]::Exists($Path))) {
        Write-Warning "Pfad '$Path' existiert nicht. Kann keinen Symlink auflösen."
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
        Write-Warning "Fehler beim Auflösen des Pfades '$Path': $($_.Exception.Message)"
        return $null
    }
}

# Determine profile repository path (needs to be synchronous to find scripts)
$ProfileSymlinkPath = $MyInvocation.MyCommand.Definition
$ProfileRepoFullPath = Resolve-SymlinkPath -Path $ProfileSymlinkPath
if ([string]::IsNullOrEmpty($ProfileRepoFullPath)) {
    Write-Error "Konnte den Repository-Pfad des Profils nicht ermitteln. Skripte können nicht geladen werden."
    return
}
$ProfileRepoPath = [System.IO.Path]::GetDirectoryName($ProfileRepoFullPath)
# Add module path for autoload/import
# Important: PSModulePath entries should point to a directory that CONTAINS module folders/files,
# not the module folder itself. Our module lives under "$ProfileRepoPath/PwshProfile",
# so we add the repo root to PSModulePath.
$modulesRoot = $ProfileRepoPath
if ([System.IO.Directory]::Exists($modulesRoot) -and ($env:PSModulePath -notlike "*${modulesRoot}*")) {
    $env:PSModulePath = "$modulesRoot;" + $env:PSModulePath
}
Write-Verbose "Module path ensured: $modulesRoot"

Write-Verbose "Initial utility functions and paths resolved at $($profileStopwatch.ElapsedMilliseconds)ms"

# --- DEFERRED INITIALIZATION USING REGISTER-ENGINEEVENT (OnIdle) ---

if (Test-IsInteractive -eq $true) {
    # Try to initialize prompt theme early to ensure first-render prompt
    $global:ProfilePromptInitializedEarly = $false
    $global:ProfileLoadingPromptActive = $false
    try {
        $earlyChoice = $Env:PWSH_PROMPT
        switch ($earlyChoice) {
            'plain' { }
            'starship' {
                if (Get-Command starship -ErrorAction SilentlyContinue) {
                    $init = starship init powershell | Out-String
                    & ([ScriptBlock]::Create($init))
                    $cmd = Get-Command prompt -ErrorAction SilentlyContinue
                    if ($null -ne $cmd -and $null -ne $cmd.ScriptBlock -and ($cmd.ScriptBlock.ToString() -match 'starship')) {
                        $global:ProfilePromptInitializedEarly = $true
                    }
                }
            }
            default {
                if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
                    $init = oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/json.omp.json" | Out-String
                    & ([ScriptBlock]::Create($init))
                    $cmd = Get-Command prompt -ErrorAction SilentlyContinue
                    if ($null -ne $cmd -and $null -ne $cmd.ScriptBlock -and ($cmd.ScriptBlock.ToString() -match 'oh-my-posh|Set-PoshPrompt')) {
                        $global:ProfilePromptInitializedEarly = $true
                    }
                }
            }
        }
    }
    catch { }

    # Temporary prompt only if theme not yet available
    if (-not $global:ProfilePromptInitializedEarly) {
        $global:ProfileLoadingPromptActive = $true
        function prompt { "[loading]: PS $($ExecutionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) " }
    }

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
                $sensitivePatterns = @('password', 'secret', 'token', 'apikey', 'connectionstring')
                return -not ($sensitivePatterns | Where-Object { $line -match $_ })
            }
            Set-PSReadLineOption -PredictionSource HistoryAndPlugin
            Set-PSReadLineOption -MaximumHistoryCount 10000
            Set-PSReadLineOption -HistorySavePath "$env:APPDATA\PSReadLine\CommandHistory.txt"
        }
    }
    catch { }

    # Set initial window title
    $adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
    $Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

    Write-Verbose "Interactive session detected; registering deferred initialization"

    $script:ProfileDeferredInitDone = $false
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -Action {
        if ($script:ProfileDeferredInitDone) { return }
        $script:ProfileDeferredInitDone = $true
        try {
            # Single module for all deferred initialization
            New-Module -Name 'ProfileDeferredInitModule' -ScriptBlock {
                # Import our functions via module for autoload
                try { Import-Module PwshProfile -ErrorAction Stop } catch { Write-Verbose ("PwshProfile import failed: {0}" -f $_.Exception.Message) }


                # Load optional modules (PSMenu, etc.) and completions if enabled
                if (Get-Command Import-RequiredModules -ErrorAction SilentlyContinue) {
                    Import-RequiredModules
                }

                # EDITOR setup
                $EDITOR = foreach ($cmd in 'nvim', 'pvim', 'vim', 'vi', 'code', 'notepad++', 'sublime_text') { if (Get-Command $cmd -EA SilentlyContinue) { $cmd; break } }
                if (-not $EDITOR) { $EDITOR = 'notepad' }
                Set-Alias -Name vim -Value $EDITOR
                Export-ModuleMember -Alias vim

                # dotnet completer
                if (Get-Command dotnet -ErrorAction SilentlyContinue) {
                    $dotnetCompleter = {
                        param($wordToComplete, $commandAst, $cursorPosition)
                        dotnet complete --position $cursorPosition $commandAst.ToString() |
                        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
                    }
                    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $dotnetCompleter
                }

                # az completer (guard short prefixes)
                if (Get-Command az -ErrorAction SilentlyContinue) {
                    Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
                        param($commandName, $wordToComplete, $cursorPosition)
                        if ([string]::IsNullOrWhiteSpace($wordToComplete) -or $wordToComplete.Length -lt 2) { return }
                        $completion_file = [System.IO.Path]::GetTempFileName()
                        try {
                            $env:ARGCOMPLETE_USE_TEMPFILES = 1
                            $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
                            $env:COMP_LINE = $wordToComplete
                            $env:COMP_POINT = $cursorPosition
                            $env:_ARGCOMPLETE = 1
                            $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
                            $env:_ARGCOMPLETE_IFS = "`n"
                            $env:_ARGCOMPLETE_SHELL = 'powershell'
                            az 2>&1 | Out-Null
                            [System.IO.File]::ReadAllLines($completion_file) | Sort-Object | ForEach-Object {
                                [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
                            }
                        }
                        finally {
                            Remove-Item -ErrorAction SilentlyContinue $completion_file
                            Remove-Item Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL -ErrorAction SilentlyContinue
                        }
                    }
                }

                # zoxide and git alias completer
                if (Get-Command __zoxide_z -ErrorAction SilentlyContinue) { Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force }
                if (Get-Command __zoxide_zi -ErrorAction SilentlyContinue) { Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force }
                if (Get-Command git -ErrorAction SilentlyContinue) {
                    Register-ArgumentCompleter -Native -CommandName git -ScriptBlock {
                        param($wordToComplete, $commandAst, $cursorPosition)
                        $gitAliases = $script:GitAliases
                        if (-not $gitAliases -or $env:GIT_COMPLETIONS_REFRESH -eq '1') {
                            $script:GitAliases = git config --list | ForEach-Object { if ($_ -match '(?<=alias\.).*?(?==)') { $Matches[0] } }
                            $gitAliases = $script:GitAliases
                        }
                        $command = $commandAst.CommandElements[0].Value
                        if ($command -eq 'git') {
                            $gitAliases | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                            }
                        }
                    }
                }

                # External completions (volta, pixi, starship, zoxide, mise) only if enabled
                if ($Env:PWSH_PROFILE_COMPLETIONS -ne '0') {
                    if (Get-Command Initialize-Completion -ErrorAction SilentlyContinue) {
                        Initialize-Completion
                    }
                }
            } | Import-Module -Global

            # EDITOR setup
            # (additional EDITOR/completers moved inside ProfileDeferredInitModule)

            # Stop the stopwatch and log final time (verbose-only)
            $sw = $ExecutionContext.SessionState.PSVariable.Get('profileStopwatch').Value
            $sw.Stop()
            $elapsedMs = [int]$sw.ElapsedMilliseconds
            Write-Verbose ("Profile fully loaded at {0}ms" -f $elapsedMs)

            # Update window title to indicate readiness
            try {
                $adminSuffix = if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { " [ADMIN]" } else { "" }
                $Host.UI.RawUI.WindowTitle = "PowerShell {0}{1} — Ready in {2} ms" -f $PSVersionTable.PSVersion.ToString(), $adminSuffix, $elapsedMs
            }
            catch { }

            # Always print a concise confirmation when the profile is fully loaded
            # Intentionally uses Write-Host for interactive UX per repo guidelines
            Write-Host ("Profile fully loaded in {0} ms" -f $elapsedMs)
        }
        catch {
            Write-Verbose ("Deferred init error: {0}" -f $_.Exception.Message)
        }
        finally {
            Unregister-Event -SourceIdentifier PowerShell.OnIdle -ErrorAction SilentlyContinue
            # Restore default prompt only if we used the temporary loading prompt
            try {
                if ($global:ProfileLoadingPromptActive) {
                    Remove-Item Function:prompt -ErrorAction SilentlyContinue
                    $global:ProfileLoadingPromptActive = $false
                }
            }
            catch { }
        }
    } | Out-Null
}

# --- Always available utility functions / aliases (fast and core to profile management) ---
# These are kept outside the deferred block because they are fundamental profile management tools and are fast to load.
function Invoke-ProfileReload { & $profile }
function Edit-Profile { vim $PROFILE }
Set-Alias -Name ep -Value Edit-Profile
function winutil { irm https://christitus.com/win | iex }
function winutildev { irm https://christitus.com/windev | iex }
function admin {
    [CmdletBinding()]
    [Alias("su")]
    param ()
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
# goToParent, goToParent2Levels, goToHome must be defined *here* or *globally available* for these aliases to work.
Set-Alias -Name c -Value Clear-Host
Set-Alias -Name ls -Value Get-ChildItem


Write-Verbose "End of synchronous profile execution at $($profileStopwatch.ElapsedMilliseconds)ms. Deferred tasks registered."
