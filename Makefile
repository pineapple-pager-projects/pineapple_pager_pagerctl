# pagerctl - WiFi Pineapple Pager Hardware Control Toolkit
# Makefile for cross-compiling shared library to MIPS

# Cross-compiler prefix
CROSS_COMPILE ?= mipsel-openwrt-linux-musl-
CC = $(CROSS_COMPILE)gcc

# Directories
SRC_DIR = src
PAYLOAD_DIR = payloads/user/examples/PAGERCTL

# Compiler flags
CFLAGS = -Wall -O2
LDFLAGS = -lm -lpthread
SO_FLAGS = -shared -fPIC

# Target library
LIB_TARGET = libpagerctl.so

# Source files
LIB_SRCS = $(SRC_DIR)/pagerctl.c
DEPS = $(SRC_DIR)/stb_truetype.h $(SRC_DIR)/stb_image.h $(SRC_DIR)/pagerctl.h

# Default: build shared library
all: $(PAYLOAD_DIR)/$(LIB_TARGET)

$(PAYLOAD_DIR)/$(LIB_TARGET): $(LIB_SRCS) $(DEPS)
	$(CC) $(CFLAGS) $(SO_FLAGS) -o $@ $(LIB_SRCS) $(LDFLAGS)

# Build using Docker (local)
docker:
	docker run --rm -v $(PWD):/src -w /src \
		openwrt/sdk:mipsel_24kc-22.03.5 \
		bash -c "export PATH=/builder/staging_dir/toolchain-mipsel_24kc_gcc-11.2.0_musl/bin:\$$PATH && export STAGING_DIR=/builder/staging_dir && make CC=mipsel-openwrt-linux-musl-gcc"

# =============================================================================
# REMOTE BUILD (on root@brainphreak build server)
# =============================================================================
# Build server has Docker image: openwrt/sdk:mipsel_24kc-22.03.5
#
remote-build:
	@echo "Building on remote server root@brainphreak..."
	ssh root@brainphreak "rm -rf /tmp/pagerctl_build && mkdir -p /tmp/pagerctl_build && chmod 777 /tmp/pagerctl_build"
	scp $(SRC_DIR)/pagerctl.c $(SRC_DIR)/pagerctl.h $(SRC_DIR)/stb_truetype.h $(SRC_DIR)/stb_image.h \
		root@brainphreak:/tmp/pagerctl_build/
	ssh root@brainphreak 'docker run --rm -v /tmp/pagerctl_build:/src -w /src openwrt/sdk:mipsel_24kc-22.03.5 bash -c " \
		export PATH=/builder/staging_dir/toolchain-mipsel_24kc_gcc-11.2.0_musl/bin:\$$PATH && \
		export STAGING_DIR=/builder/staging_dir && \
		mipsel-openwrt-linux-musl-gcc -Wall -O2 -shared -fPIC -o libpagerctl.so pagerctl.c -lm -lpthread && \
		ls -la libpagerctl.so"'
	scp root@brainphreak:/tmp/pagerctl_build/libpagerctl.so $(PAYLOAD_DIR)/
	@echo "Build complete! Library: $(PAYLOAD_DIR)/libpagerctl.so"

# Native compile (for testing on Linux x86/ARM, won't work on Pager)
native:
	gcc $(CFLAGS) $(SO_FLAGS) -o $(LIB_TARGET) $(LIB_SRCS) $(LDFLAGS)

# Build C demo (requires library to be built first)
DEMO_SRC = $(SRC_DIR)/demo.c
DEMO_TARGET = $(PAYLOAD_DIR)/examples/demo

demo: $(PAYLOAD_DIR)/$(LIB_TARGET)
	$(CC) $(CFLAGS) -I$(SRC_DIR) -o $(DEMO_TARGET) $(DEMO_SRC) \
		-L$(PAYLOAD_DIR) -l:$(LIB_TARGET) $(LDFLAGS) -Wl,-rpath,$(PAGER_DEST)

