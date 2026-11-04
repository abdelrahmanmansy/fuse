# Prints a coarse letter map of a screenshot so a text-only agent can see layout.
# Usage: powershell -ExecutionPolicy Bypass -File tools/letter_map.ps1 <png> [step]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$Step = 20
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$full = (Resolve-Path -LiteralPath $Path).Path
$b = [System.Drawing.Bitmap]::FromFile($full)
try {
    Write-Output ("letter map {0}x{1} step={2}" -f $b.Width, $b.Height, $Step)
    Write-Output "  G=green T=tan/brown S=stone/grey B=blue W=white K=dark .=very dark +=other"
    for ($y = 0; $y -lt $b.Height; $y += $Step) {
        $line = ''
        for ($x = 0; $x -lt $b.Width; $x += $Step) {
            $c = $b.GetPixel($x, $y)
            $r = [int]$c.R; $g = [int]$c.G; $bl = [int]$c.B
            $mx = [Math]::Max($r, [Math]::Max($g, $bl))
            $mn = [Math]::Min($r, [Math]::Min($g, $bl))
            $ch = '+'
            if ($mx -lt 45) { $ch = '.' }
            elseif ($r -gt 235 -and $g -gt 235 -and $bl -gt 235) { $ch = 'W' }
            elseif (($mx - $mn) -lt 22 -and $mx -gt 95) { $ch = 'S' }
            elseif ($g -gt $r + 12 -and $g -gt $bl + 12) { $ch = 'G' }
            elseif ($bl -gt $r + 15 -and $bl -gt $g + 8) { $ch = 'B' }
            elseif ($r -gt $g + 25 -and $r -gt $bl + 45) { $ch = 'T' }
            elseif ($r -gt 150 -and $g -gt 130 -and $bl -gt 100 -and ($r - $bl) -lt 60) { $ch = 'S' }
            elseif ($r -lt 90 -and $g -lt 90 -and $bl -lt 90) { $ch = 'K' }
            $line += $ch
        }
        Write-Output $line
    }
}
finally {
    $b.Dispose()
}
