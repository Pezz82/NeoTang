# NeoGeo-Tang Technical Documentation

## Overview
This document describes the technical implementation of the NeoGeo core for Tang Console (60K & 138K).

## Borrowed Modules
The following modules were borrowed from nand2mario/tangcore:

1. `pll_27_to_74_96.sv`
   - Clock generation from 27MHz to 74.25MHz and 96MHz
   - Used for core and HDMI timing

2. `sdram_dualport.sv`
   - Dual-port SDRAM controller
   - Port A: P/S/M ROM access
   - Port B: C-ROM access

3. `video_scaler_3x.sv`
   - 320×224 → 1280×720 upscaling
   - Line buffer based implementation

4. `hdmi_output.sv`
   - TMDS PHY implementation
   - Supports 720p output

5. `iosys_bl616.sv`
   - BL616 MCU interface
   - UART communication
   - ROM loading support

## ROM Size Support
The core supports the following ROM sizes:

| ROM Type | Window Size | Max Size |
|----------|-------------|-----------|
| P-ROM    | 8 MiB       | 8 MiB     |
| C-ROM    | 512 MiB     | 512 MiB   |
| V-ROM    | 256 MiB     | 256 MiB   |

## Clock Diagram
```
27MHz ──┐
        ├─ PLL ── 74.25MHz ── Core Clock
        └─ PLL ── 96MHz ───── HDMI Clock
```

## Build System
The core can be built using either:

1. OSS-CAD-Suite (recommended)
   - Yosys
   - nextpnr-gowin
   - gowin_pack

2. Vendor Tools
   - Gowin IDE
   - gowin_sh

### Build Command
```bash
# For Tang 138K (default)
./build_open.sh 138k

# For Tang 60K
./build_open.sh 60k
```

## Porting Guide
To port a MiSTer core to Tang Console:

1. Replace clock generation with `pll_27_to_74_96.sv`
2. Replace SDRAM controller with `sdram_dualport.sv`
3. Add video scaler if needed
4. Add HDMI output
5. Add BL616 interface
6. Update ROM loader for larger sizes
7. Use the build script

## Success Criteria
- Build completes without errors
- LUT usage ≤ 90% on GW5AST-138C
- BIOS grid displays correctly
- Metal Slug 2 runs without glitches
- All buttons mapped correctly
- Audio plays via HDMI 