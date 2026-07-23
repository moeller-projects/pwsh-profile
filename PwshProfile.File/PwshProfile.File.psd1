@{
    RootModule = 'PwshProfile.File.psm1'
    ModuleVersion = '1.0.0'
    FunctionsToExport = @('ConvertTo-HumanReadableSize', 'Get-FileSize', 'Publish-FileShare', 'Watch-File', 'New-EmptyFile', 'Find-File', 'Expand-ZipFile', 'Get-FileHead', 'Get-FileTail', 'Enter-NewDirectory', 'Remove-ToRecycleBin', 'Set-ClipboardText', 'Get-ClipboardText', 'Publish-Hastebin', 'Find-Text', 'Get-VolumeUsage', 'Update-FileText', 'Set-LocationParent', 'Set-LocationParentTwoLevels', 'Set-LocationHome', 'Invoke-Eza', 'Invoke-EzaLs')
    AliasesToExport = @('sf', 'wf', 'touch', 'nf', 'ff', 'unzip', 'head', 'tail', 'mkcd', 'trash', 'cpy', 'pst', 'hb', 'grep', 'df', 'sed', '..', '...', '~', 'lss')
}
