## Why

Custom profile commands are scoped to a deferred wrapper module and therefore are not available in new sessions. The startup path also performs avoidable module discovery and external-process initialization.

## What Changes

- Import the local function module directly into the profile session before the first prompt.
- Make module-path handling portable and simplify deferred initialization.
- Defer or opt in to external prompt, completion, and optional-module work.
- Remove remote code-execution convenience commands and repair the documented benchmark interface.
- Update setup and usage guidance for host-specific PowerShell profile locations.

## Capabilities

### New Capabilities
- `interactive-profile-startup`: Provides immediate availability of local profile commands with optional deferred integrations.

### Modified Capabilities
- None.

## Impact

- `profile.ps1`, `functions/import-modules.ps1`, `functions/setup-autocompletions.ps1`, `setup.ps1`, `test-loading-time.ps1`, `README.md`, and analyzer settings.
- The removed `winutil` and `winutildev` commands are breaking removals; users can run their chosen setup scripts explicitly instead.
