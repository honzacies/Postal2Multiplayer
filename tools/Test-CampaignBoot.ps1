param([switch]$Lifecycle)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$system = Join-Path $root 'POSTAL2Complete/System'
$artifacts = Join-Path $root 'artifacts'
$server = $null
$tag = if ($Lifecycle) { 'CampaignLifecycle' } else { 'CampaignBoot' }
$marker = if ($Lifecycle) { 'LifecycleOk' } else { 'CampaignWaiting' }
$log = Join-Path $system "LanCoop$tag.log"
try {
    Set-Content -LiteralPath $log -Value '' -Encoding ascii
    $url = 'suburbs-3.fuk?Game=LanCoop.LanCoopGameInfo?Port=7787'
    if ($Lifecycle) { $url += '?LifecycleProbe=1' }
    $server = Start-Process -FilePath (Join-Path $system 'UCC.exe') -WorkingDirectory $system -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $artifacts "$tag.stdout.txt") -RedirectStandardError (Join-Path $artifacts "$tag.stderr.txt") -ArgumentList @('server', $url, 'ini=LanCoop.ini', 'userini=LanCoopUser.ini', "log=LanCoop$tag.log", 'unattended')
    $deadline = (Get-Date).AddSeconds(40)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        if ($server.HasExited) { throw "Server exited early: $($server.ExitCode)" }
        # Engine log writes are buffered; stdout exposes short runs promptly.
        $outputs = @($log, (Join-Path $artifacts "$tag.stdout.txt")) | Where-Object { Test-Path $_ }
        if (Select-String -LiteralPath $outputs -SimpleMatch 'LifecycleFailed' -Quiet) { throw 'Authoritative lifecycle probe failed. See the log.' }
        if (Select-String -LiteralPath $outputs -SimpleMatch $marker -Quiet) { $ready = $true; break }
        Start-Sleep -Milliseconds 250
    }
    if (!$ready) { throw "Missing marker: $marker" }
    # Keep the server alive briefly after the marker to catch immediate failures.
    Start-Sleep -Seconds 2
    if ($server.HasExited) { throw 'Server exited after readiness.' }
    $sockets = & netstat.exe -ano -p udp
    if (!($sockets | Where-Object { $_ -match (':7787\s+\S+\s+' + $server.Id + '\s*$') })) { throw 'Cannot verify server UDP socket.' }
    "$tag OK PID=$($server.Id) UDP=7787 Marker=$marker" | Tee-Object -FilePath (Join-Path $artifacts "$tag.result.txt")
} finally {
    if ($null -ne $server -and !$server.HasExited) { Stop-Process -Id $server.Id -Force; $server.WaitForExit() }
    if (Test-Path $log) { Copy-Item -LiteralPath $log -Destination (Join-Path $artifacts "LanCoop$tag.log") -Force }
}
