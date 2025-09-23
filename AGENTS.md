# Repository Guidelines

## Project Structure & Module Organization
- `profile.ps1`: Entry point loaded by PowerShell. Orchestrates module import and completion setup with fast startup and deferred init.
- `functions/`: Themed modules (e.g., `git-functions.ps1`, `file-functions.ps1`, `azure-functions.ps1`). Add new helpers here using the same `*-functions.ps1` pattern.
- `setup.ps1`: Creates a symbolic link from this repo’s `profile.ps1` to `$PROFILE` (requires admin).
- `test-loading-time.ps1`: Measures profile load performance.
- `docs/`, `.vscode/`: Developer docs and editor settings.

## Build, Test, and Development Commands
- Setup link (run as admin): `pwsh -ExecutionPolicy Bypass -File ./setup.ps1`
- Reload profile during development: `. ./profile.ps1`
- Open a clean shell (no profile): `pwsh -NoProfile`
- Measure load time: `pwsh -File ./test-loading-time.ps1`
- Lint (requires PSScriptAnalyzer): `Invoke-ScriptAnalyzer -Path . -Recurse`

## Coding Style & Naming Conventions
- PowerShell style: 4-space indent; one function per concern; prefer advanced functions with `[CmdletBinding()]`.
- Naming: Verb-Noun for functions (e.g., `Git-Go`, `Resolve-SymlinkPath`); PascalCase for functions/parameters; file names `*-functions.ps1` by area.
- Performance: Keep `profile.ps1` fast; avoid heavy work in the hot path. Defer slow ops (use event/lazy init) and guard external calls with `Test-CommandExists`.

## Static Analysis (PSScriptAnalyzer)
- Settings file: `PSScriptAnalyzerSettings.psd1` (repo root) excludes interactive-heavy rules and enforces `ShouldProcess` where practical.
- Run locally:
  - `pwsh -NoLogo -NoProfile -Command "Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -ReportSummary"`
- Rule notes: We intentionally relax `PSAvoidUsingWriteHost` and `PSAvoidUsingInvokeExpression` for interactive UX and completions; prefer `Write-Verbose` elsewhere.

## Clean Code Standards
- Single responsibility: short, focused functions (<50 lines) with clear inputs/outputs.
- Prefer early-return guards over deep nesting; validate parameters via attributes.
- Pipeline-friendly: output objects, not formatted strings; keep `Write-Host` for UX only.
- Error handling: use `throw` for unrecoverable errors; surface user issues with `Write-Error`/`-ErrorAction` support; add `-WhatIf`/`-Confirm` when destructive.
- Naming/semantics: use approved PowerShell verbs; avoid abbreviations; keep side effects explicit.
- Defaults/logging: quiet by default; use `Write-Verbose` for details and `Write-Debug` for deep tracing; no noisy output in profile startup.
- Comments/docs: explain “why”, not “what”; include `.SYNOPSIS` and examples for public functions.

## Testing Guidelines
- Smoke test: dot-source the profile and exercise new commands: `. ./profile.ps1` then run the function(s).
- Performance test: run `./test-loading-time.ps1` and note before/after timings for changes affecting startup.
- Optional: Use Pester for unit tests; place under `tests/` with `*.Tests.ps1` names.

## Commit & Pull Request Guidelines
- Conventional Commits are used (see history): `feat:`, `fix:`, `docs:`, `refactor:`, etc.
- Commits: present tense, concise scope, include context (e.g., affected function/file).
- PRs: clear description, rationale, sample commands used, and performance notes if relevant (startup deltas). Link related issues.

## Security & Configuration Tips
- Do not commit secrets or machine-specific paths. Use environment variables or local config outside the repo.
- `setup.ps1` creates a symlink to `$PROFILE` and may require admin rights; verify paths before running.
