BeforeAll {
    . (Join-Path $PSScriptRoot '..\helpers\TestHelpers.ps1')
    $repoRoot = Get-RepoRoot
    . (Join-Path $repoRoot 'setup.ps1')
}

Describe 'setup script helpers' {
    It 'builds the expected source profile path' {
        $path = Get-SetupSourceProfilePath -RootPath '/tmp/repo'
        $path | Should -Be '/tmp/repo/profile.ps1'
    }

    It 'supports WhatIf for setup orchestration' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('pwsh-profile-setup-' + [guid]::NewGuid())
        $sourceRoot = Join-Path $tempRoot 'repo'
        $targetProfile = Join-Path $tempRoot 'target' 'Microsoft.PowerShell_profile.ps1'
        try {
            New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
            'test' | Set-Content -LiteralPath (Join-Path $sourceRoot 'profile.ps1')

            { Invoke-ProfileSetup -ResolvedRepositoryRoot $sourceRoot -ResolvedProfilePath $targetProfile -WhatIf } | Should -Not -Throw
            Test-Path -LiteralPath $targetProfile | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not force confirm settings onto nested setup helpers' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('pwsh-profile-setup-' + [guid]::NewGuid())
        $sourceRoot = Join-Path $tempRoot 'repo'
        $targetProfile = Join-Path $tempRoot 'target' 'Microsoft.PowerShell_profile.ps1'
        $script:setupHelperCalls = @()
        try {
            New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
            'test' | Set-Content -LiteralPath (Join-Path $sourceRoot 'profile.ps1')

            Mock Ensure-SetupDirectory {
                $script:setupHelperCalls += [pscustomobject]@{
                    Command    = 'Ensure-SetupDirectory'
                    Parameters = @{} + $PSBoundParameters
                }
            }
            Mock Remove-SetupExistingProfile {
                $script:setupHelperCalls += [pscustomobject]@{
                    Command    = 'Remove-SetupExistingProfile'
                    Parameters = @{} + $PSBoundParameters
                }
            }
            Mock New-SetupProfileSymbolicLink {
                $script:setupHelperCalls += [pscustomobject]@{
                    Command    = 'New-SetupProfileSymbolicLink'
                    Parameters = @{} + $PSBoundParameters
                }
            }

            Invoke-ProfileSetup -ResolvedRepositoryRoot $sourceRoot -ResolvedProfilePath $targetProfile -WhatIf

            foreach ($call in $script:setupHelperCalls) {
                $call.Parameters.ContainsKey('Confirm') | Should -BeFalse
                $call.Parameters.ContainsKey('WhatIf') | Should -BeFalse
            }
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Variable -Name setupHelperCalls -Scope Script -ErrorAction SilentlyContinue
        }
    }
}
