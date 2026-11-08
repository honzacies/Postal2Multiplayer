param([string]$UccToolDirectory, [string]$ModPackagePath)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$game = Join-Path $root 'POSTAL2Complete'
$sourceSystem = Join-Path $game 'System'
$auditRoot = Join-Path $root ('artifacts/NoNicksCoop-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$system = Join-Path $auditRoot 'System'
New-Item -ItemType Directory -Force -Path $system | Out-Null
# A separate loader directory: no renames/deletes of the user's installed mod.
$files = Get-ChildItem -LiteralPath $sourceSystem -File | Where-Object {
    ($_.Extension -in @('.u','.dll','.int') -or $_.Name -in @('UCC.exe','Postal2.exe','Default.ini','DefUser.ini')) -and
        $_.Name -notmatch '(?i)NicksCoop|Postal2CoOp'
}
foreach ($file in $files) { Copy-Item -LiteralPath $file.FullName -Destination $system }
if ($ModPackagePath) {
    Copy-Item -LiteralPath $ModPackagePath -Destination (Join-Path $system 'LanCoop.u') -Force
}
if (!(Test-Path -LiteralPath (Join-Path $system 'UCC.exe'))) {
    if (!$UccToolDirectory) { throw 'UCC.exe missing; specify an existing tool directory for the isolated audit.' }
    $tool = Join-Path $UccToolDirectory 'UCC.exe'
    if (!(Test-Path -LiteralPath $tool)) { throw 'Specified UCC tool is missing.' }
    Copy-Item -LiteralPath $tool -Destination (Join-Path $system 'UCC.exe')
    @{Tool='UCC.exe'; Source=$tool; SHA256=(Get-FileHash -LiteralPath $tool).Hash; InstalledInGame=$false} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $auditRoot 'AuditTool.json')
}
$config = Get-Content -LiteralPath (Join-Path $sourceSystem 'Default.ini') -Raw
if ($config -match '(?im)^(ServerActors|ServerPackages|GameEngine|DefaultGame|DefaultServerGame|BaseMenu)=.*(NicksCoop|Postal2CoOp)') {
    throw 'Source defaults explicitly enable the old coop; use clean defaults for the isolation audit.'
}
$config = $config -replace '(?m)^Paths=.*\r?\n', ''
$assetPaths = foreach ($line in Get-Content -LiteralPath (Join-Path $sourceSystem 'Default.ini')) {
    if ($line.StartsWith('Paths=')) {
        $path = $line.Substring(6)
        if ($path -notmatch '(?i)\.u$') { 'Paths=' + [IO.Path]::GetFullPath((Join-Path $sourceSystem $path)) }
    }
}
$config = $config -replace '(?m)^\[Core.System\]', ("[Core.System]`r`nPaths=..\System\*.u`r`n" + ($assetPaths -join "`r`n"))
$config = $config -replace '(?m)^SavePath=.*$', 'SavePath=..\AuditSaves'
$config = $config -replace '(?m)^CachePath=.*$', 'CachePath=..\AuditCache'
$config = $config -replace '(?m)^ServerActors=IpDrv.UdpServerUplink[^\r\n]*\r?\n', ''
$config = $config -replace '(?m)^ServerActors=UWeb.WebServer[^\r\n]*\r?\n', ''
$config = $config -replace '(?m)^\[Engine.GameEngine\]', "[Engine.GameEngine]`r`nServerPackages=LanCoop"
New-Item -ItemType Directory -Force -Path (Join-Path $auditRoot 'AuditSaves'),(Join-Path $auditRoot 'AuditCache') | Out-Null
Set-Content -LiteralPath (Join-Path $system 'LanCoopAudit.ini') -Value $config -Encoding ascii
Copy-Item -LiteralPath (Join-Path $sourceSystem 'DefUser.ini') -Destination (Join-Path $system 'LanCoopAuditUser.ini')
$files | Select-Object Name,Length | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $auditRoot 'SystemFileInventory.json') -Encoding utf8
$server = $null
Push-Location $system
try {
    & .\UCC.exe LanCoop.LanCoopBaseFixesCommandlet ini=LanCoopAudit.ini userini=LanCoopAuditUser.ini log=BaseFixes.log unattended
    if ($LASTEXITCODE -ne 0 -or !(Select-String -LiteralPath 'BaseFixes.log' -SimpleMatch 'BaseFixAuditOk' -Quiet)) { throw 'Base fixes missing or old coop package loaded.' }
    $stdout = Join-Path $auditRoot 'Lifecycle.stdout.txt'
    $server = Start-Process -FilePath (Join-Path $system 'UCC.exe') -WorkingDirectory $system -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError (Join-Path $auditRoot 'Lifecycle.stderr.txt') -ArgumentList @('server','suburbs-3.fuk?Game=LanCoop.LanCoopGameInfo?Port=7799?LifecycleProbe=1','ini=LanCoopAudit.ini','userini=LanCoopAuditUser.ini','log=Lifecycle.log','unattended')
    $deadline = (Get-Date).AddSeconds(45)
    $passed = $false
    while ((Get-Date) -lt $deadline) {
        if ($server.HasExited) { throw 'Isolated server exited early.' }
        if (Select-String -LiteralPath $stdout -Pattern 'LifecycleFailed|Critical:' -Quiet) { throw 'Isolated lifecycle test failed.' }
        if (Select-String -LiteralPath $stdout -SimpleMatch 'LifecycleOk' -Quiet) { $passed=$true; break }
        Start-Sleep -Milliseconds 250
    }
    if (!$passed) { throw 'Isolated lifecycle test timed out.' }
    if (Get-ChildItem -LiteralPath $system -File | Where-Object {$_.Name -match '(?i)NicksCoop|Postal2CoOp'}) { throw 'Excluded mod file appeared in isolation directory.' }
    'NoNicksCoopAudit Passed=true PackageUnavailable=true LifecyclePassed=true' | Set-Content -LiteralPath (Join-Path $auditRoot 'Result.txt')
    Set-Content -LiteralPath (Join-Path $root 'artifacts/LatestNoNicksCoopAudit.txt') -Value $auditRoot
    Write-Output "Isolated audit passed: $auditRoot"
} finally {
    if ($server -and !$server.HasExited) { Stop-Process -Id $server.Id -Force; $server.WaitForExit() }
    Pop-Location
}
