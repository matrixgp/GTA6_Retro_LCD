Add-Type -AssemblyName System.Drawing
foreach ($pose in @('lower','upper')) {
    $image = [System.Drawing.Bitmap]::FromFile("D:\Codex\GTA6_Retro_LCD\assets\graphics\player_reference_$pose.png")
    Write-Output "$pose $($image.Width)x$($image.Height)"
    $rows = if ($pose -eq 'lower') { @(730,750,770,790,810,830,850) } else { @(290,310,330,350,370,390,410) }
    foreach ($row in $rows) {
        $runs = @()
        $runStart = -1
        for ($x = 750; $x -le 1240; $x++) {
            $opaque = $image.GetPixel($x,$row).A -ge 128
            if ($opaque -and $runStart -lt 0) { $runStart = $x }
            if (-not $opaque -and $runStart -ge 0) { $runs += "$runStart-$($x-1)"; $runStart = -1 }
        }
        if ($runStart -ge 0) { $runs += "$runStart-1240" }
        Write-Output "$row : $($runs -join ', ')"
    }
    $image.Dispose()
}
