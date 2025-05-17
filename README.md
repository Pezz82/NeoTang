# NeoTang

NeoGeo core for the Tang FPGA board, based on the MiSTer NeoGeo core.

## Prerequisites

- Git
- Vivado 2023.2 or later
- Bouffalo SDK (for BL616 firmware)
- USB-C OTG adapter for USB storage
- Gowin EDA tools or open-source toolchain (Yosys, nextpnr-gowin, Project Apicula)
- Tang 138K FPGA board
- NeoGeo BIOS ROM (must be provided by the user)
- NeoGeo game ROMs in either .neo or Darksoft format

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/Pezz82/NeoTang
   cd NeoTang
   git submodule update --init --recursive
   ```

2. Flash the BL616 firmware:
   ```bash
   make flash-fw UART=/dev/ttyUSB0  # Hold BOOT button while flashing
   ```

3. Build the NeoGeo core:
   ```bash
   make CORE=neogeo TARGET=tang138k
   ```
   Note: The build script will automatically fall back to Gowin IDE if nextpnr-gowin fails.

4. Prepare your SD card:
   - Copy BIOS files to `/bios/NeoGeo/`:
     - `000-lo.lo`
     - `sfix.sfix`
     - `unibios.rom` (or stock BIOS)
   - Place `romsets.xml` in `/config/NeoGeo/`
   - Put your `.neo` game folders in `/games/NeoGeo/`

5. Connect a USB-C OTG adapter with your games on a FAT32-formatted USB stick.

## Repository Structure

```
NeoTang/
├── platform/           # Platform-specific code
│   └── tang138k/      # Tang 138K implementation
│       ├── tangcore/  # TangCore submodule
│       └── firmware-bl616/  # BL616 firmware
├── cores/             # FPGA cores
│   ├── neogeo/        # NeoGeo core
│   └── template/      # Template for new cores
├── docs/              # Documentation
└── Makefile          # Build system
```

## Building Other Cores

To build a different core:

```bash
make CORE=core_name TARGET=tang138k
```

See `cores/template/README.md` for how to create new cores.

## Controls

- Menu + Start: System menu
- Start + Select: Reset
- Menu + Select: Save state
- Menu + A: Load state

## Implemented Fixes

This port includes several important fixes for the Tang 138K board:

1. **HDMI_DE Export**
   - Fixed missing blanking net by properly separating horizontal and vertical blanking signals
   - Added proper HDMI_DE signal export
   - Ensures proper video timing

2. **SDRAM Address Width Fix**
   - Corrected address mapping from MiSTer core to Tang SDRAM controller
   - Properly preserves bank, row, and column address components

3. **Video Scaler Porch Fix**
   - Adjusted sync signal generation with corrected porch timing
   - Resolved off-by-one issue in horizontal counter reset logic
   - Ensures proper HDMI timing for 720p output

4. **Clock Tree and PLL Fix**
   - Added missing PLL lock signals
   - Corrected module instantiations
   - Ensures proper clock generation

5. **HDMI Audio Path Fix**
   - Improved audio signal path documentation
   - Ensures proper audio sample word formatting
   - Provides synchronized audio and video output

6. **ROM Loader ACK Fix**
   - Added CMD_ACK branch in STATE_WRITE state
   - Ensures proper handling of ACK commands
   - Prevents communication deadlocks during ROM transfers

7. **Build Script Improvements**
   - Added error handling and reporting
   - Implemented fallback to Gowin IDE flow
   - Added comprehensive test patterns

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- MiSTer NeoGeo core by Sean 'Furrtek' Gonsalves
- TangCore by nand2mario
- BL616 firmware by nand2mario
