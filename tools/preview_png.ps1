# Renders a PNG as a coarse luminance map plus basic stats.
# Useful on machines/agents that cannot open images directly.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools/preview_png.ps1 <file> [cols] [rows]

param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$Columns = 100,
    [int]$Rows = 46
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$full = (Resolve-Path -LiteralPath $Path).Path
$bitmap = [System.Drawing.Bitmap]::FromFile($full)
try {
    $width = $bitmap.Width
    $height = $bitmap.Height
    $cellW = [Math]::Max(1, [int]($width / $Columns))
    $cellH = [Math]::Max(1, [int]($height / $Rows))

    $ramp = ' .:-=+*#%@'
    $lines = New-Object System.Collections.Generic.List[string]
    $totalLum = 0.0
    $samples = 0
    $bright = 0
    $nonBg = 0

    for ($row = 0; $row -lt $Rows; $row++) {
        $line = ''
        for ($col = 0; $col -lt $Columns; $col++) {
            $sum = 0.0
            $count = 0
            $x0 = $col * $cellW
            $y0 = $row * $cellH
            for ($y = $y0; $y -lt [Math]::Min($y0 + $cellH, $height); $y += 2) {
                for ($x = $x0; $x -lt [Math]::Min($x0 + $cellW, $width); $x += 2) {
                    $c = $bitmap.GetPixel($x, $y)
                    $sum += (0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B)
                    $count++
                }
            }
            if ($count -eq 0) { $count = 1 }
            $lum = $sum / $count
            $totalLum += $lum * $count
            $samples += $count
            if ($lum -gt 200) { $bright++ }
            if ($lum -gt 12) { $nonBg++ }
            $index = [int]([Math]::Round(($lum / 255.0) * ($ramp.Length - 1)))
            $line += $ramp[$index]
        }
        $lines.Add($line)
    }

    $mean = $totalLum / [Math]::Max($samples, 1)
    [Console]::Out.WriteLine("file: $full")
    [Console]::Out.WriteLine(("{0}x{1}  mean luminance {2:N1}  bright cells {3}/{4}  non-background cells {5}/{4}" -f $width, $height, $mean, $bright, ($Columns * $Rows), $nonBg))
    [Console]::Out.WriteLine('')
    foreach ($line in $lines) { [Console]::Out.WriteLine($line) }
}
finally {
    $bitmap.Dispose()
}
