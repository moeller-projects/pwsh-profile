# Implementation Report

## What was fixed

- Hardened profile startup for non-interactive and non-Windows CI contexts.
- Added dependency guards and safer `-WhatIf`/`-Confirm` behavior to state-changing helpers and scripts.
- Fixed the smoke harness so failures are tracked correctly and exit codes are reliable.
- Reworked `setup.ps1` and `test-loading-time.ps1` into testable, safer scripts.
- Made module exports explicit and tightened module/package metadata.
- Added command inventory coverage plus Pester unit, smoke, and external-classification tests.
- Replaced the old analysis/publish workflows with validate-before-publish workflows.

## What was intentionally skipped

- Interactive commands that require live tools or credentials (`az`, `kubectl`, `fzf`, `tgpt`, `lumen`, `eza`) remain classified as skipped in CI.
- Remote-script helpers and cloud/firewall mutators are validated by inventory and metadata, not executed in CI.
- Windows/admin-only Defender and elevation scenarios remain skipped outside supported environments.

## Publishing model chosen

- **Module-first**: publish `PwshProfile` to PSGallery as the primary reusable package.
- **Script publishing**: publish only explicitly classified scripts with valid `PSScriptInfo` metadata.
- **Repo/bootstrap**: keep `setup.ps1` as the documented profile bootstrap path for colleagues using the whole repo.

## Remaining limitations

- Interactive selectors still depend on optional third-party tools and are not practical to execute in CI.
- Remote-script commands are intentionally confirmation-gated but still trust their configured upstream URLs when run.
- Script publishing assumes PSGallery credentials are supplied via the `PSGALLERY_API_KEY` repository secret.

## Exact install commands for colleagues

### Module

```powershell
Install-Module PwshProfile -Scope CurrentUser
Import-Module PwshProfile
```

### Repo bootstrap

```powershell
git clone https://github.com/moeller-projects/pwsh-profile.git
cd pwsh-profile
pwsh -ExecutionPolicy Bypass -File ./setup.ps1
```
