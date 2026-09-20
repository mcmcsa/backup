Add-Type -AssemblyName System.Drawing

$filePath = Join-Path (Get-Location) "assets\images\app_logo_v2.png"
$bmp = New-Object System.Drawing.Bitmap($filePath)

$minX = $bmp.Width
$maxX = 0
$minY = $bmp.Height
$maxY = 0

for ($y = 0; $y -lt $bmp.Height; $y++) {
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        $pixel = $bmp.GetPixel($x, $y)
        if ($pixel.A -gt 15) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

$bmp.Dispose()

$contentWidth = $maxX - $minX + 1
$contentHeight = $maxY - $minY + 1
$centerX = ($minX + $maxX) / 2.0
$centerY = ($minY + $maxY) / 2.0

Write-Output "Image size: $($bmp.Width) x $($bmp.Height)"
Write-Output "Bounds: X=[$minX, $maxX], Y=[$minY, $maxY]"
Write-Output "Content size: $contentWidth x $contentHeight"
Write-Output "Content center: ($centerX, $centerY)"
Write-Output "Offset from image center: dx=$($centerX - ($bmp.Width / 2.0)), dy=$($centerY - ($bmp.Height / 2.0))"
