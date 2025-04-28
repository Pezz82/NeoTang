#!/bin/bash
# Simulation script for NeoGeo core on Tang 138K

set -e  # Exit on error

# Create simulation directory
mkdir -p sim_build
cd sim_build

# Source directories
SRC_DIR="../src/neotang"
MISTER_DIR="$SRC_DIR/mister_ng"
SIM_DIR="../sim"

# List of source files
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
    
    # Testbench
    "$SIM_DIR/neotang_tb.sv"
)

# Run Verilator for simulation
echo "Running Verilator for simulation..."
verilator -cc --top-module neotang_tb \
    --trace --trace-structs \
    --Mdir verilator_build \
    --exe sim_main.cpp \
    "${SOURCE_FILES[@]}"

# Create simulation main file
cat > sim_main.cpp << 'EOF'
#include "Vneotang_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    // Initialize Verilated modules
    Vneotang_tb* tb = new Vneotang_tb;
    
    // Initialize trace dump
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    tb->trace(tfp, 99);
    tfp->open("neotang_tb.vcd");
    
    // Initialize simulation time
    vluint64_t sim_time = 0;
    vluint64_t timeout = 50000000; // 50ms at 1ns/tick
    
    // Run simulation
    std::cout << "Starting simulation..." << std::endl;
    while (!Verilated::gotFinish() && sim_time < timeout) {
        tb->eval();
        tfp->dump(sim_time);
        sim_time++;
        
        // Check for HSYNC toggling after ROM loading
        if (sim_time > 20000000 && tb->hsync_toggle_count > 0) {
            std::cout << "PASS: HSYNC is toggling" << std::endl;
            break;
        }
    }
    
    // Check if we timed out
    if (sim_time >= timeout) {
        std::cout << "FAIL: Simulation timed out without HSYNC toggling" << std::endl;
    }
    
    // Cleanup
    tfp->close();
    delete tfp;
    delete tb;
    
    return 0;
}
EOF

# Build the simulation
echo "Building simulation..."
cd verilator_build
make -j$(nproc) -f Vneotang_tb.mk Vneotang_tb

echo "Simulation build completed successfully!"
echo "Run the simulation with: ./verilator_build/Vneotang_tb"
