BeforeAll {
    . (Join-Path $PSScriptRoot '..\helpers\TestHelpers.ps1')
    $repoRoot = Get-RepoRoot
}

Describe 'smoke harness' {
    It 'passes in the default CI-safe configuration' {
        $scriptPath = Join-Path $repoRoot 'scripts/Invoke-Smoketests.ps1'
        $result = Invoke-PwshTestCommand -Command "& '$scriptPath'"

        $result.ExitCode | Should -Be 0
    }
}
