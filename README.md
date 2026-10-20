# pwsh-profile

[![PowerShell Static Analysis](https://github.com/moeller-projects/pwsh-profile/actions/workflows/powershell-analysis.yml/badge.svg)](https://github.com/moeller-projects/pwsh-profile/actions/workflows/powershell-analysis.yml)

A fast-loading PowerShell profile with autoloadable modules for Git, files, project navigation, development, Azure, Kubernetes, networking, and AI helpers. Core profile setup runs before the first prompt; optional integrations are deferred or enabled through environment variables.

## Install

Clone this repository, then run the setup script from the PowerShell host you want to configure:

```powershell
pwsh -ExecutionPolicy Bypass -File ./setup.ps1
```

Use `powershell.exe` instead of `pwsh` to configure Windows PowerShell 5.1. Each host has its own `$PROFILE`; run setup separately for each host you use.

If symbolic-link creation is unavailable, create a loader file instead:

```powershell
pwsh -ExecutionPolicy Bypass -File ./setup.ps1 -NoSymlink
```

Restart PowerShell to load the profile. During development, reload it with:

```powershell
. ./profile.ps1
```

## Use the modules

The profile adds the repository root to `PSModulePath`. PowerShell then autoloads the area module that provides a requested command. For example, `touch` comes from `PwshProfile.File`, `Switch-GitBranch` from `PwshProfile.Git`, and `Enter-ProjectDirectory` from `PwshProfile.Projects`.

When using a command without loading the profile, import its area module explicitly:

```powershell
Import-Module (Join-Path $PWD 'PwshProfile.File/PwshProfile.File.psd1')
```

To import all helpers, use the aggregate module:

```powershell
Import-Module (Join-Path $PWD 'PwshProfile/PwshProfile.psd1')
```

## Commands

| Area | Examples |
| --- | --- |
| Files | `touch`, `nf`, `Find-File`, `grep`, `head`, `tail`, `mkcd`, `trash` |
| Git | `Switch-GitBranch`, `Remove-MergedGitBranches`, `Get-RepoSize`, `Get-BranchStatus`, `Optimize-GitRepository`, `Invoke-AiCommit` |
| Projects | `Set-ProjectPaths`, `Enter-ProjectDirectory` |
| Development | `which`, `export`, `uptime`, `pgrep`, `pkill`, `Get-ProcessPort`, `Stop-ProcessPort`, `Use-Env` |
| Azure and Kubernetes | `Switch-AzureSubscription`, `Connect-ContainerRegistry`, `Select-KubeContext`, `Select-KubeNamespace` |

Use `Stop-ProcessPort -WhatIf` to preview the process termination action.

## Configuration

Project roots used by `Enter-ProjectDirectory` are stored in user configuration:

- Windows: `%APPDATA%/pwsh-profile/config.json`
- Linux and macOS: `~/.config/pwsh-profile/config.json`

Example:

```json
{ "ProjectRoots": ["D:/projects/private", "D:/projects/work"] }
```

Set the saved roots from PowerShell:

```powershell
Set-ProjectPaths -Paths @('D:/projects/private', 'D:/projects/work')
```

For a temporary override in the current process, set `PWSH_PROJECT_PATHS` to a semicolon-separated list:

```powershell
$env:PWSH_PROJECT_PATHS = 'D:/projects/private;D:/projects/work'
```

## Optional integrations

Integrations are opt-in. Unset toggles leave the corresponding integration disabled.

| Variable | Effect |
| --- | --- |
| `PWSH_PROMPT=starship` or `PWSH_PROMPT=posh` | Initialize the selected prompt engine after the first prompt. |
| `PWSH_PREDICTION=plugin` | Select PSReadLine `HistoryAndPlugin` prediction; otherwise history prediction is used when enabled. |
| `PWSH_PROFILE_PSREADLINE=1` | Configure PSReadLine key bindings, colors, and history behavior. |
| `PWSH_PROFILE_COMPLETIONS=1` | Initialize supported external completions and integrations, including Volta, Pixi, Zoxide, Mise, fnm (`--use-on-cd`), and Kiro. |
| `PWSH_PROFILE_IMPORT_OPTIONAL=1` | Import optional modules: PSMenu, InteractiveMenu, CompletionPredictor, ImportDotEnv, Terminal-Icons, and PSFzf. |
| `PWSH_PROFILE_GIT_WT=1` | Initialize `git-wt` shell integration. |
| `PWSH_PROFILE_TIMING=1` | Print profile timing checkpoints at idle. |

Some integrations require their external executable or PowerShell module to be installed. Missing optional modules are reported with an install command. Importing `ImportDotEnv` does not automatically load `.env` files or enable directory-change integration; activate that behavior manually with `Enable-ImportDotEnvCdIntegration` if needed.

## Performance

The profile performs essential settings and module-path setup synchronously. Command-area modules load on demand. Prompt engines, completion generation, optional modules, and other integrations run only when enabled and are deferred from initial startup.

Measure startup:

```powershell
pwsh -File ./test-loading-time.ps1
pwsh -File ./test-loading-time.ps1 -Iterations 20
```

## Development checks

Run the non-destructive smoke harness:

```powershell
pwsh -File ./scripts/Invoke-Smoketests.ps1 -VerboseOutput
```

Static analysis is run in CI on pushes and pull requests. With PSScriptAnalyzer installed, run it locally:

```powershell
pwsh -NoProfile -Command "Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -ReportSummary"
```

The smoke harness skips some platform-dependent and external-tool scenarios. Its output identifies skipped checks; those are not covered by a passing result.

## Repository layout

```text
profile.ps1                         # Profile entry point
functions/                          # Helper implementations by area
PwshProfile.<Area>/                 # Area modules and explicit exports
PwshProfile/                        # Aggregate module
setup.ps1                           # Profile symlink or loader setup
scripts/Invoke-Smoketests.ps1       # Smoke-test harness
test-loading-time.ps1               # Startup timing utility
openspec/                           # Change proposals and specifications
```

## Migration notes

The following names were removed before version 1.1.0:

| Removed name | Reason | Alternative |
| --- | --- | --- |
| `gdev`, `gmain`, `gup`, `gsave` | Relied on personal Git aliases such as `git co`, `git get`, and `git ss`. | Use `git switch` or `git pull` directly. |
| `gsw` | Duplicated `Switch-GitBranch`. | Use `Switch-GitBranch` or `gg`. |
| `cna`, `New-NetworkAccessExceptionForResources` | Used remote download-and-execute behavior. | Use `scripts/add-database-firewall-rules.ps1` where applicable. |
| `Format-FileSize` | Duplicated `ConvertTo-HumanReadableSize`. | Use `ConvertTo-HumanReadableSize`. |

Project-navigation commands moved from `PwshProfile.Dev` to `PwshProfile.Projects`; profile-based autoloading remains available.
