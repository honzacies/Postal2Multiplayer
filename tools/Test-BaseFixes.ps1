param([string]$GameDirectory)
$ErrorActionPreference = 'Stop'
if (!$GameDirectory) { $GameDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'POSTAL2Complete' }
$game = (Resolve-Path -LiteralPath $GameDirectory).Path
$system = Join-Path $game 'System'
if (!(Test-Path -LiteralPath (Join-Path $system 'UCC.exe'))) { throw 'UCC.exe is not available in this installation; engine capability audit cannot run.' }
& (Join-Path $PSScriptRoot 'Start-Instance.ps1') -Role Host -GameDirectory $game -PrepareOnly | Out-Null
Push-Location $system
try {
    & .\UCC.exe LanCoop.LanCoopBaseFixesCommandlet ini=LanCoopHost.ini userini=LanCoopHostUser.ini log=LanCoopBaseFixes.log unattended
    if ($LASTEXITCODE -ne 0 -or !(Select-String -LiteralPath 'LanCoopBaseFixes.log' -SimpleMatch 'BaseFixAuditOk' -Quiet)) {
        throw 'Base fixes capability audit failed; see System/LanCoopBaseFixes.log.'
    }
} finally { Pop-Location }
