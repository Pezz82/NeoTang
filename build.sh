#!/bin/bash

# Set default board if not specified
BOARD=${1:-138k}

# Create build directory if it doesn't exist
mkdir -p build

# Set environment variables
export BOARD
export DEVICE="GW5AST-${BOARD}C"

# Windows: absolute path to yowasp-yosys.exe
YOSYS_EXE="/mnt/c/Users/johnp/AppData/Roaming/Python/Python313/Scripts/yowasp-yosys.exe"
# Fallback for *nix systems where the wrapper is on PATH
[ -x "$YOSYS_EXE" ] || YOSYS_EXE=yowasp-yosys

# Write Yosys script
echo "# Yosys synthesis script for NeoGeo core" > build/neotang.ys
echo "set scriptdir ../src/neotang" >> build/neotang.ys

# Generate file list with forward slashes
for f in $(find src/neotang -name "*.v" -o -name "*.sv"); do
  posix=$(echo $f | tr '\\' '/')
  echo "read_verilog -sv ../$posix" >> build/neotang.ys
done

# Add synthesis commands
cat >> build/neotang.ys << 'EOF'

# Synthesis commands
hierarchy -top neotang_top
proc
flatten
opt
synth_gowin -top neotang_top -json neotang.json
EOF

# Run Yosys synthesis using the correct path
"$YOSYS_EXE" -l build/yosys.log -c build/neotang.ys

# Check if Yosys succeeded
if [ ! -f build/neotang.json ]; then
    echo "Error: Yosys synthesis failed"
    exit 1
fi

# Package the design (using Windows gowin_pack)
GOWIN_PACK="/mnt/c/Users/johnp/AppData/Roaming/Python/Python313/Scripts/gowin_pack.exe"
if [ -x "$GOWIN_PACK" ]; then
    "$GOWIN_PACK" -d $DEVICE -o build/neotang.pack build/neotang.fs
else
    echo "Error: gowin_pack not found at $GOWIN_PACK"
    exit 1
fi

# Create output directories
mkdir -p sd/cores/console${BOARD}

# Compress and copy to output directory
gzip -9 < build/neotang.pack > sd/cores/console${BOARD}/neogeotang.bin

echo "Build complete for $BOARD"
