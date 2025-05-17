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

# Set default board if not specified
BOARD=${1:-138k}

# Check for required tools
echo -e "${BLUE}Checking for required tools...${NC}"
check_command_exists "yosys" "Yosys not found. Please install Yosys."
check_command_exists "nextpnr-gowin" "nextpnr-gowin not found. Please install nextpnr with Gowin support."
check_command_exists "gowin_pack" "gowin_pack not found. Please install Project Apicula."

# Create build directory
echo -e "${BLUE}Creating build directory...${NC}"
mkdir -p build || handle_error $? "Failed to create build directory" ""

# Set environment variables
export BOARD
export DEVICE="GW5AST-${BOARD}C"

# Windows: absolute path to yowasp-yosys.exe
YOSYS_EXE="$HOME/AppData/Roaming/Python/Python313/Scripts/yowasp-yosys.exe"
# Fallback for *nix systems where the wrapper is on PATH
[ -x "$YOSYS_EXE" ] || YOSYS_EXE=yowasp-yosys

# Source directories
SRC_DIR="src/neotang"
MISTER_DIR="$SRC_DIR/mister_ng"
CONSTRAINTS_DIR="constraints"

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

# Write Yosys script
echo -e "${BLUE}Generating Yosys synthesis script...${NC}"
echo "# Yosys synthesis script for NeoGeo core" > build/neotang.ys
echo "set scriptdir ../$SRC_DIR" >> build/neotang.ys

# Read PLL stubs first
echo "read_verilog -sv \$scriptdir/mister_ng/ip_stubs/gowin_pll.v" >> build/neotang.ys
echo "read_verilog -sv \$scriptdir/mister_ng/ip_stubs/rpll.v" >> build/neotang.ys

# Generate file list with forward slashes
echo -e "${BLUE}Collecting source files...${NC}"
for f in $(find $SRC_DIR -name "*.v" -o -name "*.sv" -o -name "*.vh" | grep -v "ip_stubs"); do
    posix=$(echo $f | tr '\\' '/')
    echo "read_verilog -sv ../$posix" >> build/neotang.ys
done

# Add synthesis commands
cat >> build/neotang.ys << 'EOF'

# Synthesis commands
hierarchy -top mister_ng_top
proc
flatten
opt
synth_gowin -top mister_ng_top -json neotang.json
EOF

# Run Yosys synthesis using the correct path
echo -e "${BLUE}Running Yosys synthesis...${NC}"
"$YOSYS_EXE" -l build/yosys.log -c build/neotang.ys || handle_error $? "Yosys synthesis failed" "build/yosys.log"

# Check if Yosys succeeded
check_file_exists "build/neotang.json" "Yosys synthesis failed to generate JSON output"

# Package the design
echo -e "${BLUE}Packaging design...${NC}"
gowin_pack -d $DEVICE -o build/neotang.pack build/neotang.fs || handle_error $? "Gowin pack failed" ""

# Create output directories
echo -e "${BLUE}Creating output directories...${NC}"
mkdir -p sd/cores/console${BOARD} || handle_error $? "Failed to create output directory" ""

# Compress and copy to output directory
echo -e "${BLUE}Compressing and copying to output directory...${NC}"
gzip -9 < build/neotang.pack > sd/cores/console${BOARD}/neogeotang.bin || handle_error $? "Failed to compress and copy output" ""

echo -e "${GREEN}Build complete for $BOARD${NC}"
