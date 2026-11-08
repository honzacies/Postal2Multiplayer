# Starts a real windowed host briefly, then closes only the instance it created.
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$system = Join-Path $root 'POSTAL2Complete/System'
$artifacts = Join-Path $root 'artifacts'
& (Join-Path $PSScriptRoot 'Start-Instance.ps1') -Role Host -PrepareOnly
Copy-Item (Join-Path $system 'LanCoopHost.ini') (Join-Path $system 'LanCoopListenTest.ini') -Force
Copy-Item (Join-Path $system 'LanCoopHostUser.ini') (Join-Path $system 'LanCoopListenTestUser.ini') -Force
$log = Join-Path $system 'LanCoopListenTest.log'
Set-Content -LiteralPath $log -Value '' -Encoding ascii
$process = $null
try {
    $process = Start-Process -FilePath (Join-Path $system 'Postal2.exe') -WorkingDirectory $system -WindowStyle Normal -PassThru -ArgumentList @('suburbs-3.fuk?Game=LanCoop.LanCoopGameInfo?listen?Port=7787?Name=Host?Class=GameTypes.AWPostalDude','ini=LanCoopListenTest.ini','userini=LanCoopListenTestUser.ini','log=LanCoopListenTest.log','-windowed','-NewWindow','-FORCELOGFLUSH')
    $deadline = (Get-Date).AddSeconds(40)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        if ($process.HasExited) { throw "Listen host exited: $($process.ExitCode)" }
        if (Select-String -LiteralPath $log -Pattern 'Critical:|Runaway loop detected' -Quiet) { throw 'Listen host reported a fatal error. See artifacts/LanCoopListenTest.log.' }
        if (Select-String -LiteralPath $log -SimpleMatch 'WorldReady' -Quiet) { $ready=$true; break }
        Start-Sleep -Milliseconds 250
    }
    if (!$ready) { throw 'Listen host did not reach WORLD_READY in 40 seconds.' }
    Start-Sleep -Seconds 3
    if ($process.HasExited -or (Select-String -LiteralPath $log -Pattern 'Critical:|Runaway loop detected' -Quiet)) { throw 'Listen host failed after WORLD_READY.' }
    "LISTEN_HOST_OK PID=$($process.Id)" | Tee-Object -FilePath (Join-Path $artifacts 'ListenHost.result.txt')
} finally {
    if ($null -ne $process -and !$process.HasExited) { Stop-Process -Id $process.Id -Force; $process.WaitForExit() }
    Copy-Item -LiteralPath $log -Destination $artifacts -Force
}
