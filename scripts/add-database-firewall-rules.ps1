[CmdletBinding()]
param (
    [string]$RulePrefix = "lukas-at-home",
    [string]$IpAddress = $null,

    # NSG config
    [int]$NsgRulePriority = 1010,
    [ValidateSet("FullAccess", "SqlOnly", "CustomPorts")]
    [string]$NsgMode = "FullAccess",
    [string[]]$NsgDestinationPorts = @('*'),  # Used when NsgMode = CustomPorts

    # Resource selection
    [switch]$OnlySql,
    [switch]$OnlyVm,
    [switch]$OnlyMongo,

    # Output verbosity
    [switch]$Quiet,

    # Resource configuration file
    [string]$ConfigPath,
    [switch]$ShowConfigPath
)

$ErrorActionPreference = 'Stop'

# ---------------------- Helper functions ----------------------

function Write-Info {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Output $Message
    }
}

function Test-IPv4Address {
    param (
        [Parameter(Mandatory)]
        [string]$Address
    )
    # Simple IPv4 pattern (doesn't validate 0–255, but catches obvious junk)
    return $Address -match '^(?:\d{1,3}\.){3}\d{1,3}$'
}

function Get-DefaultConfigPath {
    # Default resource config path in AppData
    $base = $env:APPDATA
    if (-not $base) {
        $base = [Environment]::GetFolderPath('ApplicationData')
    }

    if (-not $base) {
        # Fallback: current directory
        return (Join-Path -Path (Get-Location) -ChildPath 'open-access-resources.yaml')
    }

    $folder = Join-Path -Path $base -ChildPath 'OpenAccessFirewall'
    if (-not (Test-Path $folder)) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }

    return (Join-Path -Path $folder -ChildPath 'resources.yaml')
}

function Load-ResourcesFromConfig {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-Warning "Resource config not found at '$Path'."
        return $null
    }

    $content = Get-Content -Raw -Path $Path -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($content)) {
        Write-Warning "Resource config at '$Path' is empty."
        return $null
    }

    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    $resources = $null

    switch ($ext) {
        ".json" {
            $resources = $content | ConvertFrom-Json
        }
        ".yml" { $resources = $content | ConvertFrom-Yaml }
        ".yaml" { $resources = $content | ConvertFrom-Yaml }
        default {
            Write-Warning "Unknown config extension '$ext'. Expected .json, .yml, or .yaml."
            return $null
        }
    }

    return $resources
}

function Remove-SQLFirewallRules {
    param (
        [string]$serverName,
        [string]$resourceGroup,
        [string]$rulePrefix
    )

    try {
        $existingRules = az sql server firewall-rule list `
            --resource-group $resourceGroup `
            --server $serverName `
            --query "[?starts_with(name, '$rulePrefix')].name" -o tsv

        if ($LASTEXITCODE -ne 0) {
            throw "az sql server firewall-rule list failed with exit code $LASTEXITCODE."
        }

        foreach ($rule in $existingRules) {
            if (-not [string]::IsNullOrWhiteSpace($rule)) {
                az sql server firewall-rule delete `
                    --resource-group $resourceGroup `
                    --server $serverName `
                    --name $rule | Out-Null

                if ($LASTEXITCODE -ne 0) {
                    throw "az sql server firewall-rule delete for rule '$rule' failed with exit code $LASTEXITCODE."
                }

                Write-Info "Deleted existing SQL firewall rule: $rule"
            }
        }
    }
    catch {
        Write-Error "Failed to remove SQL firewall rules for server $serverName. $_"
    }
}

function Remove-NSGRules {
    param (
        [string]$nsgName,
        [string]$resourceGroup,
        [string]$rulePrefix
    )

    try {
        $existingRules = az network nsg rule list `
            --resource-group $resourceGroup `
            --nsg-name $nsgName `
            --query "[?starts_with(name, '$rulePrefix')].name" -o tsv

        if ($LASTEXITCODE -ne 0) {
            throw "az network nsg rule list failed with exit code $LASTEXITCODE."
        }

        foreach ($rule in $existingRules) {
            if (-not [string]::IsNullOrWhiteSpace($rule)) {
                az network nsg rule delete `
                    --resource-group $resourceGroup `
                    --nsg-name $nsgName `
                    --name $rule | Out-Null

                if ($LASTEXITCODE -ne 0) {
                    throw "az network nsg rule delete for rule '$rule' failed with exit code $LASTEXITCODE."
                }

                Write-Info "Deleted existing NSG rule: $rule"
            }
        }
    }
    catch {
        Write-Error "Failed to remove NSG rules for NSG $nsgName. $_"
    }
}

