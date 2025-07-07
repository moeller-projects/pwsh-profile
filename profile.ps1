# Initialize a stopwatch at the very beginning of the profile
$profileStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "Profile loading started at $($profileStopwatch.ElapsedMilliseconds)ms" -ForegroundColor DarkGray

# Essential and fast-loading configurations (these run immediately)
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'

# Opt-out of telemetry if running as SYSTEM
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

Write-Host "Core configurations loaded at $($profileStopwatch.ElapsedMilliseconds)ms" -ForegroundColor DarkGray

# Admin Check (can stay synchronous as it's fast)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# --- Utility Functions (Keep synchronous as they are used early and are fast) ---

function Test-IsInteractive {
    if ($PSVersionTable.PSInteractiveSession -eq $true) { return $true }
    try { $null = $Host.UI.RawUI; return $true } catch { return $false }
}

# Optimized Test-CommandExists using try-catch instead of Get-Command for speed
function Test-CommandExists {
    param($command)
    try {
        # First, try Get-Command for speed, especially for executables on PATH.
        # -ErrorAction SilentlyContinue prevents output if not found.
        if (Get-Command $command -ErrorAction SilentlyContinue) {
            # Write-Host "Get-Command found '$command'." -ForegroundColor DarkGreen
            return $true
        }

        # If Get-Command didn't find it, it might be an alias or a function only discoverable by invocation
        # Or, if you specifically want to confirm it's runnable and not just defined.
        # Use a short timeout here to prevent hanging for too long for external commands.
        # This will only work if the command finishes quickly or the timeout is observed.
        # This part might still be problematic if the command itself hangs.
        $scriptBlockToRun = [scriptblock]::Create("& `"$command`"")
        $job = Start-Job -ScriptBlock $scriptBlockToRun -ErrorAction SilentlyContinue
        Wait-Job -Job $job -Timeout 5 | Out-Null # Wait for 5 seconds max
        if ($job.State -eq 'Completed' -and $job.HasErrors -eq $false) {
            Receive-Job -Job $job | Out-Null
            Remove-Job -Job $job | Out-Null
            # Write-Host "Invoke-Command via Job succeeded for '$command'." -ForegroundColor DarkGreen
            return $true
        }
        else {
            # Clean up hanging jobs
            Stop-Job -Job $job -Force -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            # Write-Host "Invoke-Command via Job failed or timed out for '$command'." -ForegroundColor DarkRed
            return $false
        }
    }
    catch {
        # Write-Host "Error in Test-CommandExists for '$command': $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
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
. ([System.IO.Path]::Combine($ProfileRepoPath, "functions/ai-functions.ps1"))
. ([System.IO.Path]::Combine($ProfileRepoPath, "functions/azure-functions.ps1"))
. ([System.IO.Path]::Combine($ProfileRepoPath, "functions/kubernetes-functions.ps1"))
. ([System.IO.Path]::Combine($ProfileRepoPath, "functions/dev-functions.ps1"))
. ([System.IO.Path]::Combine($ProfileRepoPath, "functions/file-functions.ps1"))
. ([System.IO.Path]::Combine($ProfileRepoPath, "functions/git-functions.ps1"))
. ([System.IO.Path]::Combine($ProfileRepoPath, "functions/network-functions.ps1"))
. ([System.IO.Path]::Combine($ProfileRepoPath, "functions/setup-autocompletions.ps1"))
Initialize-Completion
. ([System.IO.Path]::Combine($ProfileRepoPath, "functions/import-modules.ps1"))
Import-RequiredModules

Write-Host "Initial utility functions and paths resolved at $($profileStopwatch.ElapsedMilliseconds)ms" -ForegroundColor DarkGray

# --- DEFERRED INITIALIZATION USING REGISTER-ENGINEEVENT (OnIdle) ---

if (Test-IsInteractive -eq $true) {
    # Set a temporary prompt to indicate loading
    function prompt {
        "[async init]: PS $($ExecutionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) ";
    }

    # Set initial window title
    $adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
    $Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

    Write-Host "Interactive session detected; deferred loading setup begins at $($profileStopwatch.ElapsedMilliseconds)ms" -ForegroundColor DarkGray

    # Create a queue of tasks to run asynchronously
    [System.Collections.Queue]$__initQueue = @(
        {
            Write-Host "Starting Oh-My-Posh and PSReadLine init at $($profileStopwatch.ElapsedMilliseconds)ms (deferred)" -ForegroundColor DarkCyan
            # Wrap in New-Module to ensure functions/settings are global
            New-Module -Name 'PoshReadlineInit' -ScriptBlock {
                Set-PSReadLineOption -PromptText '' # Needs to be global affecting the main console

                function Initialize-Theme {
                    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/json.omp.json" | Invoke-Expression
                    $Env:POSH_GIT_ENABLED = $true
                }
                Initialize-Theme

                function Initialize-PSReadLine {
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
                        PredictionSource              = 'History'
                        PredictionViewStyle           = 'ListView'
                        BellStyle                     = 'None'
                    }
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
                Initialize-PSReadLine
                # Export functions/aliases/variables if defined here for global access
                # Export-ModuleMember -Function Initialize-Theme, Initialize-PSReadLine # Not necessary as they are called internally
            } | Import-Module -Global # Import this temporary module globally
            Write-Host "Oh-My-Posh and PSReadLine init completed at $($profileStopwatch.ElapsedMilliseconds)ms (deferred)" -ForegroundColor DarkCyan
        },
        {
            Write-Host "Starting EDITOR setup at $($profileStopwatch.ElapsedMilliseconds)ms (deferred)" -ForegroundColor DarkCyan
            New-Module -Name 'EditorSetupCustom' -ScriptBlock {
                # Test-CommandExists needed here again
                function Test-CommandExists {
                    param($command)
                    try { $null -ne (Get-Command $command -ErrorAction SilentlyContinue) }
                    catch { Write-Warning "Error checking for command '$command': $($_.Exception.Message)"; return $false }
                }

                $EDITOR_FOUND = $false
                $EDITOR = foreach ($cmd in 'nvim', 'pvim', 'vim', 'vi', 'code', 'notepad++', 'sublime_text') {
                    if (Test-CommandExists $cmd) {
                        $cmd;
                        $EDITOR_FOUND = $true;
                        break
                    }
                }
                if (-not $EDITOR_FOUND) {
                    $EDITOR = 'notepad'
                }
                Set-Alias -Name vim -Value $EDITOR
                Export-ModuleMember -Alias vim # Export the alias
            } | Import-Module -Global
            Write-Host "EDITOR setup completed at $($profileStopwatch.ElapsedMilliseconds)ms (deferred)" -ForegroundColor DarkCyan
        },
        {
            Write-Host "Starting dotnet argument completer setup at $($profileStopwatch.ElapsedMilliseconds)ms (deferred)" -ForegroundColor DarkCyan
            New-Module -Name 'DotnetCompleterCustom' -ScriptBlock {
                $dotnetCompleter = {
                    param($wordToComplete, $commandAst, $cursorPosition)
                    dotnet complete --position $cursorPosition $commandAst.ToString() |
                    ForEach-Object {
                        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                    }
                }
                Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $dotnetCompleter
            } | Import-Module -Global
            Write-Host "dotnet argument completer setup completed at $($profileStopwatch.ElapsedMilliseconds)ms (deferred)" -ForegroundColor DarkCyan
        },
        {
            Write-Host "Starting az argument completer setup at $($profileStopwatch.ElapsedMilliseconds)ms (deferred)" -ForegroundColor DarkCyan
            New-Module -Name 'AzCompleterCustom' -ScriptBlock {
                Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
                    param($commandName, $wordToComplete, $cursorPosition)
                    $completion_file = [System.IO.Path]::GetTempFileName()
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
                    [System.IO.File]::Delete($completion_file)
                    Remove-Item Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
                }
            } | Import-Module -Global
            Write-Host "az argument completer setup completed at $($profileStopwatch.ElapsedMilliseconds)ms (deferred)" -ForegroundColor DarkCyan
        },
        {
            Write-Host "Starting zoxide and git aliases setup at $($profileStopwatch.ElapsedMilliseconds)ms (deferred)" -ForegroundColor DarkCyan
            New-Module -Name 'ZoxideGitCompleterCustom' -ScriptBlock {
                Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
                Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force

                $gitAliases = git config --list | ForEach-Object {
                    if ($_ -match '(?<=alias\.).*?(?==)') {
                        $Matches[0]
                    }
                }
                $scriptblock = {
                    param($wordToComplete, $commandAst, $cursorPosition)
                    $customCompletions = @{
                        'git' = $gitAliases
                    }

                    $command = $commandAst.CommandElements[0].Value
                    if ($customCompletions.ContainsKey($command)) {
                        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                        }
                    }
                }
                Register-ArgumentCompleter -Native -CommandName git -ScriptBlock $scriptblock
                Export-ModuleMember -Alias z, zi # Export aliases
            } | Import-Module -Global
            Write-Host "zoxide and git aliases setup completed at $($profileStopwatch.ElapsedMilliseconds)ms (deferred)" -ForegroundColor DarkCyan
        }
    )

    # Register our idle callback; use `-SupportEvent` to hide the registration from the user
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -SupportEvent -Action {
        # Check if the stopwatch is still running; this allows it to be used across events.
        # This action also runs in its own scope, so $profileStopwatch and $__initQueue need to be global or accessible via $using:
        $currentStopwatch = $Global:profileStopwatch # Access the global stopwatch

        if ($Global:__initQueue.Count -gt 0) {
            Write-Verbose "Dequeuing next deferred task. Remaining tasks: $($Global:__initQueue.Count)"
            & $Global:__initQueue.Dequeue() # Execute the next script block in the queue
        }
        else {
            # All tasks completed, unregister event and clean up
            # NOTE: Use `-Force` when unregistering because we used `-SupportEvent` when registering
            Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -Force

            # Remove our queue variable to avoid polluting the environment
            Remove-Variable -Name '__initQueue' -Scope Global -Force

            # Re-render the prompt so we get pretty colors ASAP!
            [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()

            # Stop the stopwatch and log final time only once all tasks are complete
            $currentStopwatch.Stop()
            Write-Host "Profile fully loaded and interactive prompt available at $($currentStopwatch.ElapsedMilliseconds)ms" -ForegroundColor Green
        }
    }
} # End of if (Test-IsInteractive -eq $true)

# --- Always available utility functions / aliases (fast and core to profile management) ---
# These are kept outside the deferred block because they are fundamental profile management tools
# and are fast to load.
function Reload-Profile { & $profile }
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
# Let's include them here, as they are small and fundamental.
function goParent() { Set-Location .. }
function goToParent2Levels() { Set-Location ../.. }
function goToHome() { Set-Location ~ }

Set-Alias -Name c -Value Clear-Host
Set-Alias -Name ls -Value Get-ChildItem
Set-Alias -Name .. -Value goParent
Set-Alias -Name ... -Value goToParent2Levels
Set-Alias -Name ~ -Value goToHome


Write-Host "End of synchronous profile execution at $($profileStopwatch.ElapsedMilliseconds)ms. Waiting for deferred tasks..." -ForegroundColor DarkGray
