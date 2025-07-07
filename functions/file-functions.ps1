function Get-FileSize {
    param(
        [string]$Path
    )

    # Using .NET for file check and length property
    if (-not ([System.IO.File]::Exists($Path))) {
        Write-Warning "File not found: $Path"
        return $null
    }
    $sizeInBytes = (Get-Item -LiteralPath $Path).Length # Get-Item is fine for specific path
    # $sizeInBytes = (New-Object System.IO.FileInfo($Path)).Length # Alternative using .NET directly

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
    [Info("Upload one or more Files to share it using HiDrive", "Share")]
    [CmdletBinding()]
    [Alias("sf")]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    $baseApiUrl = "https://share.hidrive.com/api"

    Write-Verbose "Obtaining HiDrive credentials..."
    try {
        $credentialsResponse = Invoke-WebRequest -Method POST -Uri "$baseApiUrl/new" -UseBasicParsing # UseBasicParsing for speed
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
            $uploadResponse = Invoke-WebRequest -Method POST -Uri $uploadUri -Form @{file = $fileInfo } -ContentType "multipart/form-data" -Headers @{"x-auth-token" = $credentials.token } -UseBasicParsing
            Write-Information "[DONE] $($fileInfo.Name) - $(Get-FileSize -Path $Path)"
        }
        catch {
            Write-Error "An error occurred while processing '$Path': $($_.Exception.Message)"
        }
    }

    Write-Verbose "Finalizing upload..."
    $finalizeUri = "$baseApiUrl/$($credentials.id)/finalize"
    $finalizeResponse = Invoke-WebRequest -Method POST -Uri $finalizeUri -Headers @{"x-auth-token" = $credentials.token } -UseBasicParsing

    $share = "https://get.hidrive.com/$($credentials.id)"

    $share | Set-Clipboard # Set-Clipboard is a cmdlet, generally fast.
    Write-Output $share
    Write-Host "Share link copied to clipboard: $share" -ForegroundColor Green
}

function Watch-File {
    param (
        [string]$Path
    )
    if (-not ([System.IO.File]::Exists($Path))) {
        Write-Warning "File not found: $Path"
        return
    }
    # Get-Content -Wait -Tail 1 is efficient for this purpose.
    Get-Content -LiteralPath $Path -Wait -Tail 1
}
function wf { Watch-File -Path $args[0] }

function touch($file) {
    # Using .NET directly for creating empty file is faster than Out-File
    [System.IO.File]::WriteAllText($file, "")
    Write-Verbose "Created empty file: $file"
}

function ff($name) {
    Write-Verbose "Searching for files matching '*$name*' in '$pwd' and subdirectories..."
    # Using .NET EnumerateFiles for highly efficient recursive file listing
    [System.IO.Directory]::EnumerateFiles($pwd, "*$name*", [System.IO.SearchOption]::AllDirectories) | ForEach-Object {
        Write-Output $_
    }
    Write-Verbose "File search completed."
}

function unzip($file) {
    Write-Information "Extracting $file to $pwd"
    # Get-ChildItem is fine for locating the specific file.
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | Select-Object -ExpandProperty FullName
    if (-not $fullFile) {
        Write-Error "Archive file '$file' not found in current directory."
        return
    }
    # Expand-Archive is a cmdlet, efficient for unzipping.
    Expand-Archive -LiteralPath $fullFile -DestinationPath $pwd
    Write-Host "Extraction of $file completed." -ForegroundColor Green
}

function head {
    param($Path, $n = 10)
    if (-not ([System.IO.File]::Exists($Path))) { Write-Warning "File not found: $Path"; return }
    Get-Content -LiteralPath $Path -Head $n
}
function tail {
    param($Path, $n = 10, [switch]$f = $false)
    if (-not ([System.IO.File]::Exists($Path))) { Write-Warning "File not found: $Path"; return }
    Get-Content -LiteralPath $Path -Tail $n -Wait:$f
}

function nf {
    param($name)
    # Using .NET directly for new empty file
    [System.IO.File]::WriteAllText((Join-Path $pwd $name), "")
    Write-Verbose "Created new file: $name"
}

function mkcd {
    param($dir)
    # Using .NET for directory creation and checking
    if (-not ([System.IO.Directory]::Exists($dir))) {
        [System.IO.Directory]::CreateDirectory($dir)
        Write-Verbose "Created directory: $dir"
    }
    Set-Location $dir
    Write-Host "Changed directory to: $dir" -ForegroundColor Green
}

function trash {
    [CmdletBinding()]
    param($path)
    # Resolve-Path is a cmdlet but typically fast.
    $fullPath = (Resolve-Path -Path $path -ErrorAction SilentlyContinue).Path
    if (-not ($fullPath) -or -not ([System.IO.FileSystemInfo]::Exists($fullPath))) {
        # Use .NET for check
        Write-Host "Error: Item '$path' (resolved to '$fullPath') does not exist." -ForegroundColor Red
        return
    }
    # This uses a COM object, specific to Windows, no .NET equivalent for Recycle Bin.
    # Performance is generally acceptable.
    Write-Verbose "Moving '$fullPath' to Recycle Bin..."
    $item = Get-Item -LiteralPath $fullPath
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

function la { Get-ChildItem | Format-Table -AutoSize }
function ll { Get-ChildItem -Force -Recurse -Depth 1 | Format-Table -AutoSize }

function cpy { Set-Clipboard $args[0] }
function pst { Get-Clipboard }

function hb {
    [CmdletBinding()]
    param()
    if ($args.Length -eq 0) {
        Write-Error "No file path specified."
        return
    }
    $FilePath = $args[0]
    if (-not ([System.IO.File]::Exists($FilePath))) {
        # Use .NET for file existence check
        Write-Error "File path does not exist: $FilePath."
        return
    }
    $Content = [System.IO.File]::ReadAllText($FilePath) # Use .NET for faster file read
    $uri = "https://hastebin.de/documents"
    try {
        Write-Verbose "Uploading '$FilePath' to Hastebin..."
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop -UseBasicParsing # UseBasicParsing for speed
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

function grep($regex, $dir) {
    if ($dir) {
        # Get-ChildItem with Select-String is efficient for this.
        if (-not ([System.IO.Directory]::Exists($dir))) { Write-Warning "Directory not found: $dir"; return }
        Get-ChildItem -LiteralPath $dir | Select-String $regex
    }
    else {
        $input | Select-String $regex
    }
}

function df { get-volume } # Get-Volume is a cmdlet, efficient.

function sed($file, $find, $replace) {
    if (-not ([System.IO.File]::Exists($file))) { Write-Warning "File not found: $file"; return }
    $content = [System.IO.File]::ReadAllText($file)
    $content = $content.Replace($find, $replace)
    [System.IO.File]::WriteAllText($file, $content)
    Write-Verbose "Performed sed operation on '$file'."
}

function goParent() { Set-Location .. }
function goToParent2Levels() { Set-Location ../.. }
function goToHome() { Set-Location ~ }

# Aliases: These are assumed to be moved to the main profile script as part of deferred loading.
# Set-Alias -Name c -Value Clear-Host
# Set-Alias -Name ls -Value Get-ChildItem
# Set-Alias -Name .. -Value goToParent
# Set-Alias -Name ... -Value goToParent2Levels
# Set-Alias -Name ~ -Value goToHome
