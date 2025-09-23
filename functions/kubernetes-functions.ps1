function Select-KubeContext {
    [CmdletBinding()]
    [Alias('kubectx')]
    param (
        [parameter(Mandatory = $False, Position = 0, ValueFromRemainingArguments = $True)]
        [Object[]] $Arguments,
        [switch]$Refresh
    )
    begin {
        if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { Write-Error "kubectl not found in PATH."; return }
        if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { Write-Error "fzf not found in PATH."; return }
        $ttl = 60
        if ($Refresh -or -not $script:KubeContextsCache -or ((Get-Date) - $script:KubeContextsCacheTime).TotalSeconds -gt $ttl) {
            $script:KubeContextsCache = @(& kubectl config get-contexts -o=name)
            $script:KubeContextsCacheTime = Get-Date
        }
        $source = $script:KubeContextsCache
        $ctx = if ($Arguments.Length -gt 0) { $source | fzf -q ($Arguments -join ' ') } else { $source | fzf }
    }
    process {
        if ($ctx -ne '') {
            & kubectl config use-context $ctx
            Write-Host "Kubernetes context set to $ctx" -ForegroundColor Green
        }
        else {
            Write-Warning "No Kubernetes context selected."
        }
    }
}

function Select-KubeNamespace {
    [CmdletBinding()]
    [Alias('kubens')]
    param (
        [parameter(Mandatory = $False, Position = 0, ValueFromRemainingArguments = $True)]
        [Object[]] $Arguments,
        [switch]$Refresh
    )
    begin {
        if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { Write-Error "kubectl not found in PATH."; return }
        if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { Write-Error "fzf not found in PATH."; return }
        $ttl = 60
        if ($Refresh -or -not $script:KubeNamespacesCache -or ((Get-Date) - $script:KubeNamespacesCacheTime).TotalSeconds -gt $ttl) {
            $script:KubeNamespacesCache = @(& kubectl get namespace -o=name)
            $script:KubeNamespacesCacheTime = Get-Date
        }
        $source = $script:KubeNamespacesCache
        $ns = if ($Arguments.Length -gt 0) { $source | fzf -q ($Arguments -join ' ') } else { $source | fzf }
    }
    process {
        if ($ns -ne '') {
            $ns = $ns -replace '^namespace/'
            & kubectl config set-context --current --namespace=$ns
            Write-Host "Kubernetes namespace set to $ns" -ForegroundColor Green
        }
        else {
            Write-Warning "No Kubernetes namespace selected."
        }
    }
}
