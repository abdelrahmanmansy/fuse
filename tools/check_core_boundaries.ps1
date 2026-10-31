# Core boundary check.
#
# The simulation core (src/core) must stay engine/UI free so it can run
# headless on the server, in tests and inside client prediction. This script
# greps for references that would break that contract.
#
# Usage:  powershell -ExecutionPolicy Bypass -File tools/check_core_boundaries.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$core = Join-Path $root 'src\core'

if (-not (Test-Path $core)) {
    Write-Host "core directory not found: $core" -ForegroundColor Red
    exit 1
}

# Patterns that must never appear under src/core.
$forbidden = @(
    @{ Pattern = '\bget_tree\s*\(';             Reason = 'scene tree access' },
    @{ Pattern = '\bNode3D\b';                   Reason = '3D node type' },
    @{ Pattern = '\bNode2D\b';                   Reason = '2D node type' },
    @{ Pattern = '\bControl\b';                  Reason = 'UI node type' },
    @{ Pattern = '\bInput\.';                    Reason = 'direct input polling' },
    @{ Pattern = '\bAudioStream\w*';             Reason = 'audio playback' },
    @{ Pattern = '\bpreload\("res://scenes/';    Reason = 'scene dependency' },
    @{ Pattern = '\bload\("res://scenes/';       Reason = 'scene dependency' },
    @{ Pattern = '\bOS\.get_ticks';              Reason = 'wall-clock time' },
    @{ Pattern = '\bTime\.get_ticks';            Reason = 'wall-clock time' },
    @{ Pattern = '\brandf\s*\(';                 Reason = 'unseeded randomness' },
    @{ Pattern = '\brandi\s*\(';                 Reason = 'unseeded randomness' },
    @{ Pattern = '\bawait\b';                    Reason = 'async in the tick loop' }
)

$files = Get-ChildItem -Path $core -Recurse -Filter *.gd -File
if ($files.Count -eq 0) {
    Write-Host "no core scripts found under $core" -ForegroundColor Red
    exit 1
}

$violations = 0
foreach ($file in $files) {
    $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        $lineNumber++
        # Ignore comments so documentation can mention node types freely.
        $code = $line -replace '#.*$', ''
        foreach ($rule in $forbidden) {
            if ($code -match $rule.Pattern) {
                Write-Host ("{0}:{1}: forbidden {2} -> {3}" -f $relative, $lineNumber, $rule.Reason, $line.Trim()) -ForegroundColor Red
                $violations++
            }
        }
    }
}

if ($violations -gt 0) {
    Write-Host ""
    Write-Host "$violations boundary violation(s) in src/core" -ForegroundColor Red
    exit 1
}

Write-Host ("core boundary check passed ({0} file(s))" -f $files.Count) -ForegroundColor Green
exit 0
