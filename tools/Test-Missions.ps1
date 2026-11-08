$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$system = Join-Path $root 'POSTAL2Complete/System'
$artifacts = Join-Path $root 'artifacts'
$result = Join-Path $system 'LanCoopMissionProbe.ini'
Set-Content -LiteralPath $result -Value "[LanCoop.LanCoopMissionProbe]`r`nbFinished=False`r`nPassed=0`r`nFailed=0`r`nSkipped=0" -Encoding ascii
$server = $null
try {
    $server = Start-Process -FilePath (Join-Path $system 'UCC.exe') -WorkingDirectory $system -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $artifacts 'MissionAudit.stdout.txt') -RedirectStandardError (Join-Path $artifacts 'MissionAudit.stderr.txt') -ArgumentList @('server','suburbs-3.fuk?Game=LanCoop.LanCoopGameInfo?Port=7797?CoopMissionProbe=1','ini=LanCoop.ini','userini=LanCoopUser.ini','log=LanCoopMissionAudit.log','unattended')
    $deadline = (Get-Date).AddSeconds(90)
    while (!(Select-String -LiteralPath $result -Pattern '^bFinished=True' -Quiet)) {
        if ($server.HasExited) { throw "Mission audit exited: $($server.ExitCode)" }
        if ((Get-Date) -gt $deadline) { throw 'Mission audit timed out.' }
        Start-Sleep -Milliseconds 250
    }
    Get-Content -LiteralPath $result
    if (!(Select-String -LiteralPath $result -Pattern '^Failed=0$' -Quiet)) { throw 'Mission event audit has failures.' }
} finally {
    if ($null -ne $server -and !$server.HasExited) { Stop-Process -Id $server.Id -Force; $server.WaitForExit() }
    Copy-Item -LiteralPath $result -Destination $artifacts -Force
    Copy-Item -LiteralPath (Join-Path $system 'LanCoopMissionAudit.log') -Destination $artifacts -Force
}
