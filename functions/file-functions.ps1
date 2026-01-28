function ConvertTo-HumanReadableSize {
    param([long]$Bytes)

    $units = @('Bytes', 'KB', 'MB', 'GB', 'TB', 'PB')
    $unitValues = 1, 1KB, 1MB, 1GB, 1TB, 1PB

    for ($i = $units.Length - 1; $i -ge 0; $i--) {
        if ($Bytes -ge $unitValues[$i]) {
            $size = [math]::Round($Bytes / $unitValues[$i], 2)
            return "$size $($units[$i])"
        }
    }

    return "$Bytes Bytes"
}

function Get-FileSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Warning "File not found: $Path"
        return $null
    }
    $sizeInBytes = (Get-Item -LiteralPath $Path).Length

    ConvertTo-HumanReadableSize -Bytes $sizeInBytes
}

function Publish-FileShare {
    [CmdletBinding()]
    [Alias('sf')]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    $baseApiUrl = "https://share.hidrive.com/api"

    Write-Verbose "Obtaining HiDrive credentials..."
    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $credentialsResponse = Invoke-WebRequest -Method POST -Uri "$baseApiUrl/new" -TimeoutSec 15 -ErrorAction Stop
        }
        else {
            $credentialsResponse = Invoke-WebRequest -Method POST -Uri "$baseApiUrl/new" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        }
        $credentials = $credentialsResponse.Content | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to obtain credentials: $_"
        return
    }

    foreach ($Path in $Paths) {
        if (-not ([System.IO.File]::Exists($Path))) {
            # Use .NET for file existence check
            Write-Error "The specified path '$Path' does not exist."
            continue
        }

        try {
            $fileInfo = [System.IO.FileInfo]$Path # Use .NET FileInfo for properties
            # $file = Get-Item -Path $Path # Original was fine too

            Write-Verbose "Uploading $($fileInfo.Name)..."
            $uploadUri = "$baseApiUrl/$($credentials.id)/patch?dst=$($fileInfo.Name)&offset=0"
            # Form data creation might be optimized slightly, but Invoke-WebRequest handles it well
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $uploadResponse = Invoke-WebRequest -Method POST -Uri $uploadUri -Form @{file = $fileInfo } -ContentType "multipart/form-data" -Headers @{"x-auth-token" = $credentials.token } -TimeoutSec 60 -ErrorAction Stop
            }
            else {
                $uploadResponse = Invoke-WebRequest -Method POST -Uri $uploadUri -Form @{file = $fileInfo } -ContentType "multipart/form-data" -Headers @{"x-auth-token" = $credentials.token } -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            }
            $sizeLabel = ConvertTo-HumanReadableSize -Bytes $fileInfo.Length
            Write-Information "[DONE] $($fileInfo.Name) - $sizeLabel"
        }
        catch {
            Write-Error "An error occurred while processing '$Path': $($_.Exception.Message)"
        }
    }

    Write-Verbose "Finalizing upload..."
    $finalizeUri = "$baseApiUrl/$($credentials.id)/finalize"
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $finalizeResponse = Invoke-WebRequest -Method POST -Uri $finalizeUri -Headers @{"x-auth-token" = $credentials.token } -TimeoutSec 30 -ErrorAction Stop
    }
    else {
        $finalizeResponse = Invoke-WebRequest -Method POST -Uri $finalizeUri -Headers @{"x-auth-token" = $credentials.token } -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    }

    $share = "https://get.hidrive.com/$($credentials.id)"

    $clipboardCmd = Get-Command Set-Clipboard -ErrorAction SilentlyContinue
    if ($clipboardCmd) {
        $share | Set-Clipboard
        Write-Host "Share link copied to clipboard: $share" -ForegroundColor Green
    }
    else {
        Write-Verbose "Set-Clipboard is not available in this session; skipping copy to clipboard."
        Write-Host "Share link: $share" -ForegroundColor Green
    }

    Write-Output $share
}

function Watch-File {
    [CmdletBinding()]
    [Alias('wf')]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Warning "File not found: $Path"
        return
    }
    Get-Content -LiteralPath $Path -Wait -Tail 1
}

function New-EmptyFile {
    [CmdletBinding()]
    [Alias('touch', 'nf')]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path)
    $full = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $PWD.Path $Path }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        New-Item -ItemType File -Path $full -Force | Out-Null
        Write-Verbose "Created empty file: $full"
    }
    else {
        [System.IO.File]::SetLastWriteTimeUtc($full, [DateTime]::UtcNow)
        Write-Verbose "Updated timestamp for: $full"
    }
}

