$ErrorActionPreference = 'Stop'
$taskRoot = $PSScriptRoot
curl.exe --fail --location --silent --show-error --output "$taskRoot\SHA512-SUMS.txt" 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/SHA512-SUMS.txt'
if ($LASTEXITCODE -ne 0) { throw 'Stazeni kontrolnich souctu selhalo.' }
$taskArchive = "$taskRoot\Godot_v4.7.2-stable_export_templates.tpz"
if (-not (Test-Path -LiteralPath $taskArchive)) {
    curl.exe --fail --location --retry 2 --output $taskArchive 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
    if ($LASTEXITCODE -ne 0) { throw 'Stazeni exportnich sablon selhalo.' }
}
$taskLine = Get-Content -LiteralPath "$taskRoot\SHA512-SUMS.txt" | Where-Object { $_ -match 'Godot_v4\.7\.2-stable_export_templates\.tpz$' }
if (-not $taskLine) { throw 'Kontrolni soucet nebyl nalezen.' }
$taskExpected = ($taskLine -split '\s+')[0]
$taskActual = (Get-FileHash -LiteralPath $taskArchive -Algorithm SHA512).Hash
if ($taskActual -ne $taskExpected) { throw 'SHA512 nesouhlasi.' }
Write-Output 'SHA512 souhlasi s oficialnim vydanim.'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskZip = [System.IO.Compression.ZipFile]::OpenRead($taskArchive)
try {
    New-Item -ItemType Directory -Path "$taskRoot\templates" -Force | Out-Null
    foreach ($taskName in @('windows_release_x86_64.exe','windows_debug_x86_64.exe')) {
        $taskEntry = $taskZip.GetEntry("templates/$taskName")
        if ($null -eq $taskEntry) { throw "Sablona chybi: $taskName" }
        $taskDestination = Join-Path "$taskRoot\templates" $taskName
        if (-not (Test-Path -LiteralPath $taskDestination)) {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($taskEntry,$taskDestination,$false)
        }
        Get-Item -LiteralPath $taskDestination | Select-Object Name,Length
    }
} finally { $taskZip.Dispose() }
