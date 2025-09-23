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

    $units = @("Bytes", "KB", "MB", "GB", "TB")
    $unitValues = 1, 1KB, 1MB, 1GB, 1TB

    for ($i = $units.Length - 1; $i -ge 0; $i--) {
        if ($sizeInBytes -ge $unitValues[$i]) {
            $size = [math]::round($sizeInBytes / $unitValues[$i], 2)
            Write-Output "$size $($units[$i])"
            return
        }
    }
    # Fallback for very small files
    Write-Output "$sizeInBytes Bytes"
}

function Share-File {
    [CmdletBinding()]
    [Alias("sf")]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    $baseApiUrl = "https://share.hidrive.com/api"

    Write-Verbose "Obtaining HiDrive credentials..."
    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $credentialsResponse = Invoke-WebRequest -Method POST -Uri "$baseApiUrl/new" -TimeoutSec 15 -ErrorAction Stop
        } else {
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
            } else {
                $uploadResponse = Invoke-WebRequest -Method POST -Uri $uploadUri -Form @{file = $fileInfo } -ContentType "multipart/form-data" -Headers @{"x-auth-token" = $credentials.token } -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            }
            Write-Information "[DONE] $($fileInfo.Name) - $(Get-FileSize -Path $Path)"
        }
        catch {
            Write-Error "An error occurred while processing '$Path': $($_.Exception.Message)"
        }
    }

    Write-Verbose "Finalizing upload..."
    $finalizeUri = "$baseApiUrl/$($credentials.id)/finalize"
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $finalizeResponse = Invoke-WebRequest -Method POST -Uri $finalizeUri -Headers @{"x-auth-token" = $credentials.token } -TimeoutSec 30 -ErrorAction Stop
    } else {
        $finalizeResponse = Invoke-WebRequest -Method POST -Uri $finalizeUri -Headers @{"x-auth-token" = $credentials.token } -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    }

    $share = "https://get.hidrive.com/$($credentials.id)"

    $share | Set-Clipboard # Set-Clipboard is a cmdlet, generally fast.
    Write-Output $share
    Write-Host "Share link copied to clipboard: $share" -ForegroundColor Green
}

function Watch-File {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Warning "File not found: $Path"
        return
    }
    Get-Content -LiteralPath $Path -Wait -Tail 1
}
function wf { Watch-File -Path $args[0] }

function touch {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$File)
    $full = Join-Path $PWD.Path $File
    Set-Content -LiteralPath $full -Value '' -NoNewline -Force
    Write-Verbose "Created empty file: $full"
}

function Find-File {
    [CmdletBinding()]
    [Alias('ff')]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name)
    Write-Verbose "Searching for files matching '*$name*' in '$($PWD.Path)' and subdirectories..."
    [System.IO.Directory]::EnumerateFiles($PWD.Path, "*$Name*", [System.IO.SearchOption]::AllDirectories)
    Write-Verbose "File search completed."
}

function unzip {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$File)
    Write-Information "Extracting $File to $pwd"
    # Get-ChildItem is fine for locating the specific file.
    $fullFile = Get-ChildItem -Path $pwd -Filter $File | Select-Object -ExpandProperty FullName
    if (-not $fullFile) {
        Write-Error "Archive file '$File' not found in current directory."
        return
    }
    Expand-Archive -LiteralPath $fullFile -DestinationPath $pwd -Force
    Write-Host "Extraction of $File completed." -ForegroundColor Green
}

function head {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter()][ValidateRange(1, 1000000)][int]$n = 10
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Write-Warning "File not found: $Path"; return }
    Get-Content -LiteralPath $Path -Head $n
}
function tail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter()][ValidateRange(1, 1000000)][int]$n = 10,
        [Parameter()][switch]$f = $false
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Write-Warning "File not found: $Path"; return }
    Get-Content -LiteralPath $Path -Tail $n -Wait:$f
}

function nf {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name)
    $full = Join-Path $PWD.Path $Name
    Set-Content -LiteralPath $full -Value '' -NoNewline -Force
    Write-Verbose "Created new file: $full"
}

function mkcd {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Dir)
    $full = Join-Path $PWD.Path $Dir
    if (-not (Test-Path -LiteralPath $full)) {
        New-Item -ItemType Directory -Path $full -Force | Out-Null
        Write-Verbose "Created directory: $full"
    }
    Set-Location -LiteralPath $full
    Write-Host "Changed directory to: $Dir" -ForegroundColor Green
}

function trash {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param($path)
    $item = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
    if (-not $item) {
        Write-Host "Error: Item '$path' does not exist." -ForegroundColor Red
        return
    }
    $fullPath = $item.FullName
    $isWindowsCompat = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -like '*Windows*')
    if (-not $isWindowsCompat) { Write-Error "'trash' uses Windows Shell Recycle Bin and requires Windows."; return }
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

function la { [CmdletBinding()] param() Get-ChildItem | Format-Table -AutoSize }
function ll {
    [CmdletBinding()]
    param()
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Get-ChildItem -Force -Recurse -Depth 1 | Format-Table -AutoSize
    } else {
        Get-ChildItem -Force -Recurse | Where-Object { $_.PSIsContainer -or $_.PSChildName } | Select-Object -First 200 | Format-Table -AutoSize
    }
}

function cpy { [CmdletBinding()] param([Parameter(Mandatory)][string]$Text) Set-Clipboard $Text }
function pst { [CmdletBinding()] param() Get-Clipboard }

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
        } else {
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

function grep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Regex,
        [string]$Dir
    )
    if ($Dir) {
        # Get-ChildItem with Select-String is efficient for this.
        if (-not (Test-Path -LiteralPath $Dir)) { Write-Warning "Directory not found: $Dir"; return }
        Get-ChildItem -LiteralPath $Dir | Select-String $Regex
    }
    else {
        $input | Select-String $Regex
    }
}

function df { get-volume } # Get-Volume is a cmdlet, efficient.

function sed {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)] [string]$file,
        [Parameter(Mandatory)] [string]$find,
        [Parameter(Mandatory)] [string]$replace
    )
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { Write-Warning "File not found: $file"; return }
    if ($PSCmdlet.ShouldProcess($file, 'replace text')) {
        $content = Get-Content -LiteralPath $file -Raw
        $content = $content.Replace($find, $replace)
        Set-Content -LiteralPath $file -Value $content -NoNewline
        Write-Verbose "Performed sed operation on '$file'."
    }
}

function goParent { [CmdletBinding()] param() Set-Location .. }
function goToParent2Levels { [CmdletBinding()] param() Set-Location ../.. }
function goToHome { [CmdletBinding()] param() Set-Location ~ }

# Aliases: These are assumed to be moved to the main profile script as part of deferred loading.
# Set-Alias -Name c -Value Clear-Host
# Set-Alias -Name ls -Value Get-ChildItem
# Set-Alias -Name .. -Value goToParent
# Set-Alias -Name ... -Value goToParent2Levels
# Set-Alias -Name ~ -Value goToHome
