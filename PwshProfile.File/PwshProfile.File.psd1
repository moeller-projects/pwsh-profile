@{
    GUID              = '2274f2bd-9fd2-4201-8fa2-e70d50362c0e'
    Author            = 'moeller-projects'
    CompanyName       = 'moeller-projects'
    Description       = 'File system helpers for pwsh-profile'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RootModule = 'PwshProfile.File.psm1'
    ModuleVersion = '1.1.0'
    FunctionsToExport = @('ConvertTo-HumanReadableSize', 'Get-FileSize', 'Publish-FileShare', 'Watch-File', 'New-EmptyFile', 'Find-File', 'Expand-ZipFile', 'Get-FileHead', 'Get-FileTail', 'Enter-NewDirectory', 'Remove-ToRecycleBin', 'Set-ClipboardText', 'Get-ClipboardText', 'Publish-Hastebin', 'Find-Text', 'Get-VolumeUsage', 'Update-FileText', 'Set-LocationParent', 'Set-LocationParentTwoLevels', 'Set-LocationHome', 'Invoke-Eza', 'Invoke-EzaLs')
    AliasesToExport = @('sf', 'wf', 'touch', 'nf', 'ff', 'unzip', 'head', 'tail', 'mkcd', 'trash', 'cpy', 'pst', 'hb', 'grep', 'df', 'sed', '..', '...', '~', 'lss')
}
