# pwsh-profile

[![Validate PowerShell Profile](https://github.com/moeller-projects/pwsh-profile/actions/workflows/validate.yml/badge.svg)](https://github.com/moeller-projects/pwsh-profile/actions/workflows/validate.yml)

PowerShell profile repository with:

- `profile.ps1` as the interactive entrypoint
- reusable functions in `functions/`
- an installable module in `PwshProfile/`
- standalone scripts in `scripts/`
- Pester tests, smoke tests, and publish workflows

## Install options

### Option 1: module-first

When the module is published to PSGallery:

```powershell
Install-Module PwshProfile -Scope CurrentUser
Import-Module PwshProfile
```

### Option 2: repo/bootstrap profile setup

Clone the repo and point your profile to the checked-out `profile.ps1`:

```powershell
pwsh -ExecutionPolicy Bypass -File ./setup.ps1
```

Safe validation is supported:

```powershell
pwsh -ExecutionPolicy Bypass -File ./setup.ps1 -WhatIf
```

## What is module vs script vs profile-only

- **Module (`PwshProfile/`)**: reusable commands importable with `Import-Module`.
- **Profile (`profile.ps1`)**: interactive shell startup, prompt setup, deferred init, profile-only helpers.
- **Scripts (`scripts/`)**:
  - `Invoke-Smoketests.ps1`: CI-safe smoke harness
  - `add-database-firewall-rules.ps1`: publishable cloud access helper
  - `add-windows-defender-exclusions-for-jetbrains.ps1`: publishable Windows admin helper

## Local development and test commands

```powershell
# Reload the profile during development
. ./profile.ps1

# Static analysis
pwsh -NoLogo -NoProfile -Command "Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -ReportSummary"

# Unit, smoke, and external-classification tests
pwsh -NoLogo -NoProfile -Command "Invoke-Pester -Path ./tests/unit,./tests/smoke,./tests/external -CI -Output Detailed"

# Smoke harness only
pwsh -NoLogo -NoProfile -File ./scripts/Invoke-Smoketests.ps1 -VerboseOutput

# Profile timing
pwsh -NoLogo -NoProfile -Command "& ./test-loading-time.ps1 -Iterations 5"
```

## Test layout

- `tests/unit/`: deterministic unit coverage and script/module validation
- `tests/smoke/`: CI-safe command smoke coverage
- `tests/external/`: explicit coverage for commands intentionally skipped in CI
- `tests/helpers/`: shared Pester helpers
- `tests/command-inventory.json`: command/script inventory and coverage gate

Skipped tests are intentional for commands that require:

- external tools like `az`, `kubectl`, `fzf`, `tgpt`, `eza`
- outbound network access
- Windows-only APIs or admin privileges
- interactive prompts

The inventory test fails when new functions or scripts are added without classification.

## CI overview

`validate.yml` runs on pushes, pull requests, and workflow calls. It validates:

- PSScriptAnalyzer with repo settings
- module manifest importability
- publishable script metadata
- Pester unit tests
- smoke tests
- external-dependency classification tests

Validation runs on:

- `ubuntu-latest`
- `windows-latest`

## Publishing overview

### Module publishing

`publish-module.yml`:

- runs validation first
- validates module manifest metadata
- publishes `PwshProfile/PwshProfile.psd1`
- requires repository secret `PSGALLERY_API_KEY`

### Script publishing

`publish-scripts-to-psgallery.yml`:

- runs validation first
- publishes only scripts marked `publishable` in `tests/command-inventory.json`
- validates script metadata with `Test-ScriptFileInfo`
- requires repository secret `PSGALLERY_API_KEY`

## Dependency model

- Core profile/module commands are designed to load without optional tools.
- Optional integrations are dependency-guarded and skip cleanly when unavailable.
- State-changing commands support `-WhatIf`/`-Confirm` where practical.
- Remote/network/system-mutating commands are not forced during CI.

## Platform notes

- The module imports on Linux and Windows.
- Windows-only commands remain available but are guarded.
- `profile.ps1` avoids Windows-only assumptions during non-interactive CI loads.
- `add-windows-defender-exclusions-for-jetbrains.ps1` is Windows/admin only.

## Command coverage inventory

Inventory data lives in `tests/command-inventory.json` and tracks:

- command or script name
- source file
- exported vs internal status
- category
- dependencies
- platform support
- test classification
- skip reason where CI execution is intentionally disabled
