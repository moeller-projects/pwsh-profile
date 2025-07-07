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

function Switch-Azure-Subscription {
    [CmdletBinding()]
    [Alias("sas")]
    param ()

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

function Login-ACR {
    [CmdletBinding()]
    [Alias("lacr")]
    param ()

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

    Write-Verbose "Getting credentials for $($selectedACR.Value)..."
    # External call to az CLI - inherent overhead
    $credentials = az acr credential show --name $selectedACR.Value -o json | ConvertFrom-Json

    Write-Verbose "Logging into Docker registry $($selectedACR.Name)..."
    # External call to docker CLI - inherent overhead
    docker login $selectedACR.Name --username $credentials.username --password $credentials.passwords[0].value
    Write-Host "Logged into Docker registry $($selectedACR.Name)" -ForegroundColor Green
}

function Create-Network-Access-Exceptions-For-Resources {
    [CmdletBinding()]
    [Alias("cna")]
    param()

    Write-Verbose "Downloading and executing network exception script..."
    # This involves network I/O and script execution, will always have overhead.
    # No direct PowerShell micro-optimizations apply here.
    Invoke-WebRequest -UseBasicParsing https://gist.githubusercontent.com/moeller-projects/edef0e5eb63797f7fab3c79c0a30809b/raw/106b33a431f36ab905054c3acc5d1787f8dc7b5e/add-network-exception-for-resources.ps1 | Invoke-Expression
    Write-Host "Network access exceptions script executed." -ForegroundColor Green
}
