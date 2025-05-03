# Build script for NeoGeo core on Tang 138K using Gowin IDE
# Usage: .\build_gowin.ps1

# Error handling
$ErrorActionPreference = "Stop"

# Add Yosys to PATH
$env:Path += ";C:\Users\johnp\Downloads\toolchain-yosys-windows_x86-2019.12.11.tar\toolchain-yosys-windows_x86-2019.12.11\bin"

# Check if BOARD is set
if (-not $env:BOARD) {
    Write-Error "Error: BOARD environment variable not set"
    Write-Error "Usage: $env:BOARD='60k' .\build_gowin.ps1 or $env:BOARD='138k' .\build_gowin.ps1"
    exit 1
}

# Map board to device
switch ($env:BOARD) {
    "60k" { $DEVICE = "GW5AST-60C" }
    "138k" { $DEVICE = "GW5AST-138C" }
    default {
        Write-Error "Error: Invalid BOARD value. Must be '60k' or '138k'"
        exit 1
    }
}

# Color codes for output formatting
$RED = [System.ConsoleColor]::Red
$GREEN = [System.ConsoleColor]::Green
$YELLOW = [System.ConsoleColor]::Yellow
$BLUE = [System.ConsoleColor]::Blue

# Function to check if a file exists
function Check-FileExists {
    param (
        [string]$file,
        [string]$message
    )
    if (-not (Test-Path $file)) {
        Write-Host $message -ForegroundColor $RED
        exit 1
    }
}

# Function to check if a directory exists
function Check-DirExists {
    param (
        [string]$dir,
        [string]$message
    )
    if (-not (Test-Path $dir)) {
        Write-Host $message -ForegroundColor $RED
        exit 1
    }
}

# Check for required tools
Write-Host "Checking for required tools..." -ForegroundColor $BLUE
if (-not (Get-Command "yosys" -ErrorAction SilentlyContinue)) {
    Write-Error "Error: yosys is required but not installed"
    exit 1
}
if (-not (Get-Command "gw_sh" -ErrorAction SilentlyContinue)) {
    Write-Error "Error: gw_sh is required but not installed"
    exit 1
}

# Create build directory
Write-Host "Creating build directory..." -ForegroundColor $BLUE
New-Item -ItemType Directory -Force -Path "build" | Out-Null
Set-Location build

# Source directories
$SRC_DIR = "..\src\neotang"
$MISTER_DIR = "$SRC_DIR\mister_ng"
$CONSTRAINTS_DIR = "..\constraints"

# Check if source directories exist
Check-DirExists $SRC_DIR "Source directory not found: $SRC_DIR"
Check-DirExists $MISTER_DIR "MiSTer directory not found: $MISTER_DIR"

# Create constraints directory if it doesn't exist
Write-Host "Setting up constraint files..." -ForegroundColor $BLUE
New-Item -ItemType Directory -Force -Path $CONSTRAINTS_DIR | Out-Null

# Copy constraint files if they don't exist in constraints directory
if (-not (Test-Path "$CONSTRAINTS_DIR\neotang_138k.pcf")) {
    Check-FileExists "$SRC_DIR\neotang_138k.cst" "Constraint file not found: $SRC_DIR\neotang_138k.cst"
    Copy-Item "$SRC_DIR\neotang_138k.cst" "$CONSTRAINTS_DIR\neotang_138k.pcf"
    Write-Host "Copied CST to PCF constraint file" -ForegroundColor $GREEN
}

if (-not (Test-Path "$CONSTRAINTS_DIR\neotang.sdc")) {
    Check-FileExists "$SRC_DIR\neotang_138k.sdc" "SDC file not found: $SRC_DIR\neotang_138k.sdc"
    Copy-Item "$SRC_DIR\neotang_138k.sdc" "$CONSTRAINTS_DIR\neotang.sdc"
    Write-Host "Copied SDC timing constraint file" -ForegroundColor $GREEN
}

