# Set default board if not specified
param(
    [string]$BOARD = "138k"
)

# Create build directory if it doesn't exist
New-Item -ItemType Directory -Force -Path build | Out-Null

# Set environment variables
$env:BOARD = $BOARD
$env:DEVICE = "GW5AST-${BOARD}C"

# Windows: absolute path to yowasp-yosys.exe
$YOSYS_EXE = "$env:USERPROFILE\AppData\Roaming\Python\Python313\Scripts\yowasp-yosys.exe"

# Write Yosys script
@"
# Yosys synthesis script for NeoGeo core
set scriptdir ../src/neotang
"@ | Out-File -FilePath build/neotang.ys -Encoding ASCII

# Generate file list with forward slashes
Get-ChildItem -Path src/neotang -Recurse -Include *.v,*.sv | ForEach-Object {
    $posix = $_.FullName.Replace('\', '/').Replace('C:/Users/johnp/Downloads/NeoTang-main/', '')
    "read_verilog -sv ../$posix" | Out-File -FilePath build/neotang.ys -Append -Encoding ASCII
}

# Add synthesis commands
@"

# Synthesis commands
hierarchy -top neotang_top
proc
flatten
opt
synth_gowin -top neotang_top -json neotang.json
"@ | Out-File -FilePath build/neotang.ys -Append -Encoding ASCII

# Run Yosys synthesis using the correct path
& $YOSYS_EXE -l build/yosys.log -c build/neotang.ys

# Check if Yosys succeeded
if (-not (Test-Path build/neotang.json)) {
    Write-Error "Error: Yosys synthesis failed"
    exit 1
}

# Package the design (using Windows gowin_pack)
$GOWIN_PACK = "$env:USERPROFILE\AppData\Roaming\Python\Python313\Scripts\gowin_pack.exe"
if (Test-Path $GOWIN_PACK) {
    & $GOWIN_PACK -d $env:DEVICE -o build/neotang.pack build/neotang.fs
} else {
    Write-Error "Error: gowin_pack not found at $GOWIN_PACK"
    exit 1
}

# Create output directories
New-Item -ItemType Directory -Force -Path "sd/cores/console${BOARD}" | Out-Null

# Compress and copy to output directory
Get-Content build/neotang.pack | Set-Content -Encoding Byte sd/cores/console${BOARD}/neogeotang.bin

Write-Host "Build complete for $BOARD" 