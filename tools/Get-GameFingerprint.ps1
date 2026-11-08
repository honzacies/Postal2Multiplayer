param(
    [Parameter(Mandatory=$true)][string]$GameDirectory,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path -LiteralPath $GameDirectory).Path
$system = Join-Path $game 'System'
$names = @('Postal2.exe','Core.dll','Engine.dll','Core.u','Engine.u','FPSGame.u','Postal2Game.u','MoreGame.u','Inventory.u','GameTypes.u','MultiBase.u','MultiGame.u','MultiStuff.u','Shell.u','AIPack.u')
$files = foreach ($name in $names) {
    $path = Join-Path $system $name
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path
        [pscustomobject]@{File="System/$name"; Bytes=$item.Length; SHA256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash; Version=$item.VersionInfo.FileVersion}
    } else {
        [pscustomobject]@{File="System/$name"; Missing=$true}
    }
}
$report = [ordered]@{CapturedUtc=[DateTime]::UtcNow.ToString('o'); Description='Installation comparison only; this does not certify Steam integrity.'; Files=@($files)}
if (!$OutputPath) {
    $reports = Join-Path $game 'LanCoopReports'
    New-Item -ItemType Directory -Force -Path $reports | Out-Null
    $OutputPath = Join-Path $reports ('GameFingerprint-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Output "Fingerprint: $OutputPath"
