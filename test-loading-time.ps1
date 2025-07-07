$totalTime = 0
1..100 | ForEach-Object {
    Write-Progress -Id 1 -Activity 'Measuring Profile Load' -PercentComplete $_
    $totalTime += (Measure-Command { pwsh -command 1 }).TotalMilliseconds # This is to measure pwsh startup without profile
}
$pwshStartup = $totalTime / 100

$totalProfileTime = 0
1..100 | ForEach-Object {
    Write-Progress -Id 1 -Activity 'Measuring Full Profile Load' -PercentComplete $_
    $totalProfileTime += (Measure-Command { pwsh -command 1 -NoProfile:$false }).TotalMilliseconds # This measures pwsh + profile
}
Write-Progress -id 1 -activity 'Measuring Full Profile Load' -Completed
$profileLoadTime = ($totalProfileTime / 100) - $pwshStartup
"Average Profile Load Time: $($profileLoadTime) ms"
