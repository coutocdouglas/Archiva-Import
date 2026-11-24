# Gera o icone PLACEHOLDER do Archiva Import (letra "A" branca em fundo azul-petroleo).
# Para trocar pelo icone definitivo, substitua os arquivos em assets\icons com os mesmos nomes.
Add-Type -AssemblyName System.Drawing
$out = Join-Path $PSScriptRoot '..\assets\icons'
New-Item -ItemType Directory -Force -Path $out | Out-Null

function New-Icon([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([System.Drawing.Color]::FromArgb(31, 111, 120))
    $fontSize = [single]($size * 0.62)
    $font = New-Object System.Drawing.Font('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
    $rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
    $g.DrawString('A', $font, [System.Drawing.Brushes]::White, $rect, $fmt)
    $g.Dispose()
    return $bmp
}

foreach ($s in 16, 24) {
    $b = New-Icon $s
    $b.Save((Join-Path $out ("ArchivaImport_{0}i.bmp" -f $s)), [System.Drawing.Imaging.ImageFormat]::Bmp)
    $b.Dispose()
}

# .ico para o instalador
$big = New-Icon 48
$hicon = $big.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($hicon)
$fs = [System.IO.File]::Create((Join-Path $out 'archiva.ico'))
$icon.Save($fs)
$fs.Close()
$big.Dispose()
Write-Output 'ok'
