$totalTime = 0
1..100 | ForEach-Object {
    Write-Progress -Id 1 -Activity 'Measuring Shell Startup (NoProfile)' -PercentComplete $_
    $totalTime += (Measure-Command { pwsh -NoProfile -Command 1 }).TotalMilliseconds
}
$pwshStartup = $totalTime / 100

$totalProfileTime = 0
1..100 | ForEach-Object {
    Write-Progress -Id 1 -Activity 'Measuring Full Profile Load' -PercentComplete $_
    $totalProfileTime += (Measure-Command { pwsh -Command 1 }).TotalMilliseconds # pwsh + profile
}
Write-Progress -id 1 -activity 'Measuring Full Profile Load' -Completed
$profileLoadTime = ($totalProfileTime / 100) - $pwshStartup
"Average Profile Load Time: $($profileLoadTime) ms"
