BeforeAll {
    . (Join-Path $PSScriptRoot '..\helpers\TestHelpers.ps1')
    $repoRoot = Get-RepoRoot
    $inventory = Get-CommandInventory
    Import-PwshProfileModuleForTest
}

Describe 'PwshProfile module' {
    It 'imports the module manifest successfully' {
        $module = Get-Module PwshProfile
        $module | Should -Not -BeNullOrEmpty
        $module.Version.ToString() | Should -Be '0.2.0'
    }

    It 'exports the expected public functions' {
        $expected = $inventory |
            Where-Object { $_.Kind -eq 'function' -and $_.Exported } |
            ForEach-Object Name |
            Sort-Object -Unique

        $actual = Get-Command -Module PwshProfile -CommandType Function | Select-Object -ExpandProperty Name | Sort-Object -Unique
        $actual | Should -Be $expected
    }

    It 'exports the expected public aliases' {
        $actual = Get-Command -Module PwshProfile -CommandType Alias | Select-Object -ExpandProperty Name | Sort-Object -Unique
        $actual | Should -Contain 'gclean'
        $actual | Should -Contain 'touch'
        $actual | Should -Contain 'kubectx'
    }
}
