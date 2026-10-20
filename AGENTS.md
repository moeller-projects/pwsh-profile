# Repository Guide

This repository provides a fast-loading PowerShell profile and importable command modules. Keep startup predictable, preserve the module-autoloading contract, and make platform-specific behavior explicit.

## Repository map

- `profile.ps1`: Profile entry point. Applies fast settings, resolves the repository path, adds it to `PSModulePath`, and schedules opt-in interactive integrations for idle time.
- `functions/`: Implementations grouped by area, using `*-functions.ps1` filenames. `setup-autocompletions.ps1` and `import-modules.ps1` contain integration setup.
- `PwshProfile.<Area>/`: Area modules. Each module script dot-sources its implementation file; each manifest declares public exports. The profile's repository-root module path enables autoloading.
- `PwshProfile/`: Aggregate module for callers who intentionally want all helper functions in one import.
- `setup.ps1`: Configures the host profile using a symbolic link or `-NoSymlink` loader.
- `environment.ps1`: Setup-generated environment configuration; do not put machine-specific settings in tracked files.
- `scripts/`: Smoke-test harness and standalone scripts.
- `test-loading-time.ps1`: Startup timing utility.
- `openspec/`: Proposed behavior changes and their requirements, design, and tasks.

## Runtime and module contracts

- Keep synchronous profile work small. Prompt engines, generated completions, optional modules, and other external integrations must remain deferred or opt-in.
- Preserve area-level autoloading: add commands to the appropriate function file and update both the module script and manifest exports, including aliases.
- Keep the aggregate module aligned when changing public helper behavior; it is a separate supported import path.
- Use `[System.IO.Path]::PathSeparator` for module-search paths and account for Windows PowerShell 5.1 as well as PowerShell 7+.
- Guard optional executables and platform-specific commands before invoking them. Do not add remote download-and-execute helpers.
- Avoid `$global:` variables in module scope. Keep user configuration and secrets outside the repository.

## PowerShell conventions

- Use four-space indentation, approved `Verb-Noun` function names, and PascalCase parameters.
- Prefer focused advanced functions with `[CmdletBinding()]`, parameter attributes, clear pipeline-friendly outputs, and early validation.
- Use `SupportsShouldProcess` and honor `ShouldProcess` for destructive or externally visible actions.
- Keep default output quiet. Use `Write-Verbose` for diagnostics and reserve `Write-Host` for intentional interactive UX.
- Include help such as `.SYNOPSIS` and examples for public commands; explain why in comments rather than restating code.
- Follow `PSScriptAnalyzerSettings.psd1`; `Write-Host` is intentionally permitted for interactive UX.

## Development and verification

Run commands from the repository root:

- Install the profile link: `pwsh -ExecutionPolicy Bypass -File ./setup.ps1`
- Use a loader instead of a symlink: `pwsh -ExecutionPolicy Bypass -File ./setup.ps1 -NoSymlink`
- Reload during interactive development: `. ./profile.ps1`
- Start a clean shell: `pwsh -NoProfile`
- Run the smoke harness: `pwsh -File ./scripts/Invoke-Smoketests.ps1 -VerboseOutput`
- Measure profile startup: `pwsh -File ./test-loading-time.ps1`; use `-Iterations 20` for repeated measurements.
- Run static analysis when PSScriptAnalyzer is available: `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1`

For command changes, exercise the affected command through its area module or profile autoload path. For startup changes, check both startup behavior and timing. The smoke harness skips some external-tool and platform-specific scenarios; report those limits rather than treating skips as coverage.

## OpenSpec workflow

For planned behavior changes, inspect `openspec/specs/` and `openspec/changes/` before editing. Continue an existing relevant change when appropriate; otherwise create a focused kebab-case change directory with coherent proposal, delta spec, design when needed, and tasks. Each delta requirement needs a `MUST` or `SHALL` statement and an observable `WHEN`/`THEN` scenario. Keep task status consistent with work actually completed and validate the active change before completion.

## Changes and review

- Keep changes focused and update affected implementation, exports, documentation, and smoke coverage together.
- Use Conventional Commit messages, such as `fix: keep profile startup lazy`.
- Pull requests should state rationale, behavior changes, verification commands and results, plus startup timing notes when relevant.
