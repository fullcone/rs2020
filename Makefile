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
        switchd bde openmdk openbcm-source openbcm-bde-check openbcm-bde \
        openbcm-bde-bundle openbcm-bde-smoke-analyze \
        openbcm-userland-check openbcm-init-probe-check openbcm-init-probe \
        openbcm-init-probe-bundle redstone-handoff redstone-handoff-verify \
        redstone-handoff-analyze redstone-platform-inventory-analyze \
        redstone-usb-stage1-check redstone-usb-stage1 help

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
	@echo "  openbcm-bde-bundle - Copy OpenBCM BDE modules into a hardware-load bundle"
	@echo "  openbcm-bde-smoke-analyze - Analyze Redstone OpenBCM BDE smoke evidence"
	@echo "  openbcm-userland-check - Check OpenBCM userland init source/API path"
	@echo "  openbcm-init-probe-check - Check Redstone OpenBCM init probe prerequisites"
	@echo "  openbcm-init-probe - Build Redstone OpenBCM init probe gate"
	@echo "  openbcm-init-probe-bundle - Bundle Redstone OpenBCM init probe gate"
	@echo "  redstone-handoff - Package Redstone stage-1 hardware handoff bundle"
	@echo "  redstone-handoff-verify - Verify a Redstone hardware handoff bundle"
	@echo "  redstone-handoff-analyze - Verify handoff and analyze strict Redstone validation bundle"
	@echo "  redstone-platform-inventory-analyze - Build Redstone DTS/platform inventory from capture evidence"
	@echo "  redstone-usb-stage1-check - Check Redstone USB stage-1 image prerequisites"
	@echo "  redstone-usb-stage1 - Build non-destructive Redstone USB stage-1 boot/capture image"
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

openbcm-bde-bundle:
	@echo "==> Bundling OpenBCM Linux BDE modules for Redstone hardware smoke testing"
	@$(TOPDIR)/scripts/build-openbcm-bde.sh bundle

openbcm-bde-smoke-analyze:
	@[ -n "$(OPENBCM_BDE_SMOKE_EVIDENCE)" ] || { \
		echo "usage: make openbcm-bde-smoke-analyze OPENBCM_BDE_SMOKE_EVIDENCE=/path/to/openbcm-bde-smoke-..." >&2; \
		exit 2; \
	}
	@$(TOPDIR)/scripts/analyze-redstone-openbcm-bde-smoke.sh --strict "$(OPENBCM_BDE_SMOKE_EVIDENCE)"

openbcm-userland-check:
	@$(TOPDIR)/scripts/check-openbcm-userland-init.sh

openbcm-init-probe-check: openbcm-userland-check
	@$(TOPDIR)/scripts/build-openbcm-init-probe.sh check

openbcm-init-probe: openbcm-userland-check
	@echo "==> Building Redstone OpenBCM init probe gate"
	@$(TOPDIR)/scripts/build-openbcm-init-probe.sh build

openbcm-init-probe-bundle: openbcm-init-probe
	@echo "==> Bundling Redstone OpenBCM init probe gate"
	@$(TOPDIR)/scripts/build-openbcm-init-probe.sh bundle

redstone-handoff:
	@echo "==> Packaging Redstone stage-1 hardware handoff bundle"
	@EDGENOS_BOARD=redstone $(TOPDIR)/scripts/package-redstone-hardware-handoff.sh

redstone-handoff-verify:
	@[ -n "$(REDSTONE_HANDOFF_PATH)" ] || { \
		echo "usage: make redstone-handoff-verify REDSTONE_HANDOFF_PATH=/path/to/redstone-handoff-or-tarball" >&2; \
		exit 2; \
	}
	@$(TOPDIR)/scripts/verify-redstone-hardware-handoff.sh "$(REDSTONE_HANDOFF_PATH)"

redstone-handoff-analyze:
	@[ -n "$(REDSTONE_HANDOFF_PATH)" ] || { \
		echo "usage: make redstone-handoff-analyze REDSTONE_HANDOFF_PATH=/path/to/redstone-handoff-or-tarball REDSTONE_CAPTURE_PATH=/path/to/validation-bundle-or-dir" >&2; \
		exit 2; \
	}
	@[ -n "$(REDSTONE_CAPTURE_PATH)" ] || { \
		echo "usage: make redstone-handoff-analyze REDSTONE_HANDOFF_PATH=/path/to/redstone-handoff-or-tarball REDSTONE_CAPTURE_PATH=/path/to/validation-bundle-or-dir" >&2; \
		exit 2; \
	}
	@$(TOPDIR)/scripts/analyze-redstone-handoff-capture.sh "$(REDSTONE_HANDOFF_PATH)" "$(REDSTONE_CAPTURE_PATH)"

redstone-platform-inventory-analyze:
	@[ -n "$(REDSTONE_CAPTURE_PATH)" ] || { \
		echo "usage: make redstone-platform-inventory-analyze REDSTONE_CAPTURE_PATH=/path/to/validation-bundle-or-dir" >&2; \
		exit 2; \
	}
	@$(TOPDIR)/scripts/analyze-redstone-platform-inventory.sh "$(REDSTONE_CAPTURE_PATH)"

redstone-usb-stage1-check:
	@EDGENOS_BOARD=redstone $(TOPDIR)/scripts/package-redstone-usb-stage1.sh check

redstone-usb-stage1:
	@echo "==> Building non-destructive Redstone USB stage-1 boot/capture image"
	@EDGENOS_BOARD=redstone $(TOPDIR)/scripts/package-redstone-usb-stage1.sh image

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
