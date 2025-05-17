#!/usr/bin/env bash
#───────────────────────────────────────────────────────────────
#  build_gowin.sh  –  Gowin build for NeoGeo‑Tang core
#  Usage:  ./build_gowin.sh [60k|138k]   (default 138k)
#───────────────────────────────────────────────────────────────
set -e
BOARD=${1:-138k}
case "$BOARD" in
  60k|60K)   DEVICE=GW5AST-60C  ;;
  138k|138K) DEVICE=GW5AST-138C ;;
  *) echo "BOARD must be 60k or 138k"; exit 1 ;;
esac
echo "▶ Building for Tang Console $BOARD  (device $DEVICE)"

# Create build directory
mkdir -p build sd/cores/console${BOARD}

# Run Gowin synthesis
echo "Running synthesis..."
gowin_sh -c "set_device -device $DEVICE -package QFN88" \
         -c "read_verilog -sv ip_stubs/gowin_pll.v" \
         -c "read_verilog -sv src/common/pll_27_to_74_96.sv" \
         -c "read_verilog -sv src/common/watchdog_reset.sv" \
         -c "read_verilog -sv src/common/sdram_dualport.sv" \
         -c "read_verilog -sv src/common/sdram_cache_line.sv" \
         -c "read_verilog -sv src/common/video_scaler_3x.sv" \
         -c "read_verilog -sv src/common/hdmi_output.sv" \
         -c "read_verilog -sv src/common/iosys_bl616.sv" \
         -c "read_verilog -sv src/neotang/rom_loader.sv" \
         -c "read_verilog -sv src/neotang/neotang_top.sv" \
         -c "read_cst constraints/${BOARD}.cst" \
         -c "synthesize -top neotang_top" \
         -c "place" \
         -c "route" \
         -c "write_fs build/neotang.fs"

# Compress bitstream
gzip -9 < build/neotang.fs > sd/cores/console${BOARD}/neogeotang.bin

echo "✔ Done → sd/cores/console${BOARD}/neogeotang.bin" 