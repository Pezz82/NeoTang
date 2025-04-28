# NeoGeo Core Port to Tang 138K - First-Boot Build Fixes

This repository contains fixes for the NeoGeo core port to the Sipeed Tang 138K FPGA. The fixes address several issues that prevented the core from compiling cleanly and working properly on real hardware.

## Fixes Implemented

1. **HDMI_DE Export (mister_ng_top.sv)**
   - Fixed the missing blanking net by properly separating horizontal and vertical blanking signals
   - Added proper HDMI_DE signal export to the module port list
   - Ensures proper video timing for the NeoGeo core

2. **SDRAM Address Width Fix**
   - Corrected the address mapping from MiSTer core to Tang SDRAM controller
   - Properly preserves bank, row, and column address components
   - Ensures correct memory access patterns for ROMs and game data

3. **Video Scaler Porch Off-by-One Fix**
   - Adjusted the sync signal generation with corrected porch timing
   - Resolved the off-by-one issue in the horizontal counter reset logic
   - Ensures proper HDMI timing for the 720p output

4. **Clock Tree and PLL Hookup Fix**
   - Added the missing PLL lock signals
   - Corrected module instantiations to match their definitions
   - Ensures proper clock generation for all required frequencies

5. **HDMI Audio Path Fix**
   - Improved documentation and clarified the audio signal path
   - Ensures proper audio sample word formatting
   - Provides synchronized audio and video output

6. **ROM Loader ACK Fix**
   - Added the CMD_ACK branch in the STATE_WRITE state
   - Ensures proper handling of ACK commands from the BL616 firmware
   - Prevents communication deadlocks during ROM transfers

7. **Build Script Improvements**
   - Added `set -e` to abort on any error
   - Implemented fallback to Gowin IDE flow if nextpnr-gowin fails
   - Added comprehensive error handling and reporting

8. **Extended Simulation Tests**
   - Added comprehensive test patterns for all fixed components
   - Provides detailed pass/fail results for each subsystem
   - Ensures all fixes work correctly together

## Usage

1. Run `chmod +x build.sh simulate.sh` to make the scripts executable
2. Run `./build.sh` to build the bitstream
   - The script will automatically fall back to Gowin IDE if nextpnr-gowin fails
3. Program your Tang 138K with the generated bitstream

## Requirements

- Gowin EDA tools or open-source toolchain (Yosys, nextpnr-gowin, Project Apicula)
- Tang 138K FPGA board
- NeoGeo BIOS ROM (must be provided by the user)
- NeoGeo game ROMs in either .neo or Darksoft format

## Notes

These fixes ensure the NeoGeo core boots properly on the Tang 138K hardware. After loading the BIOS ROM, you should see the NeoGeo cross-hatch screen with working audio and controls.
