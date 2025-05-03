# Build script for NeoGeo core on Tang 138K using open-source toolchain (Yosys + nextpnr)
# Usage: .\build_opensource.ps1

# Error handling
$ErrorActionPreference = "Stop"

# Add Python Scripts to PATH
$env:Path += ";C:\Users\johnp\AppData\Roaming\Python\Python313\Scripts"

# Check if BOARD is set
if (-not $env:BOARD) {
    Write-Error "Error: BOARD environment variable not set"
    Write-Error "Usage: $env:BOARD='60k' .\build_opensource.ps1 or $env:BOARD='138k' .\build_opensource.ps1"
    exit 1
}

# Map board to device
switch ($env:BOARD) {
    "60k" { 
        $DEVICE = "GW5AST-60C"
        $DEVICE_PACKAGE = "PBGA484"
    }
    "138k" { 
        $DEVICE = "GW5AST-138C"
        $DEVICE_PACKAGE = "PBGA484"
    }
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
if (-not (Get-Command "yowasp-yosys" -ErrorAction SilentlyContinue)) {
    Write-Error "Error: yowasp-yosys is required but not installed"
    Write-Error "Please install it using: pip install yowasp-yosys"
    exit 1
}
if (-not (Get-Command "yowasp-nextpnr-gowin" -ErrorAction SilentlyContinue)) {
    Write-Error "Error: yowasp-nextpnr-gowin is required but not installed"
    Write-Error "Please install it using: pip install yowasp-nextpnr-gowin"
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

# List of source files
Write-Host "Collecting source files..." -ForegroundColor $BLUE
$SOURCE_FILES = @(
    # Gowin PLL primitives
    "$MISTER_DIR\ip_stubs\gowin_pll.v",
    
    # Clock generation
    "$SRC_DIR\pll_modules.sv",
    "$SRC_DIR\pll_hdmi_x5.sv",
    "$SRC_DIR\pll_instantiation.sv",
    
    # Memory interface
    "$SRC_DIR\memory_map.sv",
    "$SRC_DIR\sdram_controller.sv",
    "$SRC_DIR\sdram_controller_dual.sv",
    "$SRC_DIR\rom_loader.sv",
    
    # Video and audio
    "$SRC_DIR\video_scaler.sv",
    "$SRC_DIR\hdmi_output.sv",
    "$SRC_DIR\hdmi_audio_integration.sv",
    "$SRC_DIR\audio_i2s.sv",
    "$SRC_DIR\audio_processor.sv",
    "$SRC_DIR\osd_overlay.sv",
    
    # I/O system
    "$SRC_DIR\iosys_bl616.sv",
    "$SRC_DIR\input_adapter.sv",
    
    # Placeholder modules
    "$SRC_DIR\placeholder_modules.sv",
    
    # IP stubs
    "$MISTER_DIR\ip_stubs\altsyncram.v",
    "$MISTER_DIR\ip_stubs\altera_pll.v",
    "$MISTER_DIR\ip_stubs\altpll.v",
    
    # Memory modules
    "$MISTER_DIR\mem\dpram.v",
    "$MISTER_DIR\mem\backup.v",
    "$MISTER_DIR\mem\memcard.v",
    "$MISTER_DIR\mem\ddram.sv",
    "$MISTER_DIR\mem\sdram.sv",
    "$MISTER_DIR\mem\sdram_mux.sv",
    
    # Video modules
    "$MISTER_DIR\video\autoanim.v",
    "$MISTER_DIR\video\fast_cycle.v",
    "$MISTER_DIR\video\hshrink.v",
    "$MISTER_DIR\video\irq.v",
    "$MISTER_DIR\video\linebuffer.v",
    "$MISTER_DIR\video\lspc2_a2.v",
    "$MISTER_DIR\video\lspc2_clk.v",
    "$MISTER_DIR\video\lspc_regs.v",
    "$MISTER_DIR\video\lspc_timer.v",
    "$MISTER_DIR\video\neo_273.v",
    "$MISTER_DIR\video\neo_b1.v",
    "$MISTER_DIR\video\neo_cmc.v",
    "$MISTER_DIR\video\slow_cycle.v",
    "$MISTER_DIR\video\videosync.v",
    "$MISTER_DIR\video\zmc2_dot.v",
    
    # I/O modules
    "$MISTER_DIR\io\c1_inputs.v",
    "$MISTER_DIR\io\c1_regs.v",
    "$MISTER_DIR\io\c1_wait.v",
    "$MISTER_DIR\io\clocks.v",
    "$MISTER_DIR\io\com.v",
    "$MISTER_DIR\io\neo_c1.v",
    "$MISTER_DIR\io\neo_d0.v",
    "$MISTER_DIR\io\neo_e0.v",
    "$MISTER_DIR\io\neo_f0.v",
    "$MISTER_DIR\io\neo_g0.v",
    "$MISTER_DIR\io\neo_pvc.v",
    "$MISTER_DIR\io\neo_sma.sv",
    "$MISTER_DIR\io\pcm.v",
    "$MISTER_DIR\io\register.v",
    "$MISTER_DIR\io\resetp.v",
    "$MISTER_DIR\io\syslatch.v",
    "$MISTER_DIR\io\upd4990.v",
    "$MISTER_DIR\io\watchdog.v",
    "$MISTER_DIR\io\z80ctrl.v",
    "$MISTER_DIR\io\zmc.v",
    
    # CPU modules
    "$MISTER_DIR\cpu\cpu_68k.v",
    "$MISTER_DIR\cpu\cpu_z80.v",
    "$MISTER_DIR\cpu\FX68K\fx68k.sv",
    "$MISTER_DIR\cpu\FX68K\fx68kAlu.sv",
    "$MISTER_DIR\cpu\FX68K\uaddrPla.sv",
    
    # Cell modules
    "$MISTER_DIR\cells\bd3.v",
    "$MISTER_DIR\cells\C43.v",
    "$MISTER_DIR\cells\fdm.v",
    "$MISTER_DIR\cells\fds.v",
    "$MISTER_DIR\cells\fds16bit.v",
    "$MISTER_DIR\cells\lt4.v",
    
    # JT12 modules
    "$MISTER_DIR\jt12\hdl\jt12.v",
    "$MISTER_DIR\jt12\hdl\jt12_acc.v",
    "$MISTER_DIR\jt12\hdl\jt12_csr.v",
    "$MISTER_DIR\jt12\hdl\jt12_div.v",
    "$MISTER_DIR\jt12\hdl\jt12_dout.v",
    "$MISTER_DIR\jt12\hdl\jt12_eg.v",
    "$MISTER_DIR\jt12\hdl\jt12_eg_cnt.v",
    "$MISTER_DIR\jt12\hdl\jt12_eg_comb.v",
    "$MISTER_DIR\jt12\hdl\jt12_eg_ctrl.v",
    "$MISTER_DIR\jt12\hdl\jt12_eg_final.v",
    "$MISTER_DIR\jt12\hdl\jt12_eg_pure.v",
    "$MISTER_DIR\jt12\hdl\jt12_eg_step.v",
    "$MISTER_DIR\jt12\hdl\jt12_exprom.v",
    "$MISTER_DIR\jt12\hdl\jt12_kon.v",
    "$MISTER_DIR\jt12\hdl\jt12_lfo.v",
    "$MISTER_DIR\jt12\hdl\jt12_logsin.v",
    "$MISTER_DIR\jt12\hdl\jt12_mmr.v",
    "$MISTER_DIR\jt12\hdl\jt12_mmr_sim.vh",
    "$MISTER_DIR\jt12\hdl\jt12_mod.v",
    "$MISTER_DIR\jt12\hdl\jt12_op.v",
    "$MISTER_DIR\jt12\hdl\jt12_pcm.v",
    "$MISTER_DIR\jt12\hdl\jt12_pcm_interpol.v",
    "$MISTER_DIR\jt12\hdl\jt12_pg.v",
    "$MISTER_DIR\jt12\hdl\jt12_pg_comb.v",
    "$MISTER_DIR\jt12\hdl\jt12_pg_dt.v",
    "$MISTER_DIR\jt12\hdl\jt12_pg_inc.v",
    "$MISTER_DIR\jt12\hdl\jt12_pg_sum.v",
    "$MISTER_DIR\jt12\hdl\jt12_pm.v",
    "$MISTER_DIR\jt12\hdl\jt12_reg.v",
    "$MISTER_DIR\jt12\hdl\jt12_reg_ch.v",
    "$MISTER_DIR\jt12\hdl\jt12_rst.v",
    "$MISTER_DIR\jt12\hdl\jt12_sh.v",
    "$MISTER_DIR\jt12\hdl\jt12_sh24.v",
    "$MISTER_DIR\jt12\hdl\jt12_sh_rst.v",
    "$MISTER_DIR\jt12\hdl\jt12_single_acc.v",
    "$MISTER_DIR\jt12\hdl\jt12_sumch.v",
    "$MISTER_DIR\jt12\hdl\jt12_timers.v",
    "$MISTER_DIR\jt12\hdl\jt12_top.v",
    
    # JT49 modules
    "$MISTER_DIR\jt49\hdl\jt49.v",
    "$MISTER_DIR\jt49\hdl\jt49_bus.v",
    "$MISTER_DIR\jt49\hdl\jt49_cen.v",
    "$MISTER_DIR\jt49\hdl\jt49_div.v",
    "$MISTER_DIR\jt49\hdl\jt49_eg.v",
    "$MISTER_DIR\jt49\hdl\jt49_exp.v",
    "$MISTER_DIR\jt49\hdl\jt49_noise.v",
    "$MISTER_DIR\jt49\hdl\filter\jt49_dcrm.v",
    "$MISTER_DIR\jt49\hdl\filter\jt49_dcrm2.v",
    "$MISTER_DIR\jt49\hdl\filter\jt49_dly.v",
    "$MISTER_DIR\jt49\hdl\filter\jt49_mave.v",
    
    # CD modules
    "$MISTER_DIR\cd\cd.sv",
    "$MISTER_DIR\cd\cdda.v",
    "$MISTER_DIR\cd\drive.v",
    "$MISTER_DIR\cd\hps_ext.v",
    "$MISTER_DIR\cd\lc8951.v",
    
    # PLL modules
    "$MISTER_DIR\pll\pll_0002.v",
    "$MISTER_DIR\pll.v",
    
    # Core modules
    "$MISTER_DIR\neogeo.sv",
    "$SRC_DIR\mister_ng_top.sv",
    
    # Top-level module
    "$SRC_DIR\neotang_top.sv"
)

# Check if all source files exist
foreach ($file in $SOURCE_FILES) {
    Check-FileExists $file "Source file not found: $file"
}

Write-Host "Found $($SOURCE_FILES.Count) source files" -ForegroundColor $GREEN

# Create Yosys script
Write-Host "Creating Yosys synthesis script..." -ForegroundColor $BLUE
$YOSYS_SCRIPT = @"
# Yosys synthesis script for NeoGeo core
read_verilog -sv "..\src\neotang\mister_ng\ip_stubs\gowin_pll.v"
read_verilog -sv "..\src\neotang\pll_modules.sv"
read_verilog -sv "..\src\neotang\pll_hdmi_x5.sv"
read_verilog -sv "..\src\neotang\pll_instantiation.sv"
read_verilog -sv "..\src\neotang\memory_map.sv"
read_verilog -sv "..\src\neotang\sdram_controller.sv"
read_verilog -sv "..\src\neotang\sdram_controller_dual.sv"
read_verilog -sv "..\src\neotang\rom_loader.sv"
read_verilog -sv "..\src\neotang\video_scaler.sv"
read_verilog -sv "..\src\neotang\hdmi_output.sv"
read_verilog -sv "..\src\neotang\hdmi_audio_integration.sv"
read_verilog -sv "..\src\neotang\audio_i2s.sv"
read_verilog -sv "..\src\neotang\audio_processor.sv"
read_verilog -sv "..\src\neotang\osd_overlay.sv"
read_verilog -sv "..\src\neotang\iosys_bl616.sv"
read_verilog -sv "..\src\neotang\input_adapter.sv"
read_verilog -sv "..\src\neotang\placeholder_modules.sv"
read_verilog -sv "..\src\neotang\mister_ng\ip_stubs\altsyncram.v"
read_verilog -sv "..\src\neotang\mister_ng\ip_stubs\altera_pll.v"
read_verilog -sv "..\src\neotang\mister_ng\ip_stubs\altpll.v"
read_verilog -sv "..\src\neotang\mister_ng\mem\dpram.v"
read_verilog -sv "..\src\neotang\mister_ng\mem\backup.v"
read_verilog -sv "..\src\neotang\mister_ng\mem\memcard.v"
read_verilog -sv "..\src\neotang\mister_ng\mem\ddram.sv"
read_verilog -sv "..\src\neotang\mister_ng\mem\sdram.sv"
read_verilog -sv "..\src\neotang\mister_ng\mem\sdram_mux.sv"
read_verilog -sv "..\src\neotang\mister_ng\video\autoanim.v"
read_verilog -sv "..\src\neotang\mister_ng\video\fast_cycle.v"
read_verilog -sv "..\src\neotang\mister_ng\video\hshrink.v"
read_verilog -sv "..\src\neotang\mister_ng\video\irq.v"
read_verilog -sv "..\src\neotang\mister_ng\video\linebuffer.v"
read_verilog -sv "..\src\neotang\mister_ng\video\lspc2_a2.v"
read_verilog -sv "..\src\neotang\mister_ng\video\lspc2_clk.v"
read_verilog -sv "..\src\neotang\mister_ng\video\lspc_regs.v"
read_verilog -sv "..\src\neotang\mister_ng\video\lspc_timer.v"
read_verilog -sv "..\src\neotang\mister_ng\video\neo_273.v"
read_verilog -sv "..\src\neotang\mister_ng\video\neo_b1.v"
read_verilog -sv "..\src\neotang\mister_ng\video\neo_cmc.v"
read_verilog -sv "..\src\neotang\mister_ng\video\slow_cycle.v"
read_verilog -sv "..\src\neotang\mister_ng\video\videosync.v"
read_verilog -sv "..\src\neotang\mister_ng\video\zmc2_dot.v"
read_verilog -sv "..\src\neotang\mister_ng\io\c1_inputs.v"
read_verilog -sv "..\src\neotang\mister_ng\io\c1_regs.v"
read_verilog -sv "..\src\neotang\mister_ng\io\c1_wait.v"
read_verilog -sv "..\src\neotang\mister_ng\io\clocks.v"
read_verilog -sv "..\src\neotang\mister_ng\io\com.v"
read_verilog -sv "..\src\neotang\mister_ng\io\neo_c1.v"
read_verilog -sv "..\src\neotang\mister_ng\io\neo_d0.v"
read_verilog -sv "..\src\neotang\mister_ng\io\neo_e0.v"
read_verilog -sv "..\src\neotang\mister_ng\io\neo_f0.v"
read_verilog -sv "..\src\neotang\mister_ng\io\neo_g0.v"
read_verilog -sv "..\src\neotang\mister_ng\io\neo_pvc.v"
read_verilog -sv "..\src\neotang\mister_ng\io\neo_sma.sv"
read_verilog -sv "..\src\neotang\mister_ng\io\pcm.v"
read_verilog -sv "..\src\neotang\mister_ng\io\register.v"
read_verilog -sv "..\src\neotang\mister_ng\io\resetp.v"
read_verilog -sv "..\src\neotang\mister_ng\io\syslatch.v"
read_verilog -sv "..\src\neotang\mister_ng\io\upd4990.v"
read_verilog -sv "..\src\neotang\mister_ng\io\watchdog.v"
read_verilog -sv "..\src\neotang\mister_ng\io\z80ctrl.v"
read_verilog -sv "..\src\neotang\mister_ng\io\zmc.v"
read_verilog -sv "..\src\neotang\mister_ng\cpu\cpu_68k.v"
read_verilog -sv "..\src\neotang\mister_ng\cpu\cpu_z80.v"
read_verilog -sv "..\src\neotang\mister_ng\cpu\FX68K\fx68k.sv"
read_verilog -sv "..\src\neotang\mister_ng\cpu\FX68K\fx68kAlu.sv"
read_verilog -sv "..\src\neotang\mister_ng\cpu\FX68K\uaddrPla.sv"
read_verilog -sv "..\src\neotang\mister_ng\cells\bd3.v"
read_verilog -sv "..\src\neotang\mister_ng\cells\C43.v"
read_verilog -sv "..\src\neotang\mister_ng\cells\fdm.v"
read_verilog -sv "..\src\neotang\mister_ng\cells\fds.v"
read_verilog -sv "..\src\neotang\mister_ng\cells\fds16bit.v"
read_verilog -sv "..\src\neotang\mister_ng\cells\lt4.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_acc.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_csr.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_div.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_dout.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_eg.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_eg_cnt.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_eg_comb.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_eg_ctrl.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_eg_final.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_eg_pure.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_eg_step.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_exprom.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_kon.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_lfo.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_logsin.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_mmr.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_mmr_sim.vh"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_mod.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_op.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_pcm.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_pcm_interpol.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_pg.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_pg_comb.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_pg_dt.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_pg_inc.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_pg_sum.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_pm.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_reg.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_reg_ch.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_rst.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_sh.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_sh24.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_sh_rst.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_single_acc.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_sumch.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_timers.v"
read_verilog -sv "..\src\neotang\mister_ng\jt12\hdl\jt12_top.v"
read_verilog -sv "..\src\neotang\mister_ng\jt49\hdl\jt49.v"
read_verilog -sv "..\src\neotang\mister_ng\jt49\hdl\jt49_bus.v"
read_verilog -sv "..\src\neotang\mister_ng\jt49\hdl\jt49_cen.v"
read_verilog -sv "..\src\neotang\mister_ng\jt49\hdl\jt49_div.v"
read_verilog -sv "..\src\neotang\mister_ng\jt49\hdl\jt49_eg.v"
read_verilog -sv "..\src\neotang\mister_ng\jt49\hdl\jt49_exp.v"
read_verilog -sv "..\src\neotang\mister_ng\jt49\hdl\jt49_noise.v"
read_verilog -sv "..\src\neotang\mister_ng\jt49\hdl\filter\jt49_dcrm.v"
read_verilog -sv "..\src\neotang\mister_ng\jt49\hdl\filter\jt49_dcrm2.v"
read_verilog -sv "..\src\neotang\mister_ng\jt49\hdl\filter\jt49_dly.v"
read_verilog -sv "..\src\neotang\mister_ng\jt49\hdl\filter\jt49_mave.v"
read_verilog -sv "..\src\neotang\mister_ng\cd\cd.sv"
read_verilog -sv "..\src\neotang\mister_ng\cd\cdda.v"
read_verilog -sv "..\src\neotang\mister_ng\cd\drive.v"
read_verilog -sv "..\src\neotang\mister_ng\cd\hps_ext.v"
read_verilog -sv "..\src\neotang\mister_ng\cd\lc8951.v"
read_verilog -sv "..\src\neotang\mister_ng\pll\pll_0002.v"
read_verilog -sv "..\src\neotang\mister_ng\pll.v"
read_verilog -sv "..\src\neotang\mister_ng\neogeo.sv"
read_verilog -sv "..\src\neotang\mister_ng_top.sv"
read_verilog -sv "..\src\neotang\neotang_top.sv"
hierarchy -top neotang_top
proc
flatten
opt
synth_gowin -top neotang_top -json neotang.json
"@

Set-Content -Path "neotang.ys" -Value $YOSYS_SCRIPT

# Run Yosys for synthesis
Write-Host "Running Yosys for synthesis..." -ForegroundColor $BLUE
yowasp-yosys -l yosys.log neotang.ys
if ($LASTEXITCODE -ne 0) {
    Write-Host "Yosys synthesis failed" -ForegroundColor $RED
    Get-Content -Tail 10 yosys.log
    exit 1
}
Write-Host "Synthesis completed successfully" -ForegroundColor $GREEN

# Run nextpnr for place and route
Write-Host "Running nextpnr for place and route..." -ForegroundColor $BLUE
yowasp-nextpnr-gowin --json neotang.json --write neotang_pnr.json --device $DEVICE --package $DEVICE_PACKAGE --pcf "$CONSTRAINTS_DIR\neotang_138k.pcf" --log nextpnr.log
if ($LASTEXITCODE -ne 0) {
    Write-Host "nextpnr place and route failed" -ForegroundColor $RED
    Get-Content -Tail 10 nextpnr.log
    exit 1
}
Write-Host "Place and route completed successfully" -ForegroundColor $GREEN

# Run Gowin pack to generate bitstream
Write-Host "Running Gowin pack to generate bitstream..." -ForegroundColor $BLUE
gowin_pack -d $DEVICE -o neotang.bin neotang_pnr.json > gowin_pack.log 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "gowin_pack bitstream generation failed" -ForegroundColor $RED
    Get-Content -Tail 10 gowin_pack.log
    exit 1
}

# Check if bitstream was generated
Check-FileExists "neotang.bin" "Bitstream file was not generated"

Write-Host "Build completed successfully!" -ForegroundColor $GREEN
Write-Host "Bitstream is available at: $(Get-Location)\neotang.bin" -ForegroundColor $GREEN
Write-Host "Build statistics:" -ForegroundColor $BLUE
Write-Host "  - Source files: $($SOURCE_FILES.Count)" 