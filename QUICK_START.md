# NeoGeo Core for Tang 138K - Quick Start Guide

This guide will help you get started with the NeoGeo core on your Tang 138K console.

## Prerequisites

1. Tang 138K FPGA console
2. NeoGeo BIOS ROM
3. NeoGeo game ROMs (either .neo format or Darksoft format)
4. USB cable for programming

## Installation

### Option 1: Using Pre-built Bitstream

1. Download the pre-built bitstream from the releases page
2. Connect your Tang 138K to your computer via USB
3. Program the bitstream using the Gowin Programmer or openFPGALoader:
   ```
   openFPGALoader -b tangnano20k neotang.fs
   ```

### Option 2: Building from Source

1. Follow the build instructions in the README.md file
2. Program the generated bitstream to your Tang 138K

## Loading ROMs

1. Connect the Tang 138K to your computer
2. Use the BL616 loader tool to transfer the BIOS ROM:
   ```
   bl616_loader --bios neogeo.rom
   ```

3. Load a game ROM:
   - For .neo format:
     ```
     bl616_loader --neo mslug.neo
     ```
   - For Darksoft format:
     ```
     bl616_loader --darksoft p_rom.bin s_rom.bin m_rom.bin v_rom.bin c_rom.bin
     ```

## Controls

- D-Pad: Movement
- A/B/X/Y: NeoGeo A/B/C/D buttons
- Start: Start button
- Select: Select button
- L/R: Special functions

## Troubleshooting

1. **No video output**: Ensure your HDMI display supports 720p resolution
2. **No audio**: Check HDMI connection and make sure your display's audio is enabled
3. **Game doesn't start**: Verify you've loaded the correct BIOS ROM
4. **Controller not working**: Check BL616 firmware version and update if necessary

For more detailed information, refer to the full README.md file.
