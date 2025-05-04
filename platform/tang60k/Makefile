# Tang 60K Platform Makefile

# Toolchain selection
TOOLCHAIN ?= gowin

# Source files
PLATFORM_SRCS = tang_top.v

# Include paths
INCLUDES = -I../common

# Build targets
.PHONY: all clean

all: $(PLATFORM_SRCS)
ifeq ($(TOOLCHAIN),gowin)
	gowin_pack -d GW1N-9C -o neotang.fs $(PLATFORM_SRCS)
else
	@echo "Unsupported toolchain: $(TOOLCHAIN)"
	@exit 1
endif

clean:
	rm -f *.fs *.bit *.bin *.log 