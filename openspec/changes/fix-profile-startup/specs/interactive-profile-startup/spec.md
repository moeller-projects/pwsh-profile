## ADDED Requirements

### Requirement: Lazy local command availability
The interactive PowerShell profile MUST add the repository root to `PSModulePath` before the first prompt, and each function area MUST expose its commands through an autoloadable module manifest.

#### Scenario: Invoking a local helper
- **WHEN** a user invokes a helper from an unloaded function area
- **THEN** PowerShell autoloads only that area module and executes the helper

### Requirement: Portable module search path
The profile MUST use the platform path separator when it adds the repository root to `PSModulePath`.

#### Scenario: Loading on a non-Windows platform
- **WHEN** the profile runs on Linux or macOS
- **THEN** the added module-search entry remains distinct from existing entries

### Requirement: Optional integrations
The profile MUST NOT initialize external prompt engines, generated external completions, or optional third-party modules unless their documented environment toggle enables them.

#### Scenario: Default profile startup
- **WHEN** no profile integration environment toggles are set
- **THEN** startup does not execute external prompt, git integration, or completion initialization commands

### Requirement: Local-only initialization
The profile MUST NOT expose convenience commands that download and immediately execute remote PowerShell content.

#### Scenario: Loading the profile
- **WHEN** the profile is imported
- **THEN** no remote PowerShell content is downloaded or executed

### Requirement: Explicit dotenv activation
The profile MUST NOT load a `.env` file or enable ImportDotEnv directory-change integration during completion initialization.

#### Scenario: Enabled external completions
- **WHEN** `PWSH_PROFILE_COMPLETIONS` is set to `1`
- **THEN** completion initialization does not invoke `Import-DotEnv` or `Enable-ImportDotEnvCdIntegration`

### Requirement: Local port helpers
The profile MUST provide `Get-ProcessPort` to return the local listening process for a requested port and `Stop-ProcessPort` with `SupportsShouldProcess` to terminate its listening processes.

#### Scenario: Inspecting a listener
- **WHEN** a process listens on a requested local port
- **THEN** `Get-ProcessPort` returns its port, process ID, process name, and state

#### Scenario: Previewing process termination
- **WHEN** `Stop-ProcessPort` is invoked with `-WhatIf`
- **THEN** it reports the target process without terminating it