function Manage-FirewallRules {
    param (
        [string]$serverName,
        [string]$resourceGroup,
        [string]$currentIp,
        [string]$rulePrefix
    )

    $result = [pscustomobject]@{
        Status   = 'Unknown'
        RuleName = $null
        Error    = $null
    }

    Remove-SQLFirewallRules -serverName $serverName -resourceGroup $resourceGroup -rulePrefix $rulePrefix

    try {
        $firewallRuleName = "$rulePrefix-$( Get-Date -Format yyyyMMdd-HHmmss )"

        az sql server firewall-rule create `
            --resource-group $resourceGroup `
            --server $serverName `
            --name $firewallRuleName `
            --start-ip-address $currentIp `
            --end-ip-address $currentIp | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "az sql server firewall-rule create failed with exit code $LASTEXITCODE."
        }

        $result.Status = 'Success'
        $result.RuleName = $firewallRuleName
        Write-Info "Created new firewall rule '$firewallRuleName' for SQL server $serverName."
    }
    catch {
        $result.Status = 'Failed'
        $result.Error = $_.Exception.Message
        Write-Error "Failed to create firewall rule for SQL server $serverName. $_"
    }

    return $result
}

function Manage-NSGRules {
    param (
        [string]$vmName,
        [string]$resourceGroup,
        [string]$currentIp,
        [string]$rulePrefix,
        [string]$nsgMode,
        [string[]]$destinationPorts
    )

    $result = [pscustomobject]@{
        Status    = 'Unknown'
        RuleName  = $null
        PortsUsed = $null
        Error     = $null
        Reason    = $null
    }

    try {
        # Determine effective ports based on mode
        switch ($nsgMode) {
            "FullAccess" { $effectivePorts = @('*') }
            "SqlOnly" { $effectivePorts = @('1433') }
            "CustomPorts" {
                if (-not $destinationPorts -or $destinationPorts.Count -eq 0) {
                    throw "NsgMode 'CustomPorts' requires -NsgDestinationPorts to be specified."
                }
                $effectivePorts = $destinationPorts
            }
            default { $effectivePorts = $destinationPorts }
        }

        # Get NIC ID for VM
        $nicId = az vm show `
            --resource-group $resourceGroup `
            --name $vmName `
            --query "networkProfile.networkInterfaces[0].id" -o tsv

        if ($LASTEXITCODE -ne 0) {
            throw "az vm show failed with exit code $LASTEXITCODE."
        }

        if (-not $nicId) {
            $result.Status = 'Skipped'
            $result.Reason = "No NIC found for VM."
            Write-Info "No NIC found for VM $vmName in resource group $resourceGroup."
            return $result
        }

        # Try NSG on NIC
        $nsgId = az network nic show `
            --ids $nicId `
            --query "networkSecurityGroup.id" -o tsv

        if ($LASTEXITCODE -ne 0) {
            throw "az network nic show (for NSG) failed with exit code $LASTEXITCODE."
        }

        if (-not $nsgId) {
            Write-Info "No NSG found for NIC of VM $vmName. Checking for NSG on the subnet..."

            $subnetId = az network nic show `
                --ids $nicId `
                --query "ipConfigurations[0].subnet.id" -o tsv

            if ($LASTEXITCODE -ne 0) {
                throw "az network nic show (for subnet) failed with exit code $LASTEXITCODE."
            }

            if ($subnetId) {
                $nsgId = az network vnet subnet show `
                    --ids $subnetId `
                    --query "networkSecurityGroup.id" -o tsv

                if ($LASTEXITCODE -ne 0) {
                    throw "az network vnet subnet show failed with exit code $LASTEXITCODE."
                }
            }

            if (-not $nsgId) {
                $result.Status = 'Skipped'
                $result.Reason = "No NSG on NIC or subnet."
                Write-Info "No NSG found on the subnet for VM $vmName in resource group $resourceGroup."
                return $result
            }
        }

        # nsgId is a full resource ID: /subscriptions/.../resourceGroups/<rg>/providers/.../networkSecurityGroups/<name>
        $nsgParts = $nsgId.Split('/')
        $nsgResourceGroup = $nsgParts[4]
        $nsgName = $nsgParts[-1]

        Remove-NSGRules -nsgName $nsgName -resourceGroup $nsgResourceGroup -rulePrefix $rulePrefix

        $nsgRuleName = "$rulePrefix-$( Get-Date -Format yyyyMMdd-HHmmss )"

        az network nsg rule create `
            --resource-group $nsgResourceGroup `
            --nsg-name $nsgName `
            --name $nsgRuleName `
            --priority $NsgRulePriority `
            --source-address-prefixes $currentIp `
            --destination-port-ranges $effectivePorts `
            --access Allow `
            --protocol Tcp `
            --direction Inbound | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "az network nsg rule create failed with exit code $LASTEXITCODE."
        }

        $result.Status = 'Success'
        $result.RuleName = $nsgRuleName
        $result.PortsUsed = $effectivePorts -join ','
        Write-Info "Created new NSG rule '$nsgRuleName' for VM $vmName, allowing ports: $($effectivePorts -join ', ')."
    }
    catch {
        $result.Status = 'Failed'
        $result.Error = $_.Exception.Message
        Write-Error "Failed to manage NSG rules for VM $vmName. $_"
    }

    return $result
}

# ---------------------- IP resolution ----------------------

try {
    if ([string]::IsNullOrWhiteSpace($IpAddress)) {
        $response = Invoke-WebRequest https://ipv4.icanhazip.com -UseBasicParsing
        $resolvedIp = $response.Content.Trim()
    }
    else {
        $resolvedIp = $IpAddress.Trim()
    }
}
catch {
    Write-Error "Unable to determine current IP address from external service. $_"
    return
}

if (-not (Test-IPv4Address -Address $resolvedIp)) {
    Write-Error "The IP address '$resolvedIp' is not a valid IPv4 address."
    return
}

$currentIp = $resolvedIp
Write-Info "Using IP Address: $currentIp"

# ---------------------- Resource configuration ----------------------

# Determine config path (default in AppData if not provided)
$defaultConfigPath = Get-DefaultConfigPath
if (-not $ConfigPath) {
    $ConfigPath = $defaultConfigPath
}

if ($ShowConfigPath) {
    Write-Output "Resource config path: $ConfigPath"

    if (Test-Path $ConfigPath) {
        $content = Get-Content -Raw -Path $ConfigPath -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Output "Status: File exists but is empty."
        }
        else {
            Write-Output "Status: File exists and is non-empty."
        }
    }
    else {
        Write-Output "Status: File does not exist."
    }

    return
}

# Built-in default resources (used if config is missing/empty)
$defaultResources = @()

$resources = $null
$configResources = Load-ResourcesFromConfig -Path $ConfigPath

if ($configResources) {
    # Ensure we always have an array
    if ($configResources -isnot [System.Collections.IEnumerable] -or
        $configResources -is [string]) {
        $resources = @($configResources)
    }
    else {
        $resources = @($configResources)
    }

    Write-Info "Loaded $($resources.Count) resource(s) from config '$ConfigPath'."
}
else {
    $resources = $defaultResources
    Write-Info "Using built-in default resource list."
}

# Apply resource selection filters if any Only* flags are set
$hasSelectionFilter = $OnlySql -or $OnlyVm -or $OnlyMongo
if ($hasSelectionFilter) {
    $resources = $resources | Where-Object {
        ($OnlySql -and $_.Type -eq 'SQLServer') -or
        ($OnlyVm -and $_.Type -eq 'VM') -or
        ($OnlyMongo -and $_.Type -eq 'MongoDB')
    }

    Write-Info "Applied selection filters. Remaining resources: $($resources.Count)"
}

if (-not $resources -or $resources.Count -eq 0) {
    Write-Warning "No resources to process after applying configuration and filters."
    return
}

# ---------------------- Main processing & summary ----------------------

$summary = @()

# Group resources by SubscriptionId to minimize subscription switching
$groupedResources = $resources | Group-Object -Property SubscriptionId

foreach ($group in $groupedResources) {
    $subscriptionId = $group.Name

    if (-not [string]::IsNullOrWhiteSpace($subscriptionId)) {
        az account set --subscription $subscriptionId | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set Azure subscription '$subscriptionId' (exit code $LASTEXITCODE)."
        }

        Write-Info "Switched to subscription: $subscriptionId"
    }

    foreach ($resource in $group.Group) {
        $resourceType = $resource.Type
        $resName = $resource.Name
        $resGroup = $resource.ResourceGroup

        switch ($resourceType) {

            "SQLServer" {
                $fwResult = Manage-FirewallRules -serverName $resName `
                    -resourceGroup $resGroup `
                    -currentIp $currentIp `
                    -rulePrefix $RulePrefix

                $details = if ($fwResult.Status -eq 'Success') {
                    "Firewall rule $($fwResult.RuleName) created for IP $currentIp"
                }
                elseif ($fwResult.Status -eq 'Failed') {
                    $fwResult.Error
                }
                else {
                    "Status: $($fwResult.Status)"
                }

                $summary += [pscustomobject]@{
                    Type           = "SQLServer"
                    Name           = $resName
                    ResourceGroup  = $resGroup
                    SubscriptionId = $subscriptionId
                    Status         = $fwResult.Status
                    Details        = $details
                }

                Write-Info "Processed SQLServer: $resName"
            }

            "VM" {
                $nsgResult = Manage-NSGRules -vmName $resName `
                    -resourceGroup $resGroup `
                    -currentIp $currentIp `
                    -rulePrefix $RulePrefix `
                    -nsgMode $NsgMode `
                    -destinationPorts $NsgDestinationPorts

                $details = switch ($nsgResult.Status) {
                    'Success' { "NSG rule $($nsgResult.RuleName) created (Ports: $($nsgResult.PortsUsed)) for IP $currentIp" }
                    'Skipped' { $nsgResult.Reason }
                    'Failed' { $nsgResult.Error }
                    default { "Status: $($nsgResult.Status)" }
                }

                $summary += [pscustomobject]@{
                    Type           = "VM"
                    Name           = $resName
                    ResourceGroup  = $resGroup
                    SubscriptionId = $subscriptionId
                    Status         = $nsgResult.Status
                    Details        = $details
                }

                Write-Info "Processed VM: $resName"
            }

            "MongoDB" {
                $status = 'Unknown'
                $details = $null

                try {
                    atlas accessLists create $currentIp --type ipAddress `
                        --comment $RulePrefix `
                        --deleteAfter $( Get-Date ).AddDays(0.8).ToString("o") | Out-Null

                    if ($LASTEXITCODE -ne 0) {
                        throw "atlas accessLists create failed with exit code $LASTEXITCODE."
                    }

                    $status = 'Success'
                    $details = "Atlas access list entry created for IP $currentIp"
                    Write-Info "Processed MongoDB (Atlas access list created for $currentIp)."
                }
                catch {
                    $status = 'Failed'
                    $details = $_.Exception.Message
                    Write-Error "Failed to manage MongoDB Atlas access list for $currentIp. $_"
                }

                $summary += [pscustomobject]@{
                    Type           = "MongoDB"
                    Name           = $resName
                    ResourceGroup  = $resGroup
                    SubscriptionId = $subscriptionId
                    Status         = $status
                    Details        = $details
                }
            }
        }
    }
}

# ---------------------- Final summary table ----------------------

Write-Output ""
Write-Output "===== Access Management Summary ====="
$summary | Format-Table -AutoSize Type, Name, ResourceGroup, SubscriptionId, Status, Details