function Find-File {
    [CmdletBinding()]
    [Alias('ff')]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name,
        [switch]$Recurse = $true,
        [int]$MaxDepth = -1
    )

    $root = (Resolve-Path $PWD.Path).Path
    $pattern = "*$Name*"
    $depthLimit = if ($MaxDepth -ge 0) { $MaxDepth } else { [int]::MaxValue }
    Write-Verbose "Searching for files matching '$pattern' in '$root' (Recurse: $($Recurse.IsPresent), MaxDepth: $MaxDepth)..."

    try {
        if (-not $Recurse) {
            foreach ($file in [System.IO.Directory]::EnumerateFiles($root, $pattern, [System.IO.SearchOption]::TopDirectoryOnly)) {
                $file
            }
        }
        else {
            $stack = New-Object System.Collections.Stack
            $stack.Push([pscustomobject]@{ Path = $root; Depth = 0 })

            while ($stack.Count -gt 0) {
                $current = $stack.Pop()
                $currentPath = $current.Path
                $currentDepth = $current.Depth

                try {
                    foreach ($file in [System.IO.Directory]::EnumerateFiles($currentPath, $pattern, [System.IO.SearchOption]::TopDirectoryOnly)) {
                        $file
                    }
                }
                catch [System.UnauthorizedAccessException] {
                    Write-Verbose "Skipping inaccessible files under '$currentPath'."
                }

                if ($currentDepth -ge $depthLimit) { continue }

                try {
                    foreach ($dir in [System.IO.Directory]::EnumerateDirectories($currentPath, '*', [System.IO.SearchOption]::TopDirectoryOnly)) {
                        $stack.Push([pscustomobject]@{ Path = $dir; Depth = $currentDepth + 1 })
                    }
                }
                catch [System.UnauthorizedAccessException] {
                    Write-Verbose "Skipping inaccessible directory '$currentPath'."
                }
            }
        }
    }
    catch {
        Write-Error "Failed to search for files: $($_.Exception.Message)"
    }

    Write-Verbose "File search completed."
}

function Expand-ZipFile {
    [CmdletBinding()]
    [Alias('unzip')]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][Alias('File')][string]$Name)
    Write-Information "Extracting $Name to $pwd"
    $fullFile = Get-ChildItem -Path $pwd -Filter $Name | Select-Object -ExpandProperty FullName
    if (-not $fullFile) {
        Write-Error "Archive file '$Name' not found in current directory."
        return
    }
    Expand-Archive -LiteralPath $fullFile -DestinationPath $pwd -Force
    Write-Host "Extraction of $Name completed." -ForegroundColor Green
}

function Get-FileHead {
    [CmdletBinding()]
    [Alias('head')]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter()][ValidateRange(1, 1000000)][Alias('n')][int]$LineCount = 10
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Write-Warning "File not found: $Path"; return }
    Get-Content -LiteralPath $Path -Head $LineCount
}

function Get-FileTail {
    [CmdletBinding()]
    [Alias('tail')]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter()][ValidateRange(1, 1000000)][Alias('n')][int]$LineCount = 10,
        [Parameter()][Alias('f')][switch]$Follow
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Write-Warning "File not found: $Path"; return }
    Get-Content -Path $Path -Tail $LineCount -Wait:$Follow
}

function Enter-NewDirectory {
    [CmdletBinding()]
    [Alias('mkcd')]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name)
    $full = if ([System.IO.Path]::IsPathRooted($Name)) { $Name } else { Join-Path $PWD.Path $Name }
    if (-not (Test-Path -LiteralPath $full)) {
        New-Item -ItemType Directory -Path $full -Force | Out-Null
        Write-Verbose "Created directory: $full"
    }
    Set-Location -LiteralPath $full
    Write-Host "Changed directory to: $full" -ForegroundColor Green
}

function Remove-ToRecycleBin {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [Alias('trash')]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path)

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item) {
        Write-Host "Error: Item '$Path' does not exist." -ForegroundColor Red
        return
    }

    $fullPath = $item.FullName
    $isWindowsCompat = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')
    if (-not $isWindowsCompat) {
        Write-Error "Remove-ToRecycleBin requires Windows Shell support."
        return
    }

    if ($PSCmdlet.ShouldProcess($fullPath, 'move to Recycle Bin')) {
        Write-Verbose "Moving '$fullPath' to Recycle Bin..."
        $parentPath = if ($item.PSIsContainer) { $item.Parent.FullName } else { $item.DirectoryName }
        $shell = New-Object -ComObject 'Shell.Application'
        $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)
        if ($shellItem) {
            $shellItem.InvokeVerb('delete')
            Write-Host "Item '$fullPath' has been moved to the Recycle Bin." -ForegroundColor Green
        }
        else {
            Write-Host "Error: Could not find the item '$fullPath' to trash." -ForegroundColor Red
        }
    }
}