# List of source files
Write-Host "Collecting source files..." -ForegroundColor $BLUE
$SOURCE_FILES = @(
    # Top-level files
    "$SRC_DIR\neotang_top.sv"
    "$SRC_DIR\mister_ng_top.sv"
    
    # Memory interface
    "$SRC_DIR\sdram_controller_dual.sv"
    "$SRC_DIR\memory_map.sv"
    "$SRC_DIR\rom_loader.sv"
    
    # Video and audio
    "$SRC_DIR\video_scaler.sv"
    "$SRC_DIR\hdmi_output.sv"
    "$SRC_DIR\hdmi_audio_integration.sv"
    
    # Clock generation
    "$SRC_DIR\pll_instantiation.sv"
    
    # I/O system
    "$SRC_DIR\iosys_bl616.sv"
    
    # MiSTer NeoGeo core files
    (Get-ChildItem -Path $MISTER_DIR -Recurse -Include "*.v","*.sv","*.vh" | Where-Object { $_.FullName -notmatch "ip_stubs" }).FullName
    
    # IP stubs for Quartus primitives
    "$MISTER_DIR\ip_stubs\altsyncram.v"
    "$MISTER_DIR\ip_stubs\altera_pll.v"
    "$MISTER_DIR\ip_stubs\altpll.v"
)

# Check if all source files exist
foreach ($file in $SOURCE_FILES) {
    Check-FileExists $file "Source file not found: $file"
}

Write-Host "Found $($SOURCE_FILES.Count) source files" -ForegroundColor $GREEN

# Create Yosys script
Write-Host "Creating Yosys synthesis script..." -ForegroundColor $BLUE
$yosysScript = @"
# Yosys synthesis script for NeoGeo core
"@

foreach ($file in $SOURCE_FILES) {
    $yosysScript += "read_verilog -sv `"$file`"`n"
}

$yosysScript += @"
hierarchy -top neotang_top
proc
flatten
opt
synth_gowin -top neotang_top -json neotang.json
"@

Set-Content -Path "neotang.ys" -Value $yosysScript

# Run Yosys for synthesis
Write-Host "Running Yosys for synthesis..." -ForegroundColor $BLUE
yosys -l yosys.log neotang.ys
if ($LASTEXITCODE -ne 0) {
    Write-Host "Yosys synthesis failed" -ForegroundColor $RED
    Get-Content -Tail 10 yosys.log
    exit 1
}
Write-Host "Synthesis completed successfully" -ForegroundColor $GREEN

# Create Gowin project file
Write-Host "Creating Gowin project file..." -ForegroundColor $BLUE
$gowinProject = @"
<?xml version="1.0" encoding="UTF-8"?>
<Project>
    <File>
        <FileInfo>
            <FileName>neotang.json</FileName>
            <FileType>JSON</FileType>
            <FileVersion>1.0</FileVersion>
        </FileInfo>
    </File>
    <File>
        <FileInfo>
            <FileName>$CONSTRAINTS_DIR\neotang_138k.pcf</FileName>
            <FileType>PCF</FileType>
            <FileVersion>1.0</FileVersion>
        </FileInfo>
    </File>
    <File>
        <FileInfo>
            <FileName>$CONSTRAINTS_DIR\neotang.sdc</FileName>
            <FileType>SDC</FileType>
            <FileVersion>1.0</FileVersion>
        </FileInfo>
    </File>
    <ProjectInfo>
        <Device>$DEVICE</Device>
        <Timing>
            <TimingFile>$CONSTRAINTS_DIR\neotang.sdc</TimingFile>
        </Timing>
    </ProjectInfo>
</Project>
"@

Set-Content -Path "neotang.gprj" -Value $gowinProject

# Run Gowin IDE for place and route
Write-Host "Running Gowin IDE for place and route..." -ForegroundColor $BLUE
gw_ide -p neotang.gprj -t "Place & Route" -o neotang_pnr.json
if ($LASTEXITCODE -ne 0) {
    Write-Host "Gowin IDE place and route failed" -ForegroundColor $RED
    exit 1
}
Write-Host "Place and route completed successfully" -ForegroundColor $GREEN

# Run Gowin pack to generate bitstream
Write-Host "Running Gowin pack to generate bitstream..." -ForegroundColor $BLUE
gw_sh -d $DEVICE -o neotang.bin neotang_pnr.json > gowin_pack.log 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "gw_sh bitstream generation failed" -ForegroundColor $RED
    Get-Content -Tail 10 gowin_pack.log
    exit 1
}

# Check if bitstream was generated
Check-FileExists "neotang.bin" "Bitstream file was not generated"

Write-Host "Build completed successfully!" -ForegroundColor $GREEN
Write-Host "Bitstream is available at: $(Get-Location)\neotang.bin" -ForegroundColor $GREEN
Write-Host "Build statistics:" -ForegroundColor $BLUE
Write-Host "  - Source files: $($SOURCE_FILES.Count)" 