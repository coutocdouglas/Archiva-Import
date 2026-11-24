# Gera os icones do Archiva Import a partir do icone do Archiva (assets\brand\icone.png).
# - ArchivaImport_16i.bmp / _24i.bmp : botao do Max
# - logo64.png                       : logo no topo da janela
# O arquivo archiva.ico (instalador) e o mesmo icone.ico do Archiva.
Add-Type -AssemblyName System.Drawing
$root = Join-Path $PSScriptRoot '..\assets'
$src = [System.Drawing.Image]::FromFile((Resolve-Path (Join-Path $root 'brand\icone.png')))

function Resize-Icon([int]$size, [double]$inset) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)
    $cx = [int]($src.Width * $inset); $cy = [int]($src.Height * $inset)
    $srcRect = New-Object System.Drawing.Rectangle($cx, $cy, ($src.Width - 2 * $cx), ($src.Height - 2 * $cy))
    $dst = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $g.DrawImage($src, $dst, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    return $bmp
}

# botao do Max: sem cantos transparentes (BMP nao tem transparencia), por isso o recorte interno
foreach ($s in 16, 24) {
    $b = Resize-Icon $s 0.12
    $flat = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($flat)
    $g.DrawImage($b, 0, 0)
    $g.Dispose()
    $flat.Save((Join-Path $root ("icons\ArchivaImport_{0}i.bmp" -f $s)), [System.Drawing.Imaging.ImageFormat]::Bmp)
    $flat.Dispose(); $b.Dispose()
}

# logo da janela: mantem os cantos arredondados (PNG com transparencia)
$l = Resize-Icon 64 0.0
$l.Save((Join-Path $root 'brand\logo64.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$l.Dispose()
$src.Dispose()
Write-Output 'ok'
