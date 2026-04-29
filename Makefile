# EdgeNOS - Network Operating System for Edgecore AS5610-52X
# Top-level build orchestration

TOPDIR    := $(shell pwd)
CROSS     := powerpc-linux-gnu-
ARCH      := powerpc
EDGENOS_BOARD ?= as5610-52x
export EDGENOS_BOARD

# Kernel
KVER      := 5.10.224
KSRC      := $(TOPDIR)/build/linux-$(KVER)
KCONFIG   := $(TOPDIR)/config/kernel/as5610_defconfig

# Buildroot
BRVER     := 2023.02.9
BRSRC     := $(TOPDIR)/build/buildroot-$(BRVER)
BRCONFIG  := $(TOPDIR)/config/rootfs/buildroot_defconfig

# OpenMDK
OPENMDK   := $(TOPDIR)/asic/openmdk

# Output
OUTDIR    := $(TOPDIR)/output
IMGDIR    := $(OUTDIR)/images

# Platform modules
PLATFORM_MODS := platform/cpld platform/retimer

.PHONY: all clean toolchain kernel modules rootfs-base rootfs image installer \
        switchd bde openmdk openbcm-source openbcm-bde-check openbcm-bde help

all: image

help:
	@echo "EdgeNOS Build System for Edgecore AS5610-52X"
	@echo ""
	@echo "Targets:"
	@echo "  toolchain    - Verify/install cross-compilation tools"
	@echo "  kernel       - Build Linux kernel + DTB"
	@echo "  modules      - Build platform kernel modules (CPLD, retimer)"
	@echo "  bde          - Build BDE kernel modules"
	@echo "  openmdk      - Build OpenMDK libraries (CDK, BMD, PHY)"
	@echo "  openbcm-source - Fetch/check OpenBCM 6.5.27 source seed"
	@echo "  openbcm-bde-check - Check OpenBCM BDE build prerequisites"
	@echo "  openbcm-bde  - Build OpenBCM BDE modules for Redstone Linux 5.10"
	@echo "  switchd      - Build switch daemon"
	@echo "  rootfs-base  - Build base root filesystem (Buildroot)"
	@echo "  rootfs       - Assemble final rootfs with all components"
	@echo "  image        - Build ONIE installer image"
	@echo "  clean        - Clean all build artifacts"
	@echo ""
	@echo "Quick start:"
	@echo "  make toolchain && make image"
	@echo "  EDGENOS_BOARD=redstone make image"

# ── Toolchain ──────────────────────────────────────────────────────

toolchain:
	@echo "==> Checking cross-compilation toolchain..."
	@$(TOPDIR)/scripts/setup-toolchain.sh

# ── Kernel ─────────────────────────────────────────────────────────

$(KSRC)/.config: $(KCONFIG) | kernel-download
	cp $(KCONFIG) $(KSRC)/.config
	$(MAKE) -C $(KSRC) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) olddefconfig

kernel-download:
	@$(TOPDIR)/scripts/build-kernel.sh download

kernel: $(KSRC)/.config
	@$(TOPDIR)/scripts/build-kernel.sh build

kernel-menuconfig: $(KSRC)/.config
	$(MAKE) -C $(KSRC) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) menuconfig
	cp $(KSRC)/.config $(KCONFIG)

# ── Device Tree ────────────────────────────────────────────────────

dtb: kernel
	@echo "==> DTB built as part of kernel (in-tree DTS)"

# ── Platform kernel modules ───────────────────────────────────────

modules: kernel
	@for mod in $(PLATFORM_MODS); do \
		echo "==> Building $$mod"; \
		$(MAKE) -C $(KSRC) M=$(TOPDIR)/$$mod \
			ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) modules; \
	done

# ── BDE kernel modules ────────────────────────────────────────────

bde: kernel
	@echo "==> Building BDE kernel modules"
	$(MAKE) -C $(TOPDIR)/asic/bde \
		KSRC=$(KSRC) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS)

# ── OpenMDK libraries ─────────────────────────────────────────────

openmdk:
	@echo "==> Building OpenMDK (CDK/BMD/PHY)"
	@$(TOPDIR)/scripts/build-sdk.sh

openbcm-source:
	@echo "==> Preparing OpenBCM 6.5.27 source seed"
	@$(TOPDIR)/scripts/prepare-openbcm.sh fetch
	@$(TOPDIR)/scripts/prepare-openbcm.sh check

openbcm-bde-check:
	@$(TOPDIR)/scripts/build-openbcm-bde.sh check

openbcm-bde: openbcm-source
	@echo "==> Building OpenBCM Linux BDE modules for Redstone"
	@$(TOPDIR)/scripts/build-openbcm-bde.sh all

# ── Switch daemon ──────────────────────────────────────────────────

switchd: openmdk
	@echo "==> Building switchd"
	$(MAKE) -C $(TOPDIR)/asic/switchd \
		CROSS_COMPILE=$(CROSS) OPENMDK=$(OPENMDK) TOPDIR=$(TOPDIR)

# ── Root filesystem ───────────────────────────────────────────────

rootfs-download:
	@$(TOPDIR)/scripts/build-rootfs.sh download

rootfs-base: rootfs-download
	@echo "==> Building base rootfs with Buildroot"
	@$(TOPDIR)/scripts/build-rootfs.sh build

rootfs: rootfs-base kernel modules bde switchd
	@echo "==> Assembling final rootfs"
	@$(TOPDIR)/scripts/build-rootfs.sh assemble

# ── FIT image & ONIE installer ────────────────────────────────────

fit: kernel rootfs
	@echo "==> Building FIT image"
	@$(TOPDIR)/scripts/build-installer.sh fit

image: fit
	@echo "==> Building ONIE installer"
	@$(TOPDIR)/scripts/build-installer.sh image
	@echo ""
	@echo "==> ONIE installer ready under $(IMGDIR)"

# ── Clean ──────────────────────────────────────────────────────────

clean:
	rm -rf $(OUTDIR)
	@for mod in $(PLATFORM_MODS); do \
		[ -d "$$mod" ] && $(MAKE) -C $(KSRC) M=$(TOPDIR)/$$mod clean 2>/dev/null; \
	done; true
	$(MAKE) -C $(TOPDIR)/asic/bde clean 2>/dev/null; true
	$(MAKE) -C $(TOPDIR)/asic/switchd clean 2>/dev/null; true

distclean: clean
	rm -rf $(TOPDIR)/build
