function Get-PubIP {
    $publicIP = (Invoke-WebRequest https://ipv4.icanhazip.com -UseBasicParsing).Content.Trim() # Added -UseBasicParsing for potentially faster parsing
    return $publicIP
}
