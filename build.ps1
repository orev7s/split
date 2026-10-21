$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root "module"
$zipOut = Join-Path $root "Split-Module-v1.0.0.zip"

function Convert-ToLf([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $out = New-Object System.Collections.Generic.List[byte]
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 13 -and ($i + 1) -lt $bytes.Length -and $bytes[$i + 1] -eq 10) { continue }
        $out.Add($bytes[$i])
    }
    [System.IO.File]::WriteAllBytes($path, $out.ToArray())
}

Get-ChildItem $src -Recurse -File | Where-Object {
    $_.Extension -in @(".sh", ".prop") -or $_.Name -in @("splitctl", "update-binary", "updater-script")
} | ForEach-Object { Convert-ToLf $_.FullName }

if (Test-Path $zipOut) { Remove-Item $zipOut -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($zipOut, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem $src -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($src.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $zip.Dispose()
}

Write-Output "built $zipOut"
$z = [System.IO.Compression.ZipFile]::OpenRead($zipOut)
$z.Entries | ForEach-Object { "  " + $_.FullName + "  " + $_.Length }
$z.Dispose()
