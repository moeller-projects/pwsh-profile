$Iterations = $null
param(
    [int]$Iterations = 20
)

$totalTime = 0
1..$Iterations | ForEach-Object {
    Write-Progress -Id 1 -Activity 'Measuring Shell Startup (NoProfile)' -PercentComplete $_
    $totalTime += (Measure-Command { pwsh -NoProfile -Command 1 }).TotalMilliseconds
}
$pwshStartup = $totalTime / $Iterations

$totalProfileTime = 0
1..$Iterations | ForEach-Object {
    Write-Progress -Id 1 -Activity 'Measuring Full Profile Load' -PercentComplete $_
    $totalProfileTime += (Measure-Command { pwsh -Command 1 }).TotalMilliseconds # pwsh + profile
}
Write-Progress -id 1 -activity 'Measuring Full Profile Load' -Completed
$profileLoadTime = ($totalProfileTime / $Iterations) - $pwshStartup
"Average Profile Load Time: $($profileLoadTime) ms"
