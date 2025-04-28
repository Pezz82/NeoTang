#!/bin/bash
# Build script for NeoGeo core on Tang 138K
# Enhanced with better error handling and reporting

set -e  # Exit on any error

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling function
handle_error() {
    local exit_code=$1
    local error_message=$2
    local error_file=$3
    
    echo -e "${RED}ERROR: $error_message${NC}"
    
    if [ -n "$error_file" ] && [ -f "$error_file" ]; then
        echo -e "${YELLOW}Last 10 lines of log file:${NC}"
        tail -n 10 "$error_file"
        echo -e "${YELLOW}See full log at: $(pwd)/$error_file${NC}"
    fi
    
    echo -e "${RED}Build failed!${NC}"
    exit $exit_code
}

# Function to check if a file exists
check_file_exists() {
    local file=$1
    local message=$2
    
    if [ ! -f "$file" ]; then
        handle_error 1 "$message" ""
    fi
}

# Function to check if a directory exists
check_dir_exists() {
    local dir=$1
    local message=$2
    
    if [ ! -d "$dir" ]; then
        handle_error 1 "$message" ""
    fi
}

# Function to check if a command exists
check_command_exists() {
    local cmd=$1
    local message=$2
    
    if ! command -v $cmd &> /dev/null; then
        handle_error 1 "$message" ""
    fi
}

# Check for required tools
echo -e "${BLUE}Checking for required tools...${NC}"
check_command_exists "yosys" "Yosys not found. Please install Yosys."
check_command_exists "nextpnr-gowin" "nextpnr-gowin not found. Please install nextpnr with Gowin support."
check_command_exists "gowin_pack" "gowin_pack not found. Please install Project Apicula."

# Create build directory
echo -e "${BLUE}Creating build directory...${NC}"
mkdir -p build || handle_error $? "Failed to create build directory" ""
cd build

# Source directories
SRC_DIR="../src/neotang"
MISTER_DIR="$SRC_DIR/mister_ng"
CONSTRAINTS_DIR="../constraints"

# Check if source directories exist
check_dir_exists "$SRC_DIR" "Source directory not found: $SRC_DIR"
check_dir_exists "$MISTER_DIR" "MiSTer directory not found: $MISTER_DIR"

# Create constraints directory if it doesn't exist
echo -e "${BLUE}Setting up constraint files...${NC}"
mkdir -p $CONSTRAINTS_DIR || handle_error $? "Failed to create constraints directory" ""

# Copy constraint files if they don't exist in constraints directory
if [ ! -f "$CONSTRAINTS_DIR/neotang_138k.pcf" ]; then
    check_file_exists "$SRC_DIR/neotang_138k.cst" "Constraint file not found: $SRC_DIR/neotang_138k.cst"
    cp "$SRC_DIR/neotang_138k.cst" "$CONSTRAINTS_DIR/neotang_138k.pcf" || handle_error $? "Failed to copy constraint file" ""
    echo -e "${GREEN}Copied CST to PCF constraint file${NC}"
fi

if [ ! -f "$CONSTRAINTS_DIR/neotang.sdc" ]; then
    check_file_exists "$SRC_DIR/neotang_138k.sdc" "SDC file not found: $SRC_DIR/neotang_138k.sdc"
    cp "$SRC_DIR/neotang_138k.sdc" "$CONSTRAINTS_DIR/neotang.sdc" || handle_error $? "Failed to copy SDC file" ""
    echo -e "${GREEN}Copied SDC timing constraint file${NC}"
fi

# List of source files
echo -e "${BLUE}Collecting source files...${NC}"
SOURCE_FILES=(
    # Top-level files
    "$SRC_DIR/neotang_top.sv"
    "$SRC_DIR/mister_ng_top.sv"
    
    # Memory interface
    "$SRC_DIR/sdram_controller_dual.sv"
    "$SRC_DIR/memory_map.sv"
    "$SRC_DIR/rom_loader.sv"
    
    # Video and audio
    "$SRC_DIR/video_scaler.sv"
    "$SRC_DIR/hdmi_output.sv"
    "$SRC_DIR/hdmi_audio_integration.sv"
    
    # Clock generation
    "$SRC_DIR/pll_instantiation.sv"
    
    # I/O system
    "$SRC_DIR/iosys_bl616.sv"
    
    # MiSTer NeoGeo core files
    $(find $MISTER_DIR -name "*.v" -o -name "*.sv" -o -name "*.vh" | grep -v "ip_stubs")
    
    # IP stubs for Quartus primitives
    "$MISTER_DIR/ip_stubs/altsyncram.v"
    "$MISTER_DIR/ip_stubs/altera_pll.v"
    "$MISTER_DIR/ip_stubs/altpll.v"
)

# Check if all source files exist
for file in "${SOURCE_FILES[@]}"; do
    check_file_exists "$file" "Source file not found: $file"
done

echo -e "${GREEN}Found $(echo ${#SOURCE_FILES[@]}) source files${NC}"

# Create Yosys script
echo -e "${BLUE}Creating Yosys synthesis script...${NC}"
echo "# Yosys synthesis script for NeoGeo core" > neotang.ys
echo "read_verilog -sv \\" >> neotang.ys
for file in "${SOURCE_FILES[@]}"; do
    echo "    $file \\" >> neotang.ys
done
echo >> neotang.ys
echo "synth_gowin -top neotang_top -json neotang.json" >> neotang.ys

# Run Yosys for synthesis
echo -e "${BLUE}Running Yosys for synthesis...${NC}"
yosys -l yosys.log neotang.ys
if [ $? -ne 0 ]; then
    handle_error $? "Yosys synthesis failed" "yosys.log"
fi
echo -e "${GREEN}Synthesis completed successfully${NC}"

# Run nextpnr-gowin for place and route
echo -e "${BLUE}Running nextpnr-gowin for place and route...${NC}"
if ! nextpnr-gowin --device GW5AST-138 --json neotang.json --pcf $CONSTRAINTS_DIR/neotang_138k.pcf --write neotang_pnr.json --freq 74.25 > nextpnr.log 2>&1; then
    echo -e "${YELLOW}nextpnr-gowin failed, falling back to Gowin IDE flow${NC}"
    gowin_sh -f neotang.tcl
else
    echo -e "${GREEN}Place and route completed successfully${NC}"
fi

# Run Gowin pack to generate bitstream
echo -e "${BLUE}Running Gowin pack to generate bitstream...${NC}"
gowin_pack -d GW5AST-138 -o neotang.bin neotang_pnr.json > gowin_pack.log 2>&1
if [ $? -ne 0 ]; then
    handle_error $? "gowin_pack bitstream generation failed" "gowin_pack.log"
fi

# Check if bitstream was generated
check_file_exists "neotang.bin" "Bitstream file was not generated"

echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}Bitstream is available at: $(pwd)/neotang.bin${NC}"
echo -e "${BLUE}Build statistics:${NC}"
echo -e "  - Source files: ${#SOURCE_FILES[@]}"
echo -e "  - Bitstream size: $(du -h neotang.bin | cut -f1)"
echo -e "  - Build time: $SECONDS seconds"
