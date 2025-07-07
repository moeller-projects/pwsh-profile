$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'

# Opt-out of telemetry if running as SYSTEM
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Test-IsInteractive {
    if ($PSVersionTable.PSInteractiveSession -eq $true) { return $true }
    try { $null = $Host.UI.RawUI; return $true } catch { return $false }
}

function Test-CommandExists {
    param($command)
    return $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}

function Initialize-Theme
{
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/json.omp.json" | Invoke-Expression
}

function Initialize-PSReadLine {
    $psReadLineOptions = @{
        EditMode                      = 'Windows'
        HistoryNoDuplicates           = $true
        HistorySearchCursorMovesToEnd = $true
        Colors = @{
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
        PredictionSource    = 'History'
        PredictionViewStyle = 'ListView'
        BellStyle           = 'None'
    }
    Set-PSReadLineOption @psReadLineOptions

    $keyHandlers = @(
        @{ Key = 'UpArrow';         Function = 'HistorySearchBackward' },
        @{ Key = 'DownArrow';       Function = 'HistorySearchForward' },
        @{ Key = 'Tab';             Function = 'MenuComplete' },
        @{ Chord = 'Ctrl+d';        Function = 'DeleteChar' },
        @{ Chord = 'Ctrl+w';        Function = 'BackwardDeleteWord' },
        @{ Chord = 'Alt+d';         Function = 'DeleteWord' },
        @{ Chord = 'Ctrl+LeftArrow';Function = 'BackwardWord' },
        @{ Chord = 'Ctrl+RightArrow';Function = 'ForwardWord' },
        @{ Chord = 'Ctrl+z';        Function = 'Undo' },
        @{ Chord = 'Ctrl+y';        Function = 'Redo' },
        @{ Key = 'Ctrl+l';          Function = 'ClearScreen' },
        @{ Chord = 'Enter';         Function = 'ValidateAndAcceptLine' },
        @{ Chord = 'Ctrl+Enter';    Function = 'AcceptSuggestion' },
        @{ Chord = 'Alt+v';         Function = 'SwitchPredictionView' }
    )

    foreach ($handler in $keyHandlers) {
    if ($handler.ContainsKey('Key')) {
    Set-PSReadLineKeyHandler -Key $handler.Key -Function $handler.Function
    } elseif ($handler.ContainsKey('Chord')) {
    Set-PSReadLineKeyHandler -Chord $handler.Chord -Function $handler.Function
    }
    }

    # Add sensitive data filter to history
    Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitivePatterns = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    return -not ($sensitivePatterns | Where-Object { $line -match $_ })
    }

    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -MaximumHistoryCount 10000
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -HistorySavePath "$env:APPDATA\PSReadLine\CommandHistory.txt"
}

function Initialize-Profile {
    $EDITOR = foreach ($cmd in 'nvim', 'pvim', 'vim', 'vi', 'code', 'notepad++', 'sublime_text') {
        if (Test-CommandExists $cmd) { $cmd; break }
    }
    if (-not $EDITOR) { $EDITOR = 'notepad' }
    Set-Alias -Name vim -Value $EDITOR

    Initialize-Theme
    Initialize-PSReadLine
}

function Resolve-SymlinkPath {
    param (
        [string]$Path
    )
    if (-not (Test-Path $Path)) {
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


$ProfileSymlinkPath = $MyInvocation.MyCommand.Definition
$ProfileRepoFullPath = Resolve-SymlinkPath -Path $ProfileSymlinkPath
if ([string]::IsNullOrEmpty($ProfileRepoFullPath)) {
    Write-Error "Konnte den Repository-Pfad des Profils nicht ermitteln. Skripte können nicht geladen werden."
    return
}
$ProfileRepoPath = Split-Path -Parent $ProfileRepoFullPath
. (Join-Path $ProfileRepoPath "functions/import-modules.ps1")
Import-RequiredModules
. (Join-Path $ProfileRepoPath "functions/setup-autocompletions.ps1")
Initialize-Completion
. (Join-Path $ProfileRepoPath "functions/ai-functions.ps1")
. (Join-Path $ProfileRepoPath "functions/azure-functions.ps1")
. (Join-Path $ProfileRepoPath "functions/kubernetes-functions.ps1")
. (Join-Path $ProfileRepoPath "functions/dev-functions.ps1")
. (Join-Path $ProfileRepoPath "functions/file-functions.ps1")
. (Join-Path $ProfileRepoPath "functions/git-functions.ps1")
. (Join-Path $ProfileRepoPath "functions/network-functions.ps1")

$dotnetCompleter = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
    ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $dotnetCompleter

Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    $env:_ARGCOMPLETE_SHELL = 'powershell'
    az 2>&1 | Out-Null
    Get-Content $completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}

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

if (Test-IsInteractive -eq $true)
{
    $adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
    $Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

    Initialize-Profile
}

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
