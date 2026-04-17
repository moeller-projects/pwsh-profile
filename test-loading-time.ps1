[CmdletBinding()]
param(
    [ValidateRange(1, 1000)]
    [int]$Iterations = 20
)

$ErrorActionPreference = 'Stop'

function Measure-AverageDuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][string]$Activity,
        [Parameter(Mandatory)][scriptblock]$Operation
    )

    $totalTime = 0.0
    $operationToRun = $Operation
    foreach ($iteration in 1..$Count) {
        $percentComplete = [int](($iteration / $Count) * 100)
        Write-Progress -Id 1 -Activity $Activity -Status "$iteration / $Count" -PercentComplete $percentComplete
        $totalTime += (Measure-Command { & $operationToRun }).TotalMilliseconds
    }

    return ($totalTime / $Count)
}

if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    throw "pwsh executable was not found in PATH."
}

$pwshStartup = Measure-AverageDuration -Count $Iterations -Activity 'Measuring Shell Startup (NoProfile)' -Operation {
    pwsh -NoProfile -Command 1 | Out-Null
}

$profileStartup = Measure-AverageDuration -Count $Iterations -Activity 'Measuring Full Profile Load' -Operation {
    pwsh -Command 1 | Out-Null
}

Write-Progress -Id 1 -Activity 'Measuring Full Profile Load' -Completed

$result = [pscustomobject]@{
    Iterations                = $Iterations
    AveragePwshStartupMs      = [math]::Round($pwshStartup, 2)
    AveragePwshWithProfileMs  = [math]::Round($profileStartup, 2)
    AverageProfileOverheadMs  = [math]::Round(($profileStartup - $pwshStartup), 2)
}

$result
