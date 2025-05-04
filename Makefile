# --------- user-tweakable ---------
TARGET ?= tang138k
CORE   ?= neogeo
UART   ?= /dev/ttyUSB0   # BL616 flash port
# ---------------------------------

FPGA_DIR = platform/$(TARGET)
CORE_DIR = cores/$(CORE)
FW_DIR   = $(FPGA_DIR)/firmware-bl616

.PHONY: all fpga fw flash-fw clean

all: fpga fw           # build everything

fpga:
	$(MAKE) -C $(FPGA_DIR)
	$(MAKE) -C $(CORE_DIR)

fw:
	$(MAKE) -C $(FW_DIR)

flash-fw:
	$(MAKE) -C $(FW_DIR) flash COMX=$(UART)

clean:
	$(MAKE) -C $(FPGA_DIR) clean
	$(MAKE) -C $(CORE_DIR) clean
	$(MAKE) -C $(FW_DIR) clean 