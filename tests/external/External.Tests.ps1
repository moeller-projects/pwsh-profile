BeforeAll {
    . (Join-Path $PSScriptRoot '..\helpers\TestHelpers.ps1')
}

Describe 'external dependency coverage' {
    It 'classifies every external dependency command with a skip reason' {
        $inventory = Get-CommandInventory | Where-Object { $_.TestType -eq 'external-skip' }
        foreach ($entry in $inventory) {
            $entry.SkipReason | Should -Not -BeNullOrEmpty
        }
    }
}
