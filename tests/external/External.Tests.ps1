BeforeAll {
    . (Join-Path $PSScriptRoot '..\helpers\TestHelpers.ps1')
    $inventory = Get-CommandInventory | Where-Object { $_.TestType -eq 'external-skip' }
}

Describe 'external dependency coverage' {
    foreach ($entry in $inventory) {
        It "$($entry.Name) is explicitly classified with a skip reason" {
            $entry.SkipReason | Should -Not -BeNullOrEmpty
        }
    }
}
