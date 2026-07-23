## Why

Custom profile commands are scoped to a deferred wrapper module and therefore are not available in new sessions. The startup path also performs avoidable module discovery and external-process initialization.

## What Changes

- Replace the eager aggregate module import with autoloadable function-area modules.
- Keep only path setup and aliases in the synchronous profile path.
- Defer or opt in to external prompt, completion, optional-module, and integration work.
- Add safe local-port inspection and termination commands.
- Remove remote code-execution convenience commands and repair the documented benchmark interface.
- Update setup and usage guidance for host-specific PowerShell profile locations.

## Capabilities

### New Capabilities
- `interactive-profile-startup`: Provides immediate availability of local profile commands with optional deferred integrations.

### Modified Capabilities
- None.

## Impact

- `profile.ps1`, function-area modules, `functions/dev-functions.ps1`, `functions/import-modules.ps1`, `functions/setup-autocompletions.ps1`, `setup.ps1`, `test-loading-time.ps1`, `README.md`, analyzer settings, and smoke tests.
- The removed `winutil` and `winutildev` commands are breaking removals; users can run their chosen setup scripts explicitly instead.
