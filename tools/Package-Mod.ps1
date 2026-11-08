param([string]$BaselineGameDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$game = Join-Path $root 'POSTAL2Complete'
if ($BaselineGameDirectory) { $game = (Resolve-Path -LiteralPath $BaselineGameDirectory).Path }
# Use the exact compiled build artifact, independent of a clean target install.
$package = Join-Path $root 'artifacts/LanCoop.u'
if (!(Test-Path -LiteralPath $package)) { throw 'Build LanCoop.u before packaging.' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stage = Join-Path $root "artifacts/packages/LanCoop-test-$stamp"
$zip = "$stage.zip"
foreach ($dir in @('System','LanCoopTools','Source/LanCoop/Classes')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $stage $dir) | Out-Null
}
Copy-Item -LiteralPath $package -Destination (Join-Path $stage 'System/LanCoop.u')
foreach ($tool in @('Start-Instance.ps1','Get-GameFingerprint.ps1','Test-BaseFixes.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $tool) -Destination (Join-Path $stage "LanCoopTools/$tool")
}
Copy-Item -Path (Join-Path $root 'src/LanCoop/Classes/*.uc') -Destination (Join-Path $stage 'Source/LanCoop/Classes')
foreach ($role in @('Host','Client','Menu')) {
    $text = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0LanCoopTools\Start-Instance.ps1`" -GameDirectory `"%~dp0.`" -Role $role`r`nif errorlevel 1 pause`r`n"
    Set-Content -LiteralPath (Join-Path $stage "Start-LanCoop-$role.cmd") -Value $text -Encoding ascii
}
$fingerprintCommand = '@echo off' + "`r`n" + 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0LanCoopTools\Get-GameFingerprint.ps1" -GameDirectory "%~dp0."' + "`r`npause`r`n"
Set-Content -LiteralPath (Join-Path $stage 'Capture-Game-Fingerprint.cmd') -Value $fingerprintCommand -Encoding ascii
Copy-Item -LiteralPath (Join-Path $root 'PACKAGING-README.txt') -Destination (Join-Path $stage 'README.txt')
Copy-Item -LiteralPath (Join-Path $root 'DEBUGGING.md') -Destination (Join-Path $stage 'DEBUGGING.md')
Copy-Item -LiteralPath (Join-Path $root 'MP-FIX-AUDIT.md') -Destination (Join-Path $stage 'MP-FIX-AUDIT.md')
& (Join-Path $PSScriptRoot 'Get-GameFingerprint.ps1') -GameDirectory $game -OutputPath (Join-Path $stage 'DevelopmentBaseline.json')
$manifest = Get-ChildItem -LiteralPath $stage -File -Recurse | ForEach-Object {
    [pscustomobject]@{File=$_.FullName.Substring($stage.Length+1).Replace('\','/'); Bytes=$_.Length; SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
}
@{Format=1; BuildUtc=[DateTime]::UtcNow.ToString('o'); Files=@($manifest)} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'PackageManifest.json') -Encoding utf8
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    $entries = @($archive.Entries | Where-Object { !$_.FullName.EndsWith('/') })
    $binaryEntries = @($entries | Where-Object { $_.FullName -match '\.(exe|dll|u|utx|usx|ukx|fuk|ogg|uax)$' })
    if ($binaryEntries.Count -ne 1 -or $binaryEntries[0].FullName.Replace('\','/') -ne 'System/LanCoop.u') { throw 'Unexpected game binaries/assets in archive.' }
    foreach ($record in $manifest) {
        $entry = $entries | Where-Object { $_.FullName.Replace('\','/') -eq $record.File }
        if (!$entry -or $entry.Length -ne $record.Bytes) { throw "Archive entry mismatch: $($record.File)" }
        $stream = $entry.Open()
        try { $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)) }
        finally { $stream.Dispose() }
        if ($digest -ne $record.SHA256) { throw "Archive checksum mismatch: $($record.File)" }
    }
} finally { $archive.Dispose() }
Set-Content -LiteralPath (Join-Path $root 'artifacts/LatestPackage.txt') -Value $zip -Encoding utf8
Write-Output "Verified ZIP: $zip"
