BeforeAll {
    . (Join-Path $PSScriptRoot '..\helpers\TestHelpers.ps1')
    $repoRoot = Get-RepoRoot
    $profilePath = Join-Path $repoRoot 'profile.ps1'
}

Describe 'profile loading' {
    It 'loads without throwing in non-interactive CI contexts' {
        $result = Invoke-PwshTestCommand -Environment @{
            CI                       = 'true'
            PWSH_PROMPT              = 'plain'
            PWSH_PROFILE_COMPLETIONS = '0'
        } -Command ". '$profilePath'"

        $result.ExitCode | Should -Be 0
    }
}
