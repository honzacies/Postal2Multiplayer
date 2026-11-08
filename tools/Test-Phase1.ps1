param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$system = Join-Path $root 'POSTAL2Complete/System'
$artifacts = Join-Path $root 'artifacts'
if (!(Test-Path (Join-Path $system 'LanCoop.u'))) { throw 'Run tools/Build.ps1 first.' }
$server = $null
try {
    # Clear the previous run before polling, so an old readiness marker cannot pass.
    Set-Content -LiteralPath (Join-Path $system 'LanCoopServer.log') -Value '' -Encoding ascii
    $server = Start-Process -FilePath (Join-Path $system 'UCC.exe') -WorkingDirectory $system -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $artifacts 'Phase1Server.stdout.txt') -RedirectStandardError (Join-Path $artifacts 'Phase1Server.stderr.txt') -ArgumentList @('server', 'suburbs-3.fuk?Game=LanCoop.LanCoopProbeGame?MaxPlayers=2?Port=7787', 'ini=LanCoop.ini', 'userini=LanCoopUser.ini', 'log=LanCoopServer.log', 'unattended')
    $deadline = (Get-Date).AddSeconds(40)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        if ($server.HasExited) { throw "Server exited early: $($server.ExitCode)" }
        $log = Join-Path $system 'LanCoopServer.log'
        if ((Test-Path $log) -and (Select-String -LiteralPath $log -SimpleMatch 'Phase1_READY' -Quiet)) {
            $ready = $true
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (!$ready) { throw 'Server did not reach the readiness marker within 40 seconds.' }
    $sockets = & netstat.exe -ano -p udp
    $sockets | Set-Content -LiteralPath (Join-Path $artifacts 'Phase1Sockets.txt')
    $binding = $sockets | Where-Object { $_ -match (':7787\s+\S+\s+' + $server.Id + '\s*$') }
    if (!$binding) { throw 'Probe server does not own UDP port 7787.' }
    "PHASE1_SERVER_OK PID=$($server.Id) UDP=7787 Map=suburbs-3" | Tee-Object -FilePath (Join-Path $artifacts 'Phase1Result.txt')
    'This checks package loading and server startup only; campaign scripting errors are expected with the deathmatch probe.' | Add-Content (Join-Path $artifacts 'Phase1Result.txt')
} finally {
    if ($null -ne $server -and !$server.HasExited) { Stop-Process -Id $server.Id -Force; $server.WaitForExit() }
    if (Test-Path (Join-Path $system 'LanCoopServer.log')) {
        Copy-Item -LiteralPath (Join-Path $system 'LanCoopServer.log') -Destination (Join-Path $artifacts 'LanCoopCampaignProbe.log') -Force
    }
}
