# Classifies a screenshot into gameplay accent colors and prints spatial maps.
# Built for headless agents that cannot view images directly.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools/analyze_png.ps1 <file>

param(
    [Parameter(Mandatory = $true)][string]$Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$full = (Resolve-Path -LiteralPath $Path).Path
$bitmap = [System.Drawing.Bitmap]::FromFile($full)
try {
    $width = $bitmap.Width
    $height = $bitmap.Height

    # --- per-pixel classification ------------------------------------------------
    $accent = New-Object 'int[,]' $width, $height   # 0 none, 1 text, 2 cyan, 3 red, 4 orange, 5 green, 6 yellow, 7 magenta
    $lum = New-Object 'double[,]' $width, $height
    $counts = @{ text = 0; cyan = 0; red = 0; orange = 0; green = 0; yellow = 0; magenta = 0; lit = 0; dark = 0 }
    $sums = @{}
    foreach ($key in $counts.Keys) { $sums[$key] = @(0.0, 0.0) }
    $names = @('', 'text', 'cyan', 'red', 'orange', 'green', 'yellow', 'magenta')

    for ($y = 0; $y -lt $height; $y += 2) {
        for ($x = 0; $x -lt $width; $x += 2) {
            $c = $bitmap.GetPixel($x, $y)
            $r = [double]$c.R / 255.0
            $g = [double]$c.G / 255.0
            $b = [double]$c.B / 255.0
            $max = [Math]::Max($r, [Math]::Max($g, $b))
            $min = [Math]::Min($r, [Math]::Min($g, $b))
            $d = $max - $min
            $l = 0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B
            $lum[$x, $y] = $l

            $key = $null
            if ($l -lt 18) {
                $key = 'dark'
            }
            elseif ($min -gt 0.74 -and $d -lt 0.16) {
                $accent[$x, $y] = 1; $key = 'text'
            }
            elseif ($b -gt 0.55 -and $g -gt 0.45 -and $r -lt 0.72 * $max -and ($b + $g) -gt 1.1 * $r) {
                $accent[$x, $y] = 2; $key = 'cyan'
            }
            elseif ($r -gt 0.62 -and $r -gt 1.35 * $g -and $r -gt 1.35 * $b) {
                # red vs orange by how much green sits between red and blue
                if ($g -gt 0.28 * $r -and $g -lt 0.72 * $r -and $b -lt 0.45 * $r) {
                    $accent[$x, $y] = 4; $key = 'orange'
                } else {
                    $accent[$x, $y] = 3; $key = 'red'
                }
            }
            elseif ($g -gt 0.62 -and $g -gt 1.25 * $r -and $g -gt 1.25 * $b) {
                $accent[$x, $y] = 5; $key = 'green'
            }
            elseif ($r -gt 0.68 -and $g -gt 0.60 -and $b -lt 0.45 * $r) {
                $accent[$x, $y] = 6; $key = 'yellow'
            }
            elseif ($r -gt 0.55 -and $b -gt 0.55 -and $g -lt 0.65 * $r) {
                $accent[$x, $y] = 7; $key = 'magenta'
            }

            if ($key -ne $null) {
                $counts[$key]++
                $sums[$key][0] += $x
                $sums[$key][1] += $y
            }
            if ($l -gt 40) { $counts.lit++ }
        }
    }

    [Console]::Out.WriteLine("file: $full  ($width x $height, sampled every 2 px)")
    foreach ($key in @('text', 'cyan', 'red', 'orange', 'green', 'yellow', 'magenta', 'lit', 'dark')) {
        $count = $counts[$key]
        if ($count -eq 0) {
            [Console]::Out.WriteLine(("{0,-9} {1,8}" -f $key, 0))
            continue
        }
        $cx = [int]($sums[$key][0] / $count)
        $cy = [int]($sums[$key][1] / $count)
        [Console]::Out.WriteLine(("{0,-9} {1,8}   centroid ({2},{3})" -f $key, $count, $cx, $cy))
    }

    # --- 8x8 luminance grid -----------------------------------------------------
    [Console]::Out.WriteLine('')
    [Console]::Out.WriteLine('8x8 region mean luminance:')
    for ($ry = 0; $ry -lt 8; $ry++) {
        $line = ''
        for ($rx = 0; $rx -lt 8; $rx++) {
            $x0 = [int]($rx * $width / 8); $x1 = [int](($rx + 1) * $width / 8)
            $y0 = [int]($ry * $height / 8); $y1 = [int](($ry + 1) * $height / 8)
            $sum = 0.0; $n = 0
            for ($y = $y0; $y -lt $y1; $y += 6) {
                for ($x = $x0; $x -lt $x1; $x += 6) {
                    $sum += $lum[$x, $y]; $n++
                }
            }
            $line += ("{0,4:N0}" -f ($sum / [Math]::Max($n, 1)))
        }
        [Console]::Out.WriteLine($line)
    }

    # --- 48x22 spatial map ------------------------------------------------------
    # Accent letters dominate; otherwise a luminance ramp shows the board.
    [Console]::Out.WriteLine('')
    [Console]::Out.WriteLine('spatial map (T text, C cyan, R red, O fire, G green, Y yellow, M magenta; ramp otherwise):')
    $cols = 48; $rows = 22
    $ramp = ' .:-=+*#%@'
    $letter = @('', 'T', 'C', 'R', 'O', 'G', 'Y', 'M')
    for ($row = 0; $row -lt $rows; $row++) {
        $line = ''
        for ($col = 0; $col -lt $cols; $col++) {
            $x0 = [int]($col * $width / $cols); $x1 = [Math]::Min([int](($col + 1) * $width / $cols) - 1, $width - 1)
            $y0 = [int]($row * $height / $rows); $y1 = [Math]::Min([int](($row + 1) * $height / $rows) - 1, $height - 1)
            $buckets = @(0, 0, 0, 0, 0, 0, 0, 0)
            $sum = 0.0; $n = 0
            for ($y = $y0; $y -le $y1; $y += 3) {
                for ($x = $x0; $x -le $x1; $x += 3) {
                    $sum += $lum[$x, $y]; $n++
                    $a = $accent[$x, $y]
                    if ($a -gt 0) { $buckets[$a]++ }
                }
            }
            $best = 0; $bestCount = 0
            for ($i = 1; $i -lt 8; $i++) {
                if ($buckets[$i] -gt $bestCount) { $bestCount = $buckets[$i]; $best = $i }
            }
            if ($best -gt 0 -and $bestCount -ge 2) {
                $line += $letter[$best]
            } else {
                $mean = $sum / [Math]::Max($n, 1)
                $index = [int]([Math]::Round(($mean / 255.0) * ($ramp.Length - 1)))
                $line += $ramp[$index]
            }
        }
        [Console]::Out.WriteLine($line)
    }
}
finally {
    $bitmap.Dispose()
}
