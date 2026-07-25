# pwsh-profile

[![PowerShell Static Analysis](https://github.com/moeller-projects/pwsh-profile/actions/workflows/powershell-analysis.yml/badge.svg)](https://github.com/moeller-projects/pwsh-profile/actions/workflows/powershell-analysis.yml)

## Overview

This repository contains a fast-loading PowerShell profile plus a lightweight module that exposes the same helper functions for ad hoc import. The profile keeps the first prompt responsive by loading only essential settings immediately and deferring optional setup until `PowerShell.OnIdle`.

Use it to get consistent interactive helpers for:

- Git branch, cleanup, repository summary, and AI commit workflows.
- File navigation, search, clipboard, archive, and recycle-bin tasks.
- Project-root jumping via user configuration.
- Azure, Kubernetes, network, and local development shortcuts.
- Prompt, PSReadLine, and optional completion setup.

## Getting Started

1. Clone the repository.
2. Create the profile symlink from the target host:
   ```powershell
   pwsh -ExecutionPolicy Bypass -File ./setup.ps1
   ```
   Run this from `pwsh` for PowerShell 7+ and from `powershell.exe` for Windows PowerShell 5.1. Each host uses a different `$PROFILE` path; run it once per host if you use both.

   If symlink creation fails (e.g. lacking admin rights), pass `-NoSymlink` to write a one-line loader instead:
   ```powershell
   pwsh -ExecutionPolicy Bypass -File ./setup.ps1 -NoSymlink
   ```
3. Restart PowerShell, or reload during development:
   ```powershell
   . ./profile.ps1
   ```
4. Measure startup after profile changes:
   ```powershell
   pwsh -File ./test-loading-time.ps1
   ```

Optional but recommended tools:

- `git`, `fzf`, `oh-my-posh`, `PSReadLine`, `PSFzf`, `az` (Azure CLI), `kubectl`, `dotnet`

## Quality Checks

Static analysis runs on pushes and pull requests via GitHub Actions (`.github/workflows/powershell-analysis.yml`). The workflow installs PSScriptAnalyzer and checks all `.ps1` files with `PSScriptAnalyzerSettings.psd1`. A smoke-test job also runs on both Windows and Linux.

Run the same check locally:

```powershell
pwsh -NoProfile -Command "Install-Module PSScriptAnalyzer -Scope CurrentUser -Force; Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -ReportSummary"
```

## Module Usage

The profile adds this repository to `PSModulePath` and PowerShell autoloads only the function area a command needs. For example, `touch` loads `PwshProfile.File`; `Switch-GitBranch` loads `PwshProfile.Git`; `Enter-ProjectDirectory` loads `PwshProfile.Projects`.

Import an area explicitly when using the repository without the profile:

```powershell
Import-Module $(Join-Path $PWD 'PwshProfile.File/PwshProfile.File.psd1')
```

The aggregate `PwshProfile` module remains available for callers that need every helper in one import:

```powershell
Import-Module $(Join-Path $PWD 'PwshProfile/PwshProfile.psd1')
```

## Common Commands

| Area | Examples |
| --- | --- |
| Files | `touch`, `nf`, `Find-File`, `grep`, `head`, `tail`, `mkcd`, `trash` |
| Git | `Switch-GitBranch`, `Remove-MergedGitBranches`, `Get-RepoSize`, `Get-BranchStatus`, `Optimize-GitRepository`, `Invoke-AiCommit` |
| Projects | `Set-ProjectPaths`, `Enter-ProjectDirectory` (module: `PwshProfile.Projects`) |
| Development | `which`, `export`, `uptime`, `pgrep`, `pkill`, `Get-ProcessPort`, `Stop-ProcessPort -WhatIf`, `Use-Env` |
| Cloud/Kubernetes | `Switch-AzureSubscription`, `Connect-ContainerRegistry`, `Select-KubeContext`, `Select-KubeNamespace` |

## Smoke Tests

A non-destructive smoke-test harness exercises safe functions individually. It creates a temporary workspace, uses `-WhatIf` for destructive commands, and prints a pass/fail summary.

```powershell
pwsh -File ./scripts/Invoke-Smoketests.ps1 -VerboseOutput
```

## Configuration

Project roots for `Enter-ProjectDirectory` are read from user config:

- Windows: `%APPDATA%/pwsh-profile/config.json`
- Linux/macOS: `~/.config/pwsh-profile/config.json`

Example:

```json
{ "ProjectRoots": ["D:/projects/private", "D:/projects/work"] }
```

Set paths permanently:

```powershell
Set-ProjectPaths -Paths @('D:/p1','D:/p2')
```

Set paths temporarily for the current environment:

```powershell
$env:PWSH_PROJECT_PATHS = 'D:/p1;D:/p2'
```

## Performance

The profile keeps the initial path setup and aliases synchronous; function-area modules autoload only when used. Prompt engines, optional modules, PSReadLine customization, and generated completions remain deferred or opt-in. Shell-init scripts (starship, oh-my-posh, zoxide, volta, pixi, mise, git-wt, kiro) are cached in `~/.cache/pwsh-profile` (or `%LOCALAPPDATA%\pwsh-profile\cache` on Windows) and only regenerated when the tool version changes. Measure load time with multiple iterations:

```powershell
pwsh -File ./test-loading-time.ps1 -Iterations 20
```

Environment toggles:

| Variable | Values | Effect |
| --- | --- | --- |
| `PWSH_PROMPT` | `posh`, `starship` | Enables the selected prompt engine after the first prompt. Unset uses the default PowerShell prompt. |
| `PWSH_PREDICTION` | `plugin` | Enables PSReadLine `HistoryAndPlugin`; otherwise history-only prediction is used. |
| `PWSH_PROFILE_PSREADLINE` | `1` | Applies the profile's PSReadLine key bindings and colors after importing PSReadLine. |
| `PWSH_PROFILE_COMPLETIONS` | `1` | Enables external completions for Volta, Pixi, Zoxide, Mise, and Kiro. |
| `PWSH_PROFILE_IMPORT_OPTIONAL` | `1` | Imports optional profile modules, including PSMenu, InteractiveMenu, CompletionPredictor, ImportDotEnv, Terminal-Icons, and PSFzf. If any are missing, a warning lists the install command. |
| `PWSH_PROFILE_GIT_WT` | `1` | Enables `git-wt` shell integration after the first prompt. |
| `PWSH_PROFILE_TIMING` | `1` | At idle, prints a timing summary of profile load checkpoints. |

`ImportDotEnv` remains available when optional modules are imported, but profile startup never loads a `.env` file or enables directory-change integration. Enable it manually with `Enable-ImportDotEnvCdIntegration` when wanted.

## Migration Notes (from pre-1.1.0)

The following public names have been removed:

| Removed name | Reason | Alternative |
| --- | --- | --- |
| `gdev`, `gmain`, `gup`, `gsave` | Depended on personal git aliases (`git co`, `git get`, `git ss`) | Use `git switch`/`git pull` directly |
| `gsw` | Duplicate of `Switch-GitBranch` (`gg`) | Use `Switch-GitBranch` or `gg` |
| `cna` / `New-NetworkAccessExceptionForResources` | Remote download-and-execute pattern; removed by security policy | Use `scripts/add-database-firewall-rules.ps1` |
| `Format-FileSize` | Duplicate of `ConvertTo-HumanReadableSize` | Use `ConvertTo-HumanReadableSize` |

`PWSH_PROFILE_AUTO_INSTALL` is no longer supported. If optional modules are missing, the profile emits a `Write-Warning` listing the install command instead of silently running `Install-Module`.

Project-jumping functions (`Enter-ProjectDirectory`, `Get-ProjectPaths`, `Set-ProjectPaths`, `Get-ProjectConfigPath`) have moved from `PwshProfile.Dev` to a dedicated `PwshProfile.Projects` module. Autoloading is unaffected; the commands still work without explicit imports.

## Repository Layout

```text
profile.ps1                         # Fast profile entry point
functions/                          # Area-based helper implementations
PwshProfile.*/                      # Autoloadable function-area modules (includes PwshProfile.Projects)
PwshProfile/                        # Backward-compatible aggregate module
scripts/Invoke-Smoketests.ps1       # Non-destructive smoke-test harness
setup.ps1                           # Symlink/loader setup script for $PROFILE (-NoSymlink for no-admin fallback)
test-loading-time.ps1               # Startup timing script
PSScriptAnalyzerSettings.psd1        # Static-analysis settings
```
