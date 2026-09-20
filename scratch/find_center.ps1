Add-Type -AssemblyName System.Drawing

$filePath = Join-Path (Get-Location) "assets\images\app_logo_v2.png"
$bmp = New-Object System.Drawing.Bitmap($filePath)

Write-Host "Bitmap dimensions: $($bmp.Width) x $($bmp.Height)"

# Let's inspect the gear circle:
# The center of the circle can be found by finding the circular arc of the gear or the inner white disc.
# Let's find white pixels inside the gear disc (X around 200-350, Y around 150-300)
$minWhiteX = $bmp.Width; $maxWhiteX = 0; $minWhiteY = $bmp.Height; $maxWhiteY = 0
for ($y = 0; $y -lt $bmp.Height; $y++) {
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        $p = $bmp.GetPixel($x, $y)
        # Inside the lion cutout, background is white or transparent? Let's check
        if ($p.A -gt 200 -and $p.R -gt 240 -and $p.G -gt 240 -and $p.B -gt 240) {
            if ($x -lt $minWhiteX) { $minWhiteX = $x }
            if ($x -gt $maxWhiteX) { $maxWhiteX = $x }
            if ($y -lt $minWhiteY) { $minWhiteY = $y }
            if ($y -gt $maxWhiteY) { $maxWhiteY = $y }
        }
    }
}
Write-Host "White inner disc bounds: X=[$minWhiteX, $maxWhiteX], Y=[$minWhiteY, $maxWhiteY]"
Write-Host "Inner disc center: $((($minWhiteX + $maxWhiteX)/2)), $((($minWhiteY + $maxWhiteY)/2))"
Write-Host "Image center: $(($bmp.Width/2)), $(($bmp.Height/2))"

$bmp.Dispose()
