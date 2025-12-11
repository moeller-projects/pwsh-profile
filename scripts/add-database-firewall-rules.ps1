[CmdletBinding()]
param (
    [string]$RulePrefix = "lukas-at-home",
    [string]$IpAddress = $null,

    # New: configurable NSG settings instead of magic numbers
    [int]$NsgRulePriority = 1010,
    [string[]]$NsgDestinationPorts = @('*')  # e.g. @('1433','3389') if you want to restrict
)

$ErrorActionPreference = 'Stop'

function Test-IPv4Address {
    param (
        [Parameter(Mandatory)]
        [string]$Address
    )

    # Simple IPv4 pattern (doesn't validate 0–255, but enough to catch obvious junk)
    return $Address -match '^(?:\d{1,3}\.){3}\d{1,3}$'
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

                Write-Output "Deleted existing SQL firewall rule: $rule"
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

                Write-Output "Deleted existing NSG rule: $rule"
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

    # Always try to clean up older rules with the same prefix
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

        Write-Output "Created new firewall rule '$firewallRuleName' for SQL server $serverName."
    }
    catch {
        Write-Error "Failed to create firewall rule for SQL server $serverName. $_"
    }
}

function Manage-NSGRules {
    param (
        [string]$vmName,
        [string]$resourceGroup,
        [string]$currentIp,
        [string]$rulePrefix
    )

    try {
        # Get NIC ID for VM
        $nicId = az vm show `
            --resource-group $resourceGroup `
            --name $vmName `
            --query "networkProfile.networkInterfaces[0].id" -o tsv

        if ($LASTEXITCODE -ne 0) {
            throw "az vm show failed with exit code $LASTEXITCODE."
        }

        if (-not $nicId) {
            Write-Output "No NIC found for VM $vmName in resource group $resourceGroup."
            return
        }

        # Try NSG on NIC
        $nsgId = az network nic show `
            --ids $nicId `
            --query "networkSecurityGroup.id" -o tsv

        if ($LASTEXITCODE -ne 0) {
            throw "az network nic show (for NSG) failed with exit code $LASTEXITCODE."
        }

        if (-not $nsgId) {
            Write-Output "No NSG found for NIC of VM $vmName. Checking for NSG on the subnet..."

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
                Write-Output "No NSG found on the subnet for VM $vmName in resource group $resourceGroup."
                return
            }
        }

        # nsgId is a full resource ID: /subscriptions/.../resourceGroups/<rg>/providers/.../networkSecurityGroups/<name>
        $nsgParts = $nsgId.Split('/')
        $nsgResourceGroup = $nsgParts[4]
        $nsgName = $nsgParts[-1]

        # Clean old rules for that NSG/prefix
        Remove-NSGRules -nsgName $nsgName -resourceGroup $nsgResourceGroup -rulePrefix $rulePrefix

        # Create new NSG rule
        $nsgRuleName = "$rulePrefix-$( Get-Date -Format yyyyMMdd-HHmmss )"

        az network nsg rule create `
            --resource-group $nsgResourceGroup `
            --nsg-name $nsgName `
            --name $nsgRuleName `
            --priority $NsgRulePriority `
            --source-address-prefixes $currentIp `
            --destination-port-ranges $NsgDestinationPorts `
            --access Allow `
            --protocol Tcp `
            --direction Inbound | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "az network nsg rule create failed with exit code $LASTEXITCODE."
        }

        Write-Output "Created new NSG rule '$nsgRuleName' for VM $vmName, allowing ports: $($NsgDestinationPorts -join ', ')."
    }
    catch {
        Write-Error "Failed to manage NSG rules for VM $vmName. $_"
    }
}

# Determine the IP address to use (with validation and error handling)
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
Write-Output "Using IP Address: $currentIp"

# Resource definitions
$resources = @(
    @{ Type = "MongoDB";  SubscriptionId = $null; },
    @{ Type = "VM";       SubscriptionId = "f6f76124-3462-4477-9ad6-7c2890bdfc90"; Name = "intg-sql-vm-WS2019G1";     ResourceGroup = "INTG-LEGACY-DB" },
    @{ Type = "VM";       SubscriptionId = "a09a01c4-a000-49b5-962b-f32b357948a5"; Name = "prod-sql-vm";              ResourceGroup = "aveato-legacy-databases" },
    @{ Type = "SQLServer";SubscriptionId = "dfd2fba1-b1b9-47c5-902b-295b5e3f83a1"; Name = "intg-database-sql";        ResourceGroup = "intg" },
    @{ Type = "SQLServer";SubscriptionId = "07b4098b-f62d-4f89-84a2-2f73bbae0ab4"; Name = "prod-laekkerai-sqlserver"; ResourceGroup = "Databases" }
)

# Group resources by SubscriptionId to minimize subscription switching
$groupedResources = $resources | Group-Object -Property SubscriptionId

foreach ($group in $groupedResources) {
    $subscriptionId = $group.Name

    if (-not [string]::IsNullOrWhiteSpace($subscriptionId)) {
        az account set --subscription $subscriptionId | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set Azure subscription '$subscriptionId' (exit code $LASTEXITCODE)."
        }

        Write-Output "Switched to subscription: $subscriptionId"
    }

    foreach ($resource in $group.Group) {
        switch ($resource.Type) {
            "SQLServer" {
                Manage-FirewallRules -serverName $resource.Name `
                    -resourceGroup $resource.ResourceGroup `
                    -currentIp $currentIp `
                    -rulePrefix $RulePrefix

                Write-Output "Processed SQLServer: $($resource.Name)"
            }
            "VM" {
                Manage-NSGRules -vmName $resource.Name `
                    -resourceGroup $resource.ResourceGroup `
                    -currentIp $currentIp `
                    -rulePrefix $RulePrefix

                Write-Output "Processed VM: $($resource.Name)"
            }
            "MongoDB" {
                try {
                    atlas accessLists create $currentIp --type ipAddress `
                        --comment $RulePrefix `
                        --deleteAfter $( Get-Date ).AddDays(0.8).ToString("o") | Out-Null

                    if ($LASTEXITCODE -ne 0) {
                        throw "atlas accessLists create failed with exit code $LASTEXITCODE."
                    }

                    Write-Output "Processed MongoDB (Atlas access list created for $currentIp)."
                }
                catch {
                    Write-Error "Failed to manage MongoDB Atlas access list for $currentIp. $_"
                }
            }
        }
    }
}
