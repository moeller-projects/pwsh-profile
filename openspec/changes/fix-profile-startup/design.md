## Context

The profile currently imports local commands through a module created in an OnIdle event action. The wrapper exports only an alias, so its nested module commands do not reach the user session. The hot path also starts prompt executables and a git integration.

## Goals / Non-Goals

**Goals:**
- Make local commands available before the first prompt.
- Keep integrations optional or deferred without adding dependencies.
- Preserve existing command names except the unsafe remote-execution helpers.

**Non-Goals:**
- Benchmark-specific performance targets.
- Installing, configuring, or lazy-loading third-party modules on demand.

## Decisions

- Import the repository manifest by absolute path synchronously. This avoids module discovery and wrapper-module scope boundaries.
- Retain the existing OnIdle event only for integrations, with explicit global scope where state must persist.
- Make prompt engines and external completions opt in. A plain prompt is always available.
- Use script blocks created from trusted local tool output instead of `Invoke-Expression`; remove the two remote download-and-execute helpers.

## Risks / Trade-offs

- Defining all local functions costs a small fixed startup amount, but is required for immediate command availability.
- Users wanting prompt engines or generated completions must set the corresponding environment toggles.
- Removing `winutil` commands is a deliberate security-breaking change; users must invoke external setup scripts explicitly.
