# --------- user-tweakable ---------
TARGET ?= tang138k
CORE   ?= neogeo
UART   ?= /dev/ttyUSB0   # BL616 flash port
# ---------------------------------

FPGA_DIR = platform/$(TARGET)
CORE_DIR = cores/$(CORE)
FW_DIR   = $(FPGA_DIR)/firmware-bl616

# Platform-specific settings
ifeq ($(TARGET),tang138k)
    DEVICE = GW1NR-9C
else ifeq ($(TARGET),tang60k)
    DEVICE = GW1N-9C
else
    $(error Unsupported target: $(TARGET))
endif

.PHONY: all fpga fw flash-fw clean

all: fpga fw           # build everything

fpga:
	$(MAKE) -C $(FPGA_DIR) DEVICE=$(DEVICE)
	$(MAKE) -C $(CORE_DIR)

fw:
	$(MAKE) -C $(FW_DIR)

flash-fw:
	$(MAKE) -C $(FW_DIR) flash COMX=$(UART)

clean:
	$(MAKE) -C $(FPGA_DIR) clean
	$(MAKE) -C $(CORE_DIR) clean
	$(MAKE) -C $(FW_DIR) clean 