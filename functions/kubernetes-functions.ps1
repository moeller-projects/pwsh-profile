function Select-KubeContext {
    [CmdletBinding()]
    [Alias('kubectx')]
    param (
        [parameter(Mandatory = $False, Position = 0, ValueFromRemainingArguments = $True)]
        [Object[]] $Arguments
    )
    begin {
        if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { Write-Error "kubectl not found in PATH."; return }
        if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { Write-Error "fzf not found in PATH."; return }
        if ($Arguments.Length -gt 0) {
            $ctx = & kubectl config get-contexts -o=name | fzf -q ($Arguments -join ' ') # Pass arguments correctly
        }
        else {
            $ctx = & kubectl config get-contexts -o=name | fzf
        }
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
        [Object[]] $Arguments
    )
    begin {
        if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { Write-Error "kubectl not found in PATH."; return }
        if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { Write-Error "fzf not found in PATH."; return }
        if ($Arguments.Length -gt 0) {
            $ns = & kubectl get namespace -o=name | fzf -q ($Arguments -join ' ') # Pass arguments correctly
        }
        else {
            $ns = & kubectl get namespace -o=name | fzf
        }
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
