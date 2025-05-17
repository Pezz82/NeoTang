# Set default board if not specified
param(
    [string]$BOARD = "138k"
)

# Add OSS-CAD-Suite to PATH first
$env:PATH = "C:\Tools\oss-cad-suite\bin;$env:PATH"

# Create build directory
New-Item -ItemType Directory -Force -Path "build" | Out-Null

# Set environment variables
$env:BOARD = $BOARD
$env:DEVICE = "GW5AST-${BOARD}C"

# Use native Yosys if available, fall back to yowasp-yosys
$yosys = "yosys"
if (-not (Get-Command $yosys -ErrorAction SilentlyContinue)) {
    $yosys = "$env:USERPROFILE\AppData\Roaming\Python\Python313\Scripts\yowasp-yosys.exe"
}

# Run Yosys synthesis (single command, no semicolon)
Write-Host "Running Yosys synthesis..."
& $yosys -l build/yosys.log -c build/neotang.ys
if ($LASTEXITCODE) { throw "Yosys synthesis failed" }

# Run nextpnr
Write-Host "Running nextpnr..."
& nextpnr-gowin --json build/neotang.json --device $env:DEVICE --write build/neotang.pack
if ($LASTEXITCODE) { throw "nextpnr failed" }

# Run Gowin pack
Write-Host "Running Gowin pack..."
& gowin_pack -d $env:DEVICE -o build/neotang.fs build/neotang.pack
if ($LASTEXITCODE) { throw "Gowin pack failed" }

# Create output directories
New-Item -ItemType Directory -Force -Path "sd/cores/console${BOARD}" | Out-Null

# Compress and copy to output directory
Get-Content build/neotang.fs | Set-Content -Encoding Byte sd/cores/console${BOARD}/neogeotang.bin

Write-Host "Build completed successfully!" 