# NeoTang

NeoGeo core for the Tang FPGA board, based on the MiSTer NeoGeo core.

## Prerequisites

- Git
- Vivado 2023.2 or later
- Bouffalo SDK (for BL616 firmware)
- USB-C OTG adapter for USB storage

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

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- MiSTer NeoGeo core by Sean 'Furrtek' Gonsalves
- TangCore by nand2mario
- BL616 firmware by nand2mario
