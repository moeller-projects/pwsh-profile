# pwsh-profile

[![PowerShell Static Analysis](https://github.com/moeller-projects/pwsh-profile/actions/workflows/powershell-analysis.yml/badge.svg)](https://github.com/moeller-projects/pwsh-profile/actions/workflows/powershell-analysis.yml)

## CI
- Static analysis runs on pushes and PRs via GitHub Actions (`powershell-analysis.yml`).
- It installs PSScriptAnalyzer and checks all `.ps1` files using the repo settings `PSScriptAnalyzerSettings.psd1`.
- The job fails on findings and prints a concise table of issues to logs.

Run locally
- `pwsh -NoProfile -Command "Install-Module PSScriptAnalyzer -Scope CurrentUser -Force; Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -ReportSummary"`

## Usage
- Setup profile link (admin): `pwsh -ExecutionPolicy Bypass -File ./setup.ps1`
- Reload profile for testing: `. ./profile.ps1`
- Measure load time: `pwsh -File ./test-loading-time.ps1` (baseline uses `-NoProfile`)

Dependencies (optional but recommended)
- `git`, `fzf`, `oh-my-posh`, `PSReadLine`, `PSFzf`, `az` (Azure CLI), `kubectl`, `dotnet`

## Module Usage (optional)
- This repo includes a lightweight module that re-exports functions from `functions/`.
- Import directly from the repo without installation:
  - `Import-Module $(Join-Path $PWD 'PwshProfile/PwshProfile.psd1') -Force`
- Or copy `PwshProfile/` into a folder on `$env:PSModulePath` and then:
  - `Import-Module PwshProfile`

## Smoke Tests
- A non-destructive smoke-test harness exercises safe functions individually.
- Run: `pwsh -File ./scripts/Invoke-Smoketests.ps1 -VerboseOutput`
- The script creates a temporary workspace, uses `-WhatIf` for destructive commands, and prints a pass/fail summary.
