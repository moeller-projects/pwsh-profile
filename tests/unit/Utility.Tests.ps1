BeforeAll {
    . (Join-Path $PSScriptRoot '..\helpers\TestHelpers.ps1')
    Import-PwshProfileModuleForTest
    $repoRoot = Get-RepoRoot
}

Describe 'deterministic utility commands' {
    It 'converts byte counts to human-readable sizes' {
        ConvertTo-HumanReadableSize -Bytes 1536 | Should -Be '1.5 KB'
    }

    It 'parses dotenv lines' {
        $entry = ConvertFrom-DotEnvLine -Line 'FOO = bar'
        $entry.Name | Should -Be 'FOO'
        $entry.Value | Should -Be 'bar'
    }

    It 'ignores comments in dotenv parsing' {
        ConvertFrom-DotEnvLine -Line '# comment' | Should -BeNullOrEmpty
    }

    It 'does not modify files when Update-FileText runs with WhatIf' {
        $path = Join-Path ([System.IO.Path]::GetTempPath()) ('pwsh-profile-' + [guid]::NewGuid() + '.txt')
        try {
            'alpha' | Set-Content -LiteralPath $path
            Update-FileText -Path $path -Find 'alpha' -Replace 'beta' -WhatIf
            (Get-Content -LiteralPath $path -Raw).Trim() | Should -Be 'alpha'
        }
        finally {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }

    It 'supports WhatIf for Remove-ToRecycleBin on all platforms' {
        $path = Join-Path ([System.IO.Path]::GetTempPath()) ('pwsh-profile-' + [guid]::NewGuid() + '.txt')
        try {
            New-Item -ItemType File -Path $path -Force | Out-Null
            { Remove-ToRecycleBin -Path $path -WhatIf } | Should -Not -Throw
        }
        finally {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns strongly-typed Azure menu items' {
        $item = New-MenuItem -Name 'demo' -Value '123'
        $item.Name | Should -Be 'demo'
        $item.Value | Should -Be '123'
    }

    It 'derives the expected project config path' {
        $path = Get-ProjectConfigPath
        if ($IsWindows) {
            $path | Should -Match 'pwsh-profile[\\/]+config\.json$'
        }
        else {
            $path | Should -Match '\.config[\\/]+pwsh-profile[\\/]+config\.json$'
        }
    }
}
