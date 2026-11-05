# Generate a self-signed development certificate for the LAN web preview.
#
#   powershell -ExecutionPolicy Bypass -File tools/make_cert.ps1
#
# Godot 4.7 refuses to boot unless the page is a Secure Context, so the LAN link
# must be HTTPS. The certificate is self-signed: the phone will show a warning
# once, and "Advanced -> Proceed" is expected. All current IPv4 addresses are
# added as Subject Alternative Names, so rerun this script if the PC's IP changes.

param(
    [string]$OutDir = "build/certs",
    [string]$CommonName = "FUSE Dev",
    [int]$Days = 825
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$outPath = if ([System.IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }

$candidates = @(
    (Get-Command openssl -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    (Join-Path $env:ProgramFiles "Git\usr\bin\openssl.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Git\usr\bin\openssl.exe")
)
$openssl = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $openssl) {
    throw "OpenSSL not found. Install Git for Windows (it bundles openssl.exe)."
}

New-Item -ItemType Directory -Force -Path $outPath | Out-Null

$ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
    Select-Object -ExpandProperty IPAddress -Unique)
$sanParts = @("DNS:localhost", "IP:127.0.0.1") + ($ips | ForEach-Object { "IP:$_" })

$keyPath = Join-Path $outPath "dev-key.pem"
$certPath = Join-Path $outPath "dev-cert.pem"
$san = ($sanParts | Select-Object -Unique) -join ","

& $openssl req -x509 -newkey rsa:2048 -sha256 -days $Days -nodes `
    -keyout $keyPath -out $certPath -subj "/CN=$CommonName" `
    -addext "subjectAltName=$san" -addext "extendedKeyUsage=serverAuth"
if ($LASTEXITCODE -ne 0) {
    throw "openssl failed with exit code $LASTEXITCODE"
}

Write-Host "Wrote $certPath"
Write-Host "Wrote $keyPath"
Write-Host "SANs: $san"
Write-Host ""
Write-Host "Serve it with:"
Write-Host "  node tools/serve_web.mjs --https --port 8080"
Write-Host ""
Write-Host "On the phone open (accept the self-signed warning once):"
foreach ($ip in $ips) {
    Write-Host "  https://${ip}:8080/"
}
