## Context

The profile now exposes local helpers through an aggregate module, which adds a fixed parse and export cost before every prompt. The hot path also starts prompt executables and optional integrations.

## Goals / Non-Goals

**Goals:**
- Make local commands available through PowerShell module autoloading.
- Keep integrations optional or deferred without adding dependencies.
- Preserve existing command names except the unsafe remote-execution helpers.
- Provide safe, native port inspection and termination helpers.

**Non-Goals:**
- Benchmark-specific performance targets.
- Installing, configuring, or lazy-loading third-party modules on demand.

## Decisions

- Replace the synchronous aggregate import with function-area modules whose manifests explicitly declare exported functions and aliases. PowerShell can discover a command without loading unrelated areas.
- Retain the existing OnIdle event only for optional integrations and import its small integration module only when a corresponding toggle is enabled.
- Make prompt engines and external completions opt in. A plain prompt is always available.
- Use script blocks created from trusted local tool output instead of `Invoke-Expression`; remove the two remote download-and-execute helpers.
- Use `Get-NetTCPConnection` and `Stop-Process` with `ShouldProcess` for port helpers rather than adding dependencies.

## Risks / Trade-offs

- The first invocation of a command in each function area pays its module-load cost; all other areas stay unloaded.
- Users wanting prompt engines or generated completions must set the corresponding environment toggles.
- Removing `winutil` commands is a deliberate security-breaking change; users must invoke external setup scripts explicitly.
