# Core Template

This directory contains a template for creating new cores for the Tang platform.

## Directory Structure

```
template/
├── rtl/            # RTL source files
├── tb/            # Testbench files
├── Makefile       # Core-specific build rules
└── README.md      # This file
```

## How to Use

1. Copy this directory to create a new core:
   ```bash
   cp -r template ../your_core_name
   ```

2. Update the core's Makefile to include your source files:
   ```makefile
   CORE_SRCS = $(wildcard rtl/*.v)
   CORE_TB_SRCS = $(wildcard tb/*.v)
   ```

3. Create your core's top-level module in `rtl/top.v` that:
   - Connects to the Wishbone bus
   - Implements video/audio output
   - Handles input from the MCU mailbox

4. Add your core to the main Makefile:
   ```makefile
   CORE ?= your_core_name
   ```

5. Build your core:
   ```bash
   make CORE=your_core_name TARGET=tang138k
   ```

## Interface Requirements

Your core must implement:

1. Wishbone bus interface for SDRAM access
2. Video output (RGB + sync signals)
3. Audio output (stereo)
4. Input handling via MCU mailbox

See `neogeo_top.v` for an example implementation. 