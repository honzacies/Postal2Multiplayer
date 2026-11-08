param(
    [Parameter(Mandatory=$true)][ValidateSet('Host','Client','Menu')][string]$Role,
    [string]$HostAddress = '127.0.0.1',
    [string]$GameDirectory,
    [switch]$PrepareOnly
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$game = Join-Path $root 'POSTAL2Complete'
if ($GameDirectory) { $game = (Resolve-Path -LiteralPath $GameDirectory).Path }
$system = Join-Path $game 'System'
foreach ($name in @('Postal2.exe','LanCoop.u','Default.ini','DefUser.ini')) {
    if (!(Test-Path -LiteralPath (Join-Path $system $name))) { throw "Missing $name. Run tools/Build.ps1 first." }
}
if ($HostAddress -notmatch '^[a-zA-Z0-9.:-]+$') { throw 'Enter a host name or IP address without spaces or URL options.' }
$iniName = "LanCoop$Role.ini"
$userName = "LanCoop${Role}User.ini"
$iniPath = Join-Path $system $iniName
$userPath = Join-Path $system $userName
if (!(Test-Path -LiteralPath $iniPath)) {
    # Bootstrap from the target installation, not the development machine.
    $seed = Join-Path $system 'Postal2.ini'
    if (!(Test-Path -LiteralPath $seed)) { $seed = Join-Path $system 'Default.ini' }
    $config = Get-Content -LiteralPath $seed -Raw
    $config = $config -replace '(?m)^ServerActors=IpDrv.UdpServerUplink[^\r\n]*\r?\n', ''
    $config = $config -replace '(?m)^ServerActors=UWeb.WebServer[^\r\n]*\r?\n', ''
    if ($config -notmatch '(?m)^ServerPackages=LanCoop\s*$') {
        $config = $config -replace '(?m)^\[Engine.GameEngine\]', "[Engine.GameEngine]`r`nServerPackages=LanCoop"
    }
    $config = $config -replace '(?m)^SavePath=.*$', "SavePath=..\LanCoop${Role}Saves"
    $config = $config -replace '(?m)^CachePath=.*$', "CachePath=..\LanCoop${Role}Cache"
    $config = $config -replace '(?m)^StartupFullscreen=.*$', 'StartupFullscreen=False'
    $config = $config -replace '(?m)^WindowedViewportX=.*$', 'WindowedViewportX=1024'
    $config = $config -replace '(?m)^WindowedViewportY=.*$', 'WindowedViewportY=768'
    Set-Content -LiteralPath $iniPath -Value $config -Encoding ascii
}
# The stock shell switches any smaller window to 1024x768, then restores it
# from a render callback during network travel, which crashes D3D. Preserve
# larger user resolutions and fullscreen preferences on subsequent launches.
$config = Get-Content -LiteralPath $iniPath -Raw
$config = [regex]::Replace($config, '(?m)^(WindowedViewportX|MenuViewportX)=(\d+)', { param($m) $m.Groups[1].Value + '=' + [Math]::Max(1024, [int]$m.Groups[2].Value) })
$config = [regex]::Replace($config, '(?m)^(WindowedViewportY|MenuViewportY)=(\d+)', { param($m) $m.Groups[1].Value + '=' + [Math]::Max(768, [int]$m.Groups[2].Value) })
$config = $config -replace '(?m)^BaseMenu=.*$', 'BaseMenu=LanCoop.LanCoopRootWindow'
Set-Content -LiteralPath $iniPath -Value $config -Encoding ascii
if (!(Test-Path -LiteralPath $userPath)) {
    $userSeed = Join-Path $system 'User.ini'
    if (!(Test-Path -LiteralPath $userSeed)) { $userSeed = Join-Path $system 'DefUser.ini' }
    Copy-Item -LiteralPath $userSeed -Destination $userPath
}
$identityPath = Join-Path $system "LanCoop${Role}Identity.txt"
if (!(Test-Path -LiteralPath $identityPath)) { [guid]::NewGuid().ToString('N') | Set-Content -LiteralPath $identityPath -Encoding ascii }
$clientId = (Get-Content -LiteralPath $identityPath -Raw).Trim()
if ($clientId -notmatch '^[a-zA-Z0-9-]{1,80}$') { throw 'Invalid coop identity file.' }
$settingsPath = Join-Path $system 'LanCoopSession.ini'
$settingsText = if (Test-Path -LiteralPath $settingsPath) { Get-Content -LiteralPath $settingsPath -Raw } else { '' }
function Get-CoopSetting([string]$Key, [string]$Fallback) {
    $settingMatch = [regex]::Match($settingsText, '(?im)^' + [regex]::Escape($Key) + '=(.*)$')
    if ($settingMatch.Success) { return $settingMatch.Groups[1].Value.Trim().Trim('"') }
    return $Fallback
}
$coopPort = Get-CoopSetting 'Port' '7787'
if ($coopPort -notmatch '^\d+$' -or [int]$coopPort -lt 1 -or [int]$coopPort -gt 65535) { throw 'Invalid coop port.' }
New-Item -ItemType Directory -Force -Path (Join-Path $game "LanCoop${Role}Saves"), (Join-Path $game "LanCoop${Role}Cache") | Out-Null
$url = if ($Role -eq 'Host') {
    $startMap = if ((Get-CoopSetting 'bSkipIntro' 'true') -ieq 'false') { 'intro.fuk' } else { 'suburbs-3.fuk' }
    $hostName = (Get-CoopSetting 'PlayerName' 'Dude') -replace '[^a-zA-Z0-9_-]', '_'
    $players = [Math]::Min(16, [Math]::Max(1, [int](Get-CoopSetting 'PlayerLimit' '2')))
    $spectators = [Math]::Min(16, [Math]::Max(0, [int](Get-CoopSetting 'SpectatorLimit' '2')))
    "${startMap}?Game=LanCoop.LanCoopGameInfo?listen?Port=${coopPort}?Name=${hostName}?MaxPlayers=${players}?MaxSpectators=${spectators}?CoopId=${clientId}"
} elseif ($Role -eq 'Client') {
    "${HostAddress}:${coopPort}?Name=Guest?CoopId=${clientId}"
} else {
    'Startup.fuk'
}
$arguments = @($url, "ini=$iniName", "userini=$userName", "log=LanCoop$Role.log", '-NewWindow')
Write-Output "$Role : $url"
if (!$PrepareOnly) {
    Start-Process -FilePath (Join-Path $system 'Postal2.exe') -WorkingDirectory $system -ArgumentList $arguments -WindowStyle Normal | Out-Null
}
