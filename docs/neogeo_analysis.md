# NeoGeo Core Analysis for Tang 138K Port

## Overview
This document provides an analysis of the MiSTer NeoGeo core architecture to guide the porting process to the Sipeed Tang 138K console.

## Top-Level Module Structure
The MiSTer NeoGeo core uses a top-level module named `emu` that interfaces with the MiSTer framework. Key interfaces include:
- Clock inputs (CLK_50M)
- Video outputs (VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_DE)
- Audio outputs (AUDIO_L, AUDIO_R)
- Memory interfaces (DDRAM and SDRAM)
- Input handling via HPS_BUS

## Memory Requirements
The NeoGeo core has significant memory requirements:

### SDRAM
- Uses dual SDRAM interfaces for high bandwidth
- Handles game ROMs, graphics data, and other assets
- Uses both primary and secondary SDRAM modules in MiSTer
- Memory controller handles refresh, read/write operations

### DDRAM (DDR3)
- Used for additional storage, particularly for CD-based games
- Handles ADPCM audio data
- Provides high-bandwidth access for large assets

## Video Implementation
- Native resolution appears to be 320×224
- Uses a video_mixer module for scaling and processing
- Supports various scaling options (1x, 2x, etc.)
- Outputs 8-bit per channel RGB
- Generates standard HSync/VSync signals
- Includes aspect ratio handling

## Audio Implementation
- Outputs 16-bit stereo audio (AUDIO_L, AUDIO_R)
- Uses signed audio samples (AUDIO_S = 1)
- Includes audio mixing capabilities
- Incorporates JT12 (YM2612) and JT49 sound modules
- Supports ADPCM audio for CD-based games
- Audio clock is 24.576 MHz (standard for 48kHz audio)

## Input Handling
- Uses HPS_BUS for communication with the MiSTer framework
- Supports multiple joysticks/controllers
- Handles buttons, spinners, and other inputs
- Processes PS/2 keyboard and mouse inputs

## Main Components
The core is organized into several key directories:
- `/rtl/cpu` - Contains 68K and Z80 CPU implementations
- `/rtl/video` - Video generation and processing
- `/rtl/jt12` and `/rtl/jt49` - Sound generation modules
- `/rtl/mem` - Memory controllers and interfaces
- `/rtl/io` - Input/output handling
- `/rtl/cd` - CD subsystem (not needed for our cartridge-only port)
- `/rtl/cells` - Basic hardware cells and building blocks

## Adaptation Requirements for Tang 138K

### Memory Adaptation
- Need to map dual SDRAM to Tang 138K's single memory interface
- May need to optimize memory access patterns for different memory architecture
- ROM loading will need to be handled via BL616 microcontroller

### Video Adaptation
- Need to convert to fixed 720p HDMI output
- Will use hdl-util HDMI module from NESTang as reference
- May need scaling or centering of the 320×224 output

### Audio Adaptation
- Need to route audio to HDMI module
- Ensure 48kHz audio sample rate is maintained
- Adapt audio mixing if necessary

### Input Handling
- Replace HPS_BUS with BL616 I/O system
- Map controller inputs from BL616 to NeoGeo expected inputs
- Implement ROM loading via BL616 UART interface

### Clock Generation
- Need to generate appropriate clocks for NeoGeo core
- Need 74.25 MHz for HDMI 720p output
- Need to maintain original timing for NeoGeo components

## Next Steps
1. Create Tang top module that instantiates the NeoGeo core
2. Adapt video output for HDMI
3. Implement audio integration
4. Configure memory interface
5. Integrate BL616 I/O system
6. Build and test the implementation