function Set-ClipboardText {
    [CmdletBinding()]
    [Alias('cpy')]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Text)
    Set-Clipboard -Value $Text
}

function Get-ClipboardText {
    [CmdletBinding()]
    [Alias('pst')]
    param()
    Get-Clipboard
}

function Publish-Hastebin {
    [CmdletBinding()]
    [Alias('hb')]
    param()
    if ($args.Length -eq 0) {
        Write-Error "No file path specified."
        return
    }
    $FilePath = $args[0]
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        Write-Error "File path does not exist: $FilePath."
        return
    }
    $Content = Get-Content -LiteralPath $FilePath -Raw
    $uri = "https://hastebin.de/documents"
    try {
        Write-Verbose "Uploading '$FilePath' to Hastebin..."
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop -TimeoutSec 30
        }
        else {
            $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop -UseBasicParsing -TimeoutSec 30
        }
        $hasteKey = $response.key
        $url = "https://hastebin.de/$hasteKey"
        Set-Clipboard $url
        Write-Output $url
        Write-Host "Hastebin link copied to clipboard: $url" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to upload the document. Error: $($_.Exception.Message)"
    }
}

function Find-Text {
    [CmdletBinding()]
    [Alias('grep')]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][Alias('Regex')][string]$Pattern,
        [Alias('Dir')][string[]]$Path,
        [switch]$Recurse,
        [string[]]$Include,
        [string[]]$Exclude
    )

    if ($Path) {
        foreach ($target in $Path) {
            if (-not (Test-Path -LiteralPath $target)) {
                Write-Warning "Directory not found: $target"
                continue
            }

            $gciParams = @{
                LiteralPath = $target
                File        = $true
                ErrorAction = 'SilentlyContinue'
            }
            if ($Recurse) { $gciParams.Recurse = $true }
            if ($Include) { $gciParams.Include = $Include }
            if ($Exclude) { $gciParams.Exclude = $Exclude }

            Get-ChildItem @gciParams | Select-String -Pattern $Pattern
        }
    }
    else {
        $input | Select-String -Pattern $Pattern
    }
}

function Get-VolumeUsage {
    [CmdletBinding()]
    [Alias('df')]
    param()
    Get-Volume
}

function Update-FileText {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [Alias('sed')]
    param(
        [Parameter(Mandatory)][Alias('File')][string]$Path,
        [Parameter(Mandatory)][Alias('find')][string]$Find,
        [Parameter(Mandatory)][Alias('replace')][string]$Replace,
        [System.Text.Encoding]$Encoding,
        [switch]$Regex
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Write-Warning "File not found: $Path"; return }

    if (-not $PSBoundParameters.ContainsKey('Encoding')) {
        $Encoding = [System.Text.UTF8Encoding]::new($false)
    }

    if ($PSCmdlet.ShouldProcess($Path, 'replace text')) {
        $originalContent = [System.IO.File]::ReadAllText($Path, $Encoding)
        $newlineMatch = [regex]::Match($originalContent, '(\r?\n)$')
        $terminalNewline = if ($newlineMatch.Success) { $newlineMatch.Groups[1].Value } else { $null }

        if ($Regex) {
            $updatedContent = [regex]::Replace($originalContent, $Find, $Replace)
        }
        else {
            $updatedContent = $originalContent.Replace($Find, $Replace)
        }

        if ($terminalNewline -and -not $updatedContent.EndsWith($terminalNewline)) {
            $updatedContent += $terminalNewline
        }

        [System.IO.File]::WriteAllText($Path, $updatedContent, $Encoding)
        Write-Verbose "Performed sed operation on '$Path'."
    }
}

function Set-LocationParent {
    [CmdletBinding()]
    [Alias('..')]
    param()
    Set-Location ..
}

function Set-LocationParentTwoLevels {
    [CmdletBinding()]
    [Alias('...')]
    param()
    Set-Location ../..
}

function Set-LocationHome {
    [CmdletBinding()]
    [Alias('~')]
    param()
    Set-Location ~
}

function Invoke-Eza {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )
    eza --icons=always @Args
}

function Invoke-EzaLs {
    [CmdletBinding()]
    [Alias('lss')]
    param (
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )
    Invoke-Eza -Args '-lh --git --icons --group-directories-first'
}
