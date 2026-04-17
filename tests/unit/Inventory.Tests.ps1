BeforeAll {
    . (Join-Path $PSScriptRoot '..\helpers\TestHelpers.ps1')
    $inventory = Get-CommandInventory
}

Describe 'command inventory coverage' {
    It 'covers every tracked function definition' {
        $actual = Get-RepositoryFunctionDefinitions | Sort-Object Source, Name
        $expected = $inventory | Where-Object Kind -eq 'function' | ForEach-Object {
            '{0}|{1}' -f $_.Source, $_.Name
        } | Sort-Object

        $actualKeys = $actual | ForEach-Object { '{0}|{1}' -f $_.Source, $_.Name } | Sort-Object
        $actualKeys | Should -Be $expected
    }

    It 'covers every tracked top-level script' {
        $actual = Get-RepositoryScripts | Sort-Object Source
        $expected = $inventory | Where-Object Kind -eq 'script' | ForEach-Object Source | Sort-Object
        ($actual | ForEach-Object Source) | Should -Be $expected
    }

    It 'provides required metadata for every inventory entry' {
        foreach ($entry in $inventory) {
            $entry.Name | Should -Not -BeNullOrEmpty
            $entry.Source | Should -Not -BeNullOrEmpty
            $entry.Category | Should -Not -BeNullOrEmpty
            $entry.Platform | Should -Not -BeNullOrEmpty
            $entry.TestType | Should -Not -BeNullOrEmpty
            $entry.PSObject.Properties.Name | Should -Contain 'dependencies'

            if ($entry.TestType -like '*skip*') {
                $entry.SkipReason | Should -Not -BeNullOrEmpty
            }
        }
    }
}
