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
    $config = Get-Content -LiteralPath (Join-Path $system 'Default.ini') -Raw
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
# from a render callback during network travel, which crashes D3D. Enforce
# the shell's minimum on existing development INIs as well as new ones.
$config = Get-Content -LiteralPath $iniPath -Raw
$config = $config -replace '(?m)^(WindowedViewportX|MenuViewportX)=.*$', '${1}=1024'
$config = $config -replace '(?m)^(WindowedViewportY|MenuViewportY)=.*$', '${1}=768'
$config = $config -replace '(?m)^StartupFullscreen=.*$', 'StartupFullscreen=False'
$config = $config -replace '(?m)^BaseMenu=.*$', 'BaseMenu=LanCoop.LanCoopRootWindow'
Set-Content -LiteralPath $iniPath -Value $config -Encoding ascii
if (!(Test-Path -LiteralPath $userPath)) {
    Copy-Item -LiteralPath (Join-Path $system 'DefUser.ini') -Destination $userPath
}
New-Item -ItemType Directory -Force -Path (Join-Path $game "LanCoop${Role}Saves"), (Join-Path $game "LanCoop${Role}Cache") | Out-Null
$url = if ($Role -eq 'Host') {
    'suburbs-3.fuk?Game=LanCoop.LanCoopGameInfo?listen?Port=7787?Name=Dude'
} elseif ($Role -eq 'Client') {
    "${HostAddress}:7787?Name=Guest"
} else {
    'Startup.fuk'
}
$arguments = @($url, "ini=$iniName", "userini=$userName", "log=LanCoop$Role.log", '-windowed', '-NewWindow')
Write-Output "$Role : $url"
if (!$PrepareOnly) {
    Start-Process -FilePath (Join-Path $system 'Postal2.exe') -WorkingDirectory $system -ArgumentList $arguments -WindowStyle Normal | Out-Null
}
