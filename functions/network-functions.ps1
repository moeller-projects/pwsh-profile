function Get-PubIP {
    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $publicIP = (Invoke-WebRequest https://ipv4.icanhazip.com -TimeoutSec 10 -ErrorAction Stop).Content.Trim()
        } else {
            $publicIP = (Invoke-WebRequest https://ipv4.icanhazip.com -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop).Content.Trim()
        }
        return $publicIP
    }
    catch {
        Write-Error "Failed to retrieve public IP: $($_.Exception.Message)"
    }
}
