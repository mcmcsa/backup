Add-Type -AssemblyName System.Drawing

$srcPath = Join-Path (Get-Location) "assets\images\app_logo_v2.png"
$src = New-Object System.Drawing.Bitmap($srcPath)

$dstSize = 512
$dst = New-Object System.Drawing.Bitmap($dstSize, $dstSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$g.Clear([System.Drawing.Color]::Transparent)

# Source bounds: X=[76, 416], Y=[62, 383]
# Content width = 340, Content height = 322
# Source Center: X = 246, Y = 222.5
# Target Center: 256, 256
# So offset: dx = 256 - 246 = 10; dy = 256 - 222.5 = 33.5 (approx 34)

# We can draw the source image shifted by (dx, dy):
$dx = 10
$dy = 34

$g.DrawImage($src, $dx, $dy, $src.Width, $src.Height)
$g.Dispose()
$src.Dispose()

$outPath = Join-Path (Get-Location) "assets\images\app_logo_centered.png"
$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$dst.Dispose()

Write-Host "Saved centered logo to $outPath"
