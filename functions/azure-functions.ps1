class MenuOption {
    [String]$Name
    [String]$Value

    [String]ToString() {
        return "$($this.Name) ($($this.Value))"
    }
}

function New-MenuItem {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Name,
        [string]$Value
    )
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

    $selectedAZSub = $null
    if (Get-Command Show-Menu -ErrorAction SilentlyContinue) {
        $selectedAZSub = Show-Menu -MenuItems $Options
    }
    else {
        Write-Host "Available subscriptions:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $Options.Count; $i++) {
            Write-Host "  [$($i + 1)] $($Options[$i].Name) ($($Options[$i].Value))"
        }
        $choice = Read-Host "Enter number"
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $Options.Count) { $selectedAZSub = $Options[$idx] }
    }

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

    $selectedACR = $null
    if (Get-Command Show-Menu -ErrorAction SilentlyContinue) {
        $selectedACR = Show-Menu -MenuItems $Options
    }
    else {
        Write-Host "Available container registries:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $Options.Count; $i++) {
            Write-Host "  [$($i + 1)] $($Options[$i].Name) ($($Options[$i].Value))"
        }
        $choice = Read-Host "Enter number"
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $Options.Count) { $selectedACR = $Options[$idx] }
    }

    if ($null -eq $selectedACR) {
        Write-Warning "No ACR selected."
        return
    }

    Write-Verbose "Logging into ACR via az for $($selectedACR.Value)..."
    # Simpler and avoids handling credentials in shell
    & az acr login -n $selectedACR.Value | Out-Null
    Write-Host "Logged into Docker registry $($selectedACR.Name)" -ForegroundColor Green
}
