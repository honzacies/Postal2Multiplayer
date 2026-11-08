param([string]$GameDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$game = Join-Path $root 'POSTAL2Complete'
if ($GameDirectory) { $game = (Resolve-Path -LiteralPath $GameDirectory).Path }
$system = Join-Path $game 'System'
$stage = Join-Path $game 'LanCoop/Classes'
$artifacts = Join-Path $root 'artifacts'
New-Item -ItemType Directory -Force -Path $stage, $artifacts, (Join-Path $game 'LanCoopSaves'), (Join-Path $game 'LanCoopCache') | Out-Null
Copy-Item -Path (Join-Path $root 'src/LanCoop/Classes/*.uc') -Destination $stage -Force

# Start with the shipped defaults, never the user's or Nick's configuration.
$config = Get-Content -LiteralPath (Join-Path $system 'Default.ini') -Raw
$config = $config -replace '(?m)^SavePath=.*$', 'SavePath=..\LanCoopSaves'
$config = $config -replace '(?m)^CachePath=.*$', 'CachePath=..\LanCoopCache'
# No public master-server registration or web administration for local tests.
$config = $config -replace '(?m)^ServerActors=IpDrv.UdpServerUplink[^\r\n]*\r?\n', ''
$config = $config -replace '(?m)^ServerActors=UWeb.WebServer[^\r\n]*\r?\n', ''
$config = $config -replace '(?m)^StartupFullscreen=.*$', 'StartupFullscreen=False'
$config = $config -replace '(?m)^EditPackages=.*\r?\n', ''
$config = $config -replace '(?m)^\[Editor.EditorEngine\]', "[Editor.EditorEngine]`r`nEditPackages=Core`r`nEditPackages=Engine`r`nEditPackages=Editor`r`nEditPackages=IpDrv`r`nEditPackages=FPSGame`r`nEditPackages=Postal2Game`r`nEditPackages=MultiBase`r`nEditPackages=MoreGame`r`nEditPackages=MultiGame`r`nEditPackages=MultiStuff`r`nEditPackages=GameTypes`r`nEditPackages=AIPack`r`nEditPackages=AWPawns`r`nEditPackages=Shell`r`nEditPackages=LanCoop"
$config = $config -replace '(?m)^\[Engine.GameEngine\]', "[Engine.GameEngine]`r`nServerPackages=LanCoop"
$configPath = Join-Path $system 'LanCoop.ini'
Set-Content -LiteralPath $configPath -Value $config -Encoding ascii
Copy-Item -LiteralPath (Join-Path $system 'DefUser.ini') -Destination (Join-Path $system 'LanCoopUser.ini') -Force

# Only our generated package is removed, so make actually rebuilds changed code.
$package = Join-Path $system 'LanCoop.u'
if (Test-Path -LiteralPath $package) { Remove-Item -LiteralPath $package }
Push-Location $system
try {
    & .\UCC.exe make ini=LanCoop.ini userini=LanCoopUser.ini log=LanCoopBuild.log unattended
    $code = $LASTEXITCODE
    Copy-Item -LiteralPath (Join-Path $system 'LanCoopBuild.log') -Destination $artifacts -Force
    if ($code -ne 0 -or !(Test-Path -LiteralPath $package)) { throw "Build failed (exit $code). See artifacts/LanCoopBuild.log." }
    & .\UCC.exe LanCoop.LanCoopCheckCommandlet ini=LanCoop.ini userini=LanCoopUser.ini log=LanCoopCheck.log unattended
    $code = $LASTEXITCODE
    Copy-Item -LiteralPath (Join-Path $system 'LanCoopCheck.log') -Destination $artifacts -Force
    if ($code -ne 0 -or !(Select-String -LiteralPath (Join-Path $artifacts 'LanCoopCheck.log') -SimpleMatch 'CheckOk' -Quiet)) { throw 'Package load check failed.' }
    Copy-Item -LiteralPath $package -Destination $artifacts -Force
} finally { Pop-Location }
