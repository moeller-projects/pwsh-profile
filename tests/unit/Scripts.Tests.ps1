BeforeAll {
    . (Join-Path $PSScriptRoot '..\helpers\TestHelpers.ps1')
}

Describe 'standalone scripts' {
    It 'returns structured timing data from test-loading-time.ps1' {
        $repoRoot = Get-RepoRoot
        $scriptPath = Join-Path $repoRoot 'test-loading-time.ps1'
        $result = Invoke-PwshTestCommand -Command "& '$scriptPath' -Iterations 1 | ConvertTo-Json -Compress"

        $result.ExitCode | Should -Be 0
        $payload = ($result.Output -join "`n" | ConvertFrom-Json)
        $payload.Iterations | Should -Be 1
        $payload.AverageProfileOverheadMs | Should -Not -BeNullOrEmpty
    }

    It 'returns a non-zero exit code when the smoke harness detects a failure' {
        $repoRoot = Get-RepoRoot
        $scriptPath = Join-Path $repoRoot 'scripts/Invoke-Smoketests.ps1'
        $result = Invoke-PwshTestCommand -Environment @{ PWSH_PROFILE_SMOKE_FORCE_FAILURE = '1' } -Command "& '$scriptPath'"

        $result.ExitCode | Should -Be 1
    }
}
