class MenuOption {
    [String]$Name
    [String]$Value

    [String]ToString() {
        return "$($this.Name) ($($this.Value))"
    }
}

function New-MenuItem([String]$Name, [String]$Value) {
    $MenuItem = [MenuOption]::new()
    $MenuItem.Name = $Name
    $MenuItem.Value = $Value
    return $MenuItem
}

function Switch-AzureSubscription {
    [CmdletBinding()]
    [Alias("sas")]
    param ()

    if (-not (Get-Command az -ErrorAction SilentlyContinue)) { Write-Error "Azure CLI 'az' not found in PATH."; return }

    Write-Verbose "Fetching Azure subscriptions..."
    # External call to az CLI - inherent overhead
    $AZ_SUBSCRIPTIONS = az account list --output json | ConvertFrom-Json
    if ($AZ_SUBSCRIPTIONS.Count -eq 0) {
        Write-Error "No Azure Subscriptions found."
        return
    }

    $Options = $AZ_SUBSCRIPTIONS | ForEach-Object { New-MenuItem -Name $_.name -Value $_.id }

    # Assuming Show-Menu is provided by PSMenu/InteractiveMenu
    $selectedAZSub = Show-Menu -MenuItems $Options
    if ($null -eq $selectedAZSub) {
        Write-Warning "No subscription selected."
        return
    }

    Write-Verbose "Setting Azure subscription to $($selectedAZSub.Name) ($($selectedAZSub.Value))..."
    & az account set -s $selectedAZSub.Value
    Write-Host "Azure subscription set to $($selectedAZSub.Name)" -ForegroundColor Green
}

function Connect-ContainerRegistry {
    [CmdletBinding()]
    [Alias("lacr")]
    param ()

    if (-not (Get-Command az -ErrorAction SilentlyContinue)) { Write-Error "Azure CLI 'az' not found in PATH."; return }

    Write-Verbose "Retrieving Azure Container Registries..."
    # External call to az CLI - inherent overhead
    $ACRs = az acr list --output json | ConvertFrom-Json

    if ($ACRs.Count -eq 0) {
        Write-Error "No Azure Container Registries found."
        return
    }

    $Options = $ACRs | ForEach-Object { New-MenuItem -Name $_.loginServer -Value $_.name }

    $selectedACR = Show-Menu -MenuItems $Options
    if ($null -eq $selectedACR) {
        Write-Warning "No ACR selected."
        return
    }

    Write-Verbose "Logging into ACR via az for $($selectedACR.Value)..."
    # Simpler and avoids handling credentials in shell
    & az acr login -n $selectedACR.Value | Out-Null
    Write-Host "Logged into Docker registry $($selectedACR.Name)" -ForegroundColor Green
}

function New-NetworkAccessExceptionForResources {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [Alias("cna")]
    param()

    $url = 'https://gist.githubusercontent.com/moeller-projects/edef0e5eb63797f7fab3c79c0a30809b/raw/106b33a431f36ab905054c3acc5d1787f8dc7b5e/add-network-exception-for-resources.ps1'
    Write-Host "About to download and run: $url" -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -notmatch '^(?i)y(?:es)?$') { Write-Host "Aborted." -ForegroundColor Yellow; return }
    $temp = [System.IO.Path]::GetTempFileName().Replace('.tmp', '.ps1')
    try {
        Write-Verbose "Downloading script to $temp..."
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            Invoke-WebRequest -TimeoutSec 30 -ErrorAction Stop -Uri $url -OutFile $temp
        }
        else {
            Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop -Uri $url -OutFile $temp
        }
        if ($PSCmdlet.ShouldProcess($temp, 'execute downloaded script')) {
            & $temp
            Write-Host "Network access exceptions script executed." -ForegroundColor Green
        }
    }
    finally {
        Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue
    }
}
