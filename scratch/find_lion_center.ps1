Add-Type -AssemblyName System.Drawing

$filePath = Join-Path (Get-Location) "assets\images\app_logo_v2.png"
$bmp = New-Object System.Drawing.Bitmap($filePath)

# Yellow/Gold lion pixels: high R, medium-high G, lower B
$minLionX = $bmp.Width; $maxLionX = 0; $minLionY = $bmp.Height; $maxLionY = 0
for ($y = 0; $y -lt $bmp.Height; $y++) {
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        $p = $bmp.GetPixel($x, $y)
        if ($p.A -gt 50 -and $p.R -gt 200 -and $p.G -gt 150 -and $p.B -lt 80) {
            if ($x -lt $minLionX) { $minLionX = $x }
            if ($x -gt $maxLionX) { $maxLionX = $x }
            if ($y -lt $minLionY) { $minLionY = $y }
            if ($y -gt $maxLionY) { $maxLionY = $y }
        }
    }
}
Write-Host "Lion bounds: X=[$minLionX, $maxLionX], Y=[$minLionY, $maxLionY]"
Write-Host "Lion center: $((($minLionX + $maxLionX)/2)), $((($minLionY + $maxLionY)/2))"

# Blue gear bounds: high B, medium R, G
$minGearX = $bmp.Width; $maxGearX = 0; $minGearY = $bmp.Height; $maxGearY = 0
for ($y = 0; $y -lt $bmp.Height; $y++) {
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        $p = $bmp.GetPixel($x, $y)
        if ($p.A -gt 50 -and $p.B -gt 150 -and $p.R -lt 100) {
            if ($x -lt $minGearX) { $minGearX = $x }
            if ($x -gt $maxGearX) { $maxGearX = $x }
            if ($y -lt $minGearY) { $minGearY = $y }
            if ($y -gt $maxGearY) { $maxGearY = $y }
        }
    }
}
Write-Host "Blue gear bounds: X=[$minGearX, $maxGearX], Y=[$minGearY, $maxGearY]"
Write-Host "Blue gear center: $((($minGearX + $maxGearX)/2)), $((($minGearY + $maxGearY)/2))"

$bmp.Dispose()
