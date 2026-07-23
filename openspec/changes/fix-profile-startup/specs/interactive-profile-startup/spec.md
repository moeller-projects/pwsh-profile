## ADDED Requirements

### Requirement: Immediate local command availability
The interactive PowerShell profile MUST import the repository's `PwshProfile` module directly by its manifest path before registering deferred initialization.

#### Scenario: Opening an interactive pwsh session
- **WHEN** the profile repository and module manifest are present
- **THEN** functions exported by `PwshProfile` are available before the first prompt is accepted

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