# Build demo on remote server
remote-demo:
	@echo "Building C demo on remote server root@brainphreak..."
	ssh root@brainphreak "mkdir -p /tmp/pagerctl_build"
	scp $(DEMO_SRC) $(SRC_DIR)/pagerctl.h $(SRC_DIR)/stb_truetype.h $(SRC_DIR)/stb_image.h \
		$(PAYLOAD_DIR)/libpagerctl.so root@brainphreak:/tmp/pagerctl_build/
	ssh root@brainphreak 'docker run --rm -v /tmp/pagerctl_build:/src -w /src openwrt/sdk:mipsel_24kc-22.03.5 bash -c " \
		export PATH=/builder/staging_dir/toolchain-mipsel_24kc_gcc-11.2.0_musl/bin:\$$PATH && \
		export STAGING_DIR=/builder/staging_dir && \
		mipsel-openwrt-linux-musl-gcc -Wall -O2 -I. -o demo demo.c \
			-L. -l:libpagerctl.so -lm \
			-Wl,-rpath,/root/payloads/user/examples/PAGERCTL && \
		ls -la demo"'
	scp root@brainphreak:/tmp/pagerctl_build/demo $(DEMO_TARGET)
	@echo "Build complete! Demo binary: $(DEMO_TARGET)"

# Download fonts
fonts:
	mkdir -p $(PAYLOAD_DIR)/fonts
	@echo "Downloading Roboto font..."
	curl -sL "https://github.com/googlefonts/roboto/raw/main/src/hinted/Roboto-Regular.ttf" \
		-o $(PAYLOAD_DIR)/fonts/Roboto-Regular.ttf
	curl -sL "https://github.com/googlefonts/roboto/raw/main/src/hinted/Roboto-Bold.ttf" \
		-o $(PAYLOAD_DIR)/fonts/Roboto-Bold.ttf
	@echo "Done! Fonts saved to $(PAYLOAD_DIR)/fonts/"

# Transfer to Pager
PAGER_IP ?= 172.16.52.1
PAGER_DEST ?= /root/payloads/user/examples/PAGERCTL

deploy:
	@echo "Deploying to Pager at $(PAGER_IP)..."
	ssh root@$(PAGER_IP) "mkdir -p $(PAGER_DEST)/examples $(PAGER_DEST)/fonts $(PAGER_DEST)/images"
	scp $(PAYLOAD_DIR)/libpagerctl.so $(PAYLOAD_DIR)/pagerctl.py \
		$(PAYLOAD_DIR)/payload.sh \
		root@$(PAGER_IP):$(PAGER_DEST)/
	scp $(PAYLOAD_DIR)/examples/demo $(PAYLOAD_DIR)/examples/*.py \
		root@$(PAGER_IP):$(PAGER_DEST)/examples/ 2>/dev/null || true
	@if [ -d "$(PAYLOAD_DIR)/fonts" ] && [ "$$(ls -A $(PAYLOAD_DIR)/fonts 2>/dev/null)" ]; then \
		echo "Transferring fonts..."; \
		scp $(PAYLOAD_DIR)/fonts/*.ttf $(PAYLOAD_DIR)/fonts/LICENSE.txt \
			root@$(PAGER_IP):$(PAGER_DEST)/fonts/ 2>/dev/null || true; \
	fi
	@if [ -d "$(PAYLOAD_DIR)/images" ] && [ "$$(ls -A $(PAYLOAD_DIR)/images 2>/dev/null)" ]; then \
		echo "Transferring images..."; \
		scp $(PAYLOAD_DIR)/images/* \
			root@$(PAGER_IP):$(PAGER_DEST)/images/ 2>/dev/null || true; \
	fi
	ssh root@$(PAGER_IP) "chmod +x $(PAGER_DEST)/*.sh $(PAGER_DEST)/examples/* 2>/dev/null || true"
	@echo ""
	@echo "Deployed! Access via Payloads > Examples > PAGERCTL"
	@echo ""
	@echo "Uses Python + libpagerctl.so for smooth graphics."
	@echo "Python3 will be auto-installed if needed."

clean:
	rm -f $(PAYLOAD_DIR)/$(LIB_TARGET) $(LIB_TARGET)

.PHONY: all native docker remote-build demo remote-demo fonts deploy clean
