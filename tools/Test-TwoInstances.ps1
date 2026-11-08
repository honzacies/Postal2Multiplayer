# Opens two real game windows and closes only these test instances afterward.
param([ValidateRange(3,60)][int]$HoldSeconds = 3, [switch]$TravelRoundTrip)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$system = Join-Path $root 'POSTAL2Complete/System'
$artifacts = Join-Path $root 'artifacts'
$hostProcess = $null
$clientProcess = $null
foreach ($role in @('Host','Client')) {
    & (Join-Path $PSScriptRoot 'Start-Instance.ps1') -Role $role -PrepareOnly
    Copy-Item (Join-Path $system "LanCoop$role.ini") (Join-Path $system "LanCoopTwo$role.ini") -Force
    Copy-Item (Join-Path $system "LanCoop${role}User.ini") (Join-Path $system "LanCoopTwo${role}User.ini") -Force
    Set-Content (Join-Path $system "LanCoopTwo$role.log") -Value '' -Encoding ascii
}
$hostLog = Join-Path $system 'LanCoopTwoHost.log'
$clientLog = Join-Path $system 'LanCoopTwoClient.log'
if ($TravelRoundTrip) {
    Set-Content -LiteralPath (Join-Path $system 'LanCoopTravelProbe.ini') -Value "[LanCoop.LanCoopTravelProbe]`r`nbPassed=False`r`nbFailed=False`r`nLastCheckedStage=-1" -Encoding ascii
}
try {
    $hostURL = 'suburbs-3.fuk?Game=LanCoop.LanCoopGameInfo?listen?Port=7787?Name=Dude?Class=GameTypes.AWPostalDude'
    if ($TravelRoundTrip) { $hostURL += '?CoopTravelProbe=1' }
    $hostProcess = Start-Process -FilePath (Join-Path $system 'Postal2.exe') -WorkingDirectory $system -WindowStyle Normal -PassThru -ArgumentList @($hostURL,'ini=LanCoopTwoHost.ini','userini=LanCoopTwoHostUser.ini','log=LanCoopTwoHost.log','-windowed','-NewWindow','-FORCELOGFLUSH')
    $deadline = (Get-Date).AddSeconds(40)
    while (!(Select-String -LiteralPath $hostLog -SimpleMatch 'PlayerJoin Name=Dude' -Quiet)) {
        if ($hostProcess.HasExited -or (Select-String -LiteralPath $hostLog -SimpleMatch 'Critical:' -Quiet)) { throw 'Test host failed before client launch.' }
        if ((Get-Date) -gt $deadline) { throw 'Test host did not become ready.' }
        Start-Sleep -Milliseconds 250
    }
    $clientProcess = Start-Process -FilePath (Join-Path $system 'Postal2.exe') -WorkingDirectory $system -WindowStyle Normal -PassThru -ArgumentList @('127.0.0.1:7787?Name=Guest?Class=GameTypes.AWPostalDude','ini=LanCoopTwoClient.ini','userini=LanCoopTwoClientUser.ini','log=LanCoopTwoClient.log','-windowed','-NewWindow','-FORCELOGFLUSH')
    $joinDeadline = (Get-Date).AddSeconds(90)
    $connected = $false
    while ((Get-Date) -lt $joinDeadline) {
        if ($hostProcess.HasExited -or $clientProcess.HasExited) { break }
        if (Select-String -LiteralPath $hostLog,$clientLog -SimpleMatch 'Critical:' -Quiet) { break }
        if (Select-String -LiteralPath $hostLog -SimpleMatch 'PlayerJoin Name=Guest' -Quiet) { $connected = $true; break }
        Start-Sleep -Milliseconds 500
    }
    $travelPassed = $false
    if ($TravelRoundTrip -and $connected) {
        $travelDeadline = (Get-Date).AddSeconds(150)
        while ((Get-Date) -lt $travelDeadline) {
            if ($hostProcess.HasExited -or $clientProcess.HasExited) { break }
            if (Select-String -LiteralPath $hostLog,$clientLog -Pattern 'Critical:|TravelProbeFailed|TravelFailed|InventoryClientCheckFailed' -Quiet) { break }
            if (Select-String -LiteralPath $hostLog -SimpleMatch 'TravelRoundtripOk' -Quiet) { $travelPassed = $true; break }
            $probeState = Join-Path $system 'LanCoopTravelProbe.ini'
            if (Select-String -LiteralPath $probeState -Pattern '^bFailed=True' -Quiet) { break }
            if (Select-String -LiteralPath $probeState -Pattern '^bPassed=True' -Quiet) { $travelPassed = $true; break }
            Start-Sleep -Milliseconds 500
        }
    }
    Start-Sleep -Seconds $HoldSeconds
    $separate = !$hostProcess.HasExited -and !$clientProcess.HasExited -and (Get-Item $clientLog).Length -gt 0
    $hostFatal = [bool](Select-String -LiteralPath $hostLog -SimpleMatch 'Critical:' -Quiet)
    $clientFatal = [bool](Select-String -LiteralPath $clientLog -SimpleMatch 'Critical:' -Quiet)
    "TWO_INSTANCES Separate=$separate Connected=$connected TravelPassed=$travelPassed HostPID=$($hostProcess.Id) ClientPID=$($clientProcess.Id) HostFatal=$hostFatal ClientFatal=$clientFatal" | Tee-Object -FilePath (Join-Path $artifacts 'TwoInstances.result.txt')
    if (!$separate) { throw 'Two independent running instances were not established.' }
    if (!$connected -or $hostFatal -or $clientFatal) { throw 'Two-client connection failed.' }
    if ($TravelRoundTrip -and !$travelPassed) { throw 'Map round-trip test failed.' }
} finally {
    foreach ($process in @($clientProcess,$hostProcess)) {
        if ($null -ne $process -and !$process.HasExited) { Stop-Process -Id $process.Id -Force; $process.WaitForExit() }
    }
    Copy-Item -LiteralPath $hostLog,$clientLog -Destination $artifacts -Force
    if ($TravelRoundTrip) { Copy-Item -LiteralPath (Join-Path $system 'LanCoopTravelProbe.ini') -Destination $artifacts -Force }
}
