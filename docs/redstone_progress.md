# Redstone Progress Log

This log records completed Redstone bring-up increments and the next concrete
checkpoint. Keep entries small enough to match one commit or one hardware test.

## 2026-04-29

### Stage-1 Baseline Planning

Completed:

- Added the Redstone stage-1 bring-up plan.
- Documented that stage 1 is limited to boot, BCM56846 detection, BDE/switchd
  start, one front-panel link, and one ping through the ASIC data path.
- Selected OpenBCM 6.5.27 as the public SDK proof baseline, while keeping
  Broadcom SDK 5.10.x-era evidence as the compatibility reference.

Verified:

- `switchd` can be built as an ELF32 big-endian PowerPC static executable with
  the current OpenMDK-based path.

Next checkpoint:

- Make Redstone selection explicit in the image and runtime boot path instead
  of asking operators to overwrite `/etc/switchd/config.bcm`.

### Stage-1 Runtime Board Selection

Completed:

- Added a runtime board selector using `/etc/edgenos/board` or
  `EDGENOS_BOARD`.
- Kept `as5610-52x` as the default board profile.
- Mapped `redstone`, `rs2020`, and `r0678` to
  `/etc/switchd/redstone-stage1.bcm`.
- Routed `switchd.service` through `switchd-init` so systemd and manual starts
  use the same preflight and config selection path.
- Made `build-rootfs.sh`, `build-all.sh`, and the Buildroot post-build hook
  write `/etc/edgenos/board`.

Verified:

- `sh -n` and `bash -n` pass for the changed shell scripts.
- `git diff --check` passes.

Next checkpoint:

- Add Redstone kernel/DTS build selection without asserting unverified board
  wiring. The first useful output should be a Redstone-named image that still
  clearly marks the DTS as pending hardware validation.

### Stage-1 Redstone Build Artifacts

Completed:

- Added shared board metadata in `scripts/board-env.sh`.
- Kept `as5610-52x` as the default build target.
- Added `redstone`, `rs2020`, and `r0678` build aliases that generate:
  - `output/kernel/redstone-stage1.dtb`
  - `output/images/edgenos-redstone-stage1.bin`
- Kept the FIT config selector as `accton_as5610_52x` so the current installer
  U-Boot command remains compatible.
- This step initially used the AS5610 DTS as a compatibility placeholder. The
  Redstone board selection now points at the stage-1 DTS skeleton recorded
  below.

Verified:

- `bash -n` passes for the changed build scripts.
- `sh -n` passes for `scripts/board-env.sh`.
- `EDGENOS_BOARD=redstone` resolves to `redstone-stage1.dtb` and
  `edgenos-redstone-stage1.bin`.
- `git diff --check` passes.

Next checkpoint:

- Add a first-pass Redstone hardware inventory table for DTS work: I2C muxes,
  EEPROMs, CPLD/GPIO, fans, PSU, optics presence, and management Ethernet.

### Stage-1 switchd Foreground PID Tracking

Completed:

- Fixed `switchd-init start-foreground` so it writes `/var/run/switchd.pid`
  before `exec`ing `switchd`.
- Preserved the shared `switchd-init` control path: systemd foreground starts
  now leave a PID file that the existing `status` and `stop` commands can use.

Verified:

- `bash -n` passes for `config/rootfs/overlay/usr/sbin/switchd-init`.
- `git diff --check` passes.

Next checkpoint:

- Add the first-pass Redstone hardware inventory table for DTS work.

### Stage-2 Hardware Inventory Seed

Completed:

- Added `docs/redstone_hardware_inventory.md` with a first-pass Redstone
  hardware inventory for Linux 5.10 DTS and platform work.
- Captured confirmed Redstone facts from the original DTB, ZebOS startup
  script, BCM config files, SDK startup scripts, and original modules.
- Marked AS5610-derived DTS, I2C, ONLP SFP, and CPLD code as placeholders that
  must not be treated as Redstone hardware proof.
- Linked the stage-1 plan to the new inventory so future DTS work starts from
  extracted Redstone evidence.

Verified:

- Decompiled `../../boot_original/p2020rdb.dtb` with `dtc` and checked the
  CPU, localbus, CPLD, I2C, Ethernet, and PCIe nodes used in the inventory.
- Inspected `../../cf_card/ZEBOS/zebos.sh` and BCM config files for board
  identity, BDE startup, ASIC startup, and port map evidence.
- `git diff --check` passes.

Next checkpoint:

- Create a Linux 5.10 Redstone DTS skeleton from original `p2020rdb.dtb` facts
  only: CPU, localbus, CPLD, I2C, management Ethernet, PCIe, and flash layout.

### Stage-2 Redstone DTS Skeleton

Completed:

- Added `kernel/dts/redstone-stage1.dts` from extracted original
  `p2020rdb.dtb` facts.
- Switched `EDGENOS_BOARD=redstone`, `rs2020`, and `r0678` to use
  `kernel/dts/redstone-stage1.dts`.
- Kept AS5610 as the default build target.
- Left AS5610-specific mux, optics, fan, and CPLD assumptions out of the
  Redstone DTS skeleton.

Verified:

- `dtc -I dts -O dtb -o /tmp/redstone-stage1.dtb kernel/dts/redstone-stage1.dts`
- `EDGENOS_BOARD=redstone` resolves to `kernel/dts/redstone-stage1.dts` and
  `redstone-stage1.dtb`.
- `EDGENOS_BOARD=as5610-52x` still resolves to the existing AS5610 DTS and
  image names.
- `git diff --check`

Next checkpoint:

- Validate the new DTS against a Linux 5.10 Redstone boot log.
- Capture `dmesg`, `/proc/device-tree`, `lspci -nn`, `ip link`, and I2C scan
  output from hardware, then extend the DTS only from confirmed differences.

### Stage-2 First-Boot Capture Script

Completed:

- Added `redstone-stage1-capture` to the rootfs overlay.
- The script captures board selection, device-tree properties, kernel logs,
  PCI, network, BDE device nodes, switchd status/config, EEPROM, CPLD, and
  hwmon evidence into `/var/log/redstone-stage1/`.
- Active I2C scans are opt-in with `--scan-i2c`; the default capture avoids
  probing every discovered bus.
- Updated the stage-1 plan and hardware inventory to make the capture tarball
  the input for future Redstone DTS and platform-driver changes.

Verified:

- `sh -n config/rootfs/overlay/usr/sbin/redstone-stage1-capture`
- `bash -n config/rootfs/overlay/usr/sbin/redstone-stage1-capture`
- `git diff --check`

Next checkpoint:

- Build a Redstone rootfs/image including the capture script.
- Boot it on hardware, run `redstone-stage1-capture`, then use the tarball to
  validate PCIe BCM56846 enumeration and live device-tree differences.

### Stage-2 Redstone Source Preflight

Completed:

- Added `scripts/check-redstone-stage1.sh` as a build-path preflight for the
  Redstone source tree.
- The preflight checks Redstone board alias resolution, required DTS/config
  files, rootfs overlay inclusion points, switchd service wiring, 52 front-panel
  port mappings, shell syntax, optional DTS compilation, and the executable
  mode for both the preflight script and `redstone-stage1-capture`.
- Documented the preflight in the stage-1 plan so it is the required check
  before a full rootfs or installer build.

Verified:

- `wsl sh -n /mnt/c/other_project/R0678/redstone_system_extracted/_external/edgenos/scripts/check-redstone-stage1.sh`
- `wsl sh /mnt/c/other_project/R0678/redstone_system_extracted/_external/edgenos/scripts/check-redstone-stage1.sh`
- `git diff --cached --check`
- `git diff --check`

Next checkpoint:

- Build a Redstone rootfs/image including the capture script.
- Boot it on hardware, run `redstone-stage1-capture`, then use the tarball to
  validate PCIe BCM56846 enumeration and live device-tree differences.

### Stage-2 Capture Sysfs Symlink Fix

Completed:

- Updated `redstone-stage1-capture` so sysfs class collection follows symlinked
  entries under `/sys/class`.
- Preserved a fallback to plain `find` if the target runtime does not support
  `find -L`.
- Documented that EEPROM, CPLD, and hwmon evidence depends on following
  `/sys/class` symlinks into the real device directories.

Verified:

- `sh -n config/rootfs/overlay/usr/sbin/redstone-stage1-capture`
- `bash -n config/rootfs/overlay/usr/sbin/redstone-stage1-capture`
- `git diff --check`
- `scripts/check-redstone-stage1.sh`

Next checkpoint:

- Include this fix in the next PR review request.
- Boot it on hardware, run `redstone-stage1-capture`, and confirm the tarball
  includes non-empty EEPROM, CPLD, and hwmon class evidence when those classes
  exist.

### Stage-3 Kernel Source Seed

Completed:

- Ran the Redstone kernel source download path with `EDGENOS_BOARD=redstone`.
- Confirmed the Linux 5.10.224 source tree receives
  `arch/powerpc/boot/dts/redstone-stage1.dts`.
- Confirmed the kernel DTS `Makefile` includes `redstone-stage1.dtb`.
- Added `build/` to `.gitignore` because downloaded kernel sources and tarballs
  are generated build inputs, not reviewable source.

Verified:

- `EDGENOS_BOARD=redstone ./scripts/build-kernel.sh download`
- `test -f build/linux-5.10.224/arch/powerpc/boot/dts/redstone-stage1.dts`
- `grep -q redstone-stage1.dtb build/linux-5.10.224/arch/powerpc/boot/dts/Makefile`
- `git ls-files -o --exclude-standard`

Next checkpoint:

- Build the Redstone kernel with `EDGENOS_BOARD=redstone`.
- Decide whether to satisfy the full rootfs/image build through Docker, a Linux
  host with root privileges, or a Buildroot-only path that avoids `debootstrap`.

### Stage-3 Redstone Kernel Build

Completed:

- Installed the missing WSL host build tools required by Linux Kconfig:
  `flex` and `bison`.
- Updated `scripts/build-kernel.sh` so `olddefconfig` is refreshed before every
  kernel build, even when `.config` already exists.
- Built the Redstone-selected Linux 5.10.224 kernel path with
  `EDGENOS_BOARD=redstone`.
- Produced:
  - `output/kernel/uImage`
  - `output/kernel/redstone-stage1.dtb`
  - `output/kernel/vmlinux`

Verified:

- `EDGENOS_BOARD=redstone ./scripts/build-kernel.sh build`
- `file output/kernel/uImage output/kernel/redstone-stage1.dtb output/kernel/vmlinux`
- `dtc -I dtb -O dts output/kernel/redstone-stage1.dtb >/dev/null`
- `sh -n scripts/build-kernel.sh`
- `git diff --check`
- `git ls-files -o --exclude-standard`

Next checkpoint:

- Build a Redstone rootfs/image that includes the capture script and the
  Redstone kernel outputs.
- Decide whether the full image build should use a Linux root/debootstrap path
  or a Buildroot-only path that avoids Docker on this Windows host.

### Stage-3 Redstone Rootfs Build

Completed:

- Moved the default Buildroot source/work tree to
  `${XDG_CACHE_HOME:-$HOME/.cache}/edgenos/buildroot`, with
  `EDGENOS_BUILDROOT_WORKDIR` available for overrides.
- Kept downloaded Buildroot tarballs under the repo-local ignored `build/`
  cache, while extracting the active source tree onto a Linux filesystem.
- Made the Redstone rootfs defconfig explicit for the P2020/e500v2 SPE path:
  `BR2_powerpc_8548`, `BR2_powerpc_SPE`, `uClibc`, and BusyBox init.
- Added `/etc/init.d/S20edgenos` so the BusyBox init rootfs starts
  `platform-init.sh` and `switchd-init start`.
- Kept systemd service enablement conditional in the post-build hook so the
  same overlay can still carry future systemd units.
- Built and assembled the Redstone rootfs artifacts:
  - `output/rootfs/rootfs.tar`
  - `output/rootfs/rootfs.squashfs`
  - `output/images/rootfs.sqsh`

Verified:

- `EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh build`
- `EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh assemble`
- `output/rootfs/staging/etc/edgenos/board` contains `redstone`.
- `output/rootfs/staging/etc/init.d/S20edgenos` is executable.
- `output/rootfs/staging/usr/sbin/redstone-stage1-capture` is executable.
- `output/rootfs/staging/etc/switchd/redstone-stage1.bcm` exists.
- Buildroot final `.config` contains `BR2_powerpc_8548`,
  `BR2_powerpc_SPE`, `BR2_TOOLCHAIN_BUILDROOT_UCLIBC`, and
  `BR2_INIT_BUSYBOX`.
- Artifact sizes from this WSL build:
  - `output/rootfs/rootfs.tar`: 36M
  - `output/rootfs/rootfs.squashfs`: 6.5M
  - `output/images/rootfs.sqsh`: 11M
- `wsl sh scripts/check-redstone-stage1.sh`
- `git diff --check`
- `git ls-files -o --exclude-standard`

Next checkpoint:

- Build or package a Redstone installer image that pairs the verified
  Redstone kernel outputs with the assembled Redstone rootfs.
- Boot the image on hardware, confirm BCM56846 PCIe enumeration, start BDE and
  `switchd`, then run `redstone-stage1-capture`.

### Stage-3 Redstone Installer Packaging

Completed:

- Fixed `initramfs-build.sh` so it can build the raw-syscall
  `initramfs/nos-init.c` source that defines `_start` directly.
- Kept the compile path freestanding with `-nostdlib`, `-nostartfiles`,
  `-nodefaultlibs`, and explicit `-lgcc`; the Docker fallback uses the same
  flags and source path.
- Ignored generated top-level initramfs build outputs:
  - `initramfs.cpio.gz`
  - `root/`
- Built the Redstone FIT image from the existing Redstone kernel, initramfs,
  and `redstone-stage1.dtb`.
- Built the Redstone ONIE installer image from the Redstone FIT and assembled
  rootfs.

Verified:

- `bash -n initramfs-build.sh`
- `bash -n scripts/build-installer.sh`
- `EDGENOS_BOARD=redstone ./scripts/build-installer.sh fit`
- `EDGENOS_BOARD=redstone ./scripts/build-installer.sh image`
- `file root/init initramfs.cpio.gz output/images/uImage-powerpc.itb output/images/edgenos-redstone-stage1.bin`
- `grep -q redstone-stage1 output/images/nos.its`
- `grep -q accton_as5610_52x output/images/nos.its`
- `grep -q "EdgeNOS for Redstone" output/images/nos.its`
- `wsl sh scripts/check-redstone-stage1.sh`
- Artifact sizes from this WSL build:
  - `initramfs.cpio.gz`: 2.5K
  - `output/images/uImage-powerpc.itb`: 4.4M
  - `output/images/rootfs.sqsh`: 11M
  - `output/images/payload.tar`: 15M
  - `output/images/edgenos-redstone-stage1.bin`: 15M

Next checkpoint:

- Boot `output/images/edgenos-redstone-stage1.bin` on Redstone hardware.
- Confirm the kernel reaches BusyBox init, the rootfs board selector is
  `redstone`, BCM56846 appears on PCIe, BDE starts, and `switchd` reads
  `/etc/switchd/redstone-stage1.bcm`.
- Bring up one front-panel port, pass one ping through the ASIC data path, and
  run `redstone-stage1-capture` for the next DTS/platform-driver increment.

### Stage-3 Redstone Support Module Packaging

Completed:

- Added `scripts/build-modules.sh` to build the Redstone stage-1 kernel support
  modules against the Linux 5.10.224 build tree.
- Built and checked the BDE, AS5610-compatible CPLD placeholder, and retimer
  modules required by `platform-init.sh`.
- Fixed the retimer class module build on Linux 5.10 by including the kernel
  device-number helper header used for `MKDEV`.
- Added `scripts/check-redstone-image.sh` to verify the generated Redstone
  rootfs staging tree contains board selection, switchd, BDE modules, platform
  modules, and `redstone-stage1.bcm`.
- Extended the source preflight so it also covers the module build script and
  generated-image staging check.
- Updated `build-all.sh` so full builds also build and verify these external
  modules before rootfs assembly.

Verified:

- `sh -n scripts/build-modules.sh`
- `sh -n scripts/check-redstone-image.sh`
- `bash -n scripts/build-all.sh`
- `EDGENOS_BOARD=redstone ./scripts/build-modules.sh build`
- `EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh assemble`
- `EDGENOS_BOARD=redstone ./scripts/check-redstone-image.sh`
- `EDGENOS_BOARD=redstone ./scripts/build-installer.sh image`
- `EDGENOS_BOARD=redstone ./scripts/check-redstone-stage1.sh`
- `git diff --check`

Generated module outputs from this WSL build:

- `asic/bde/linux-kernel-bde.ko`: 17K
- `asic/bde/linux-user-bde.ko`: 5.1K
- `platform/cpld/accton_as5610_52x_cpld.ko`: 11K
- `platform/retimer/retimer_class.ko`: 6.2K
- `platform/retimer/ds100df410.ko`: 11K

Next checkpoint:

- Boot `output/images/edgenos-redstone-stage1.bin` on Redstone hardware.
- Confirm `linux-kernel-bde.ko`, `linux-user-bde.ko`, CPLD placeholder, and
  retimer modules load from `/lib/modules/extra`.
- Confirm BCM56846 appears through BDE, then start `switchd` with
  `/etc/switchd/redstone-stage1.bcm`.

### Stage-1 Hardware Validation Entrypoint

Completed:

- Added `redstone-stage1-validate` to the rootfs overlay for first-boot
  hardware acceptance checks.
- The validator records evidence under `/var/log/redstone-stage1/validate-*`
  and checks board selection, Redstone switchd config, packaged modules,
  loaded BDE modules, BDE device nodes, BCM56846 PCIe ID `14e4:b846`,
  `switchd` status, `swp` interfaces, front-panel link, and optional ping.
- Added `--strict` for acceptance gating and `--capture` to chain the larger
  `redstone-stage1-capture` evidence bundle.
- Extended source preflight and generated-image checks so the validation
  entrypoint must be present and executable.

Verified:

- `sh -n config/rootfs/overlay/usr/sbin/redstone-stage1-validate`
- `config/rootfs/overlay/usr/sbin/redstone-stage1-validate --help`
- `EDGENOS_BOARD=redstone ./scripts/check-redstone-stage1.sh`
- `EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh assemble`
- `EDGENOS_BOARD=redstone ./scripts/check-redstone-image.sh`
- `EDGENOS_BOARD=redstone ./scripts/build-installer.sh image`

Next checkpoint:

- On hardware, run
  `redstone-stage1-validate --iface <swpN> --peer <peer-ip> --strict`.
- If that passes, rerun with `--capture` and attach the validation directory
  plus capture tarball to the next DTS/platform-driver increment.

### Stage-1 Evidence Analyzer

Completed:

- Added `scripts/analyze-redstone-stage1-evidence.sh` as a host-side analyzer
  for `redstone-stage1-validate` directories and `redstone-stage1-capture`
  `.tar.gz` bundles.
- The analyzer reports a repeatable PASS/WARN/FAIL checklist for board
  selection, `redstone-stage1.bcm`, BDE modules, BDE device nodes, BCM56846
  PCIe evidence, `switchd`, `swp` interfaces, link-up, ping, focused dmesg,
  and platform sysfs evidence.
- Added `--strict` so an acceptance bundle exits nonzero when required
  evidence is missing, including a missing validation log or skipped ping.
- Extended the source preflight so the analyzer must be present, shell-valid,
  and tracked executable.
- Updated the stage-1 plan with the evidence-analysis workflow.

Verified:

- `sh -n scripts/analyze-redstone-stage1-evidence.sh`
- `./scripts/analyze-redstone-stage1-evidence.sh /tmp/redstone-validate-ok`
- `./scripts/analyze-redstone-stage1-evidence.sh --strict /tmp/redstone-validate-ok`
- `./scripts/analyze-redstone-stage1-evidence.sh /tmp/redstone-capture-ok.tar.gz`
- `EDGENOS_BOARD=redstone ./scripts/check-redstone-stage1.sh`

Next checkpoint:

- Use `redstone-stage1-validate --iface <swpN> --peer <peer-ip> --strict` on
  hardware and analyze the resulting `validate-*` directory before changing DTS
  or platform drivers.
- If the validation run also produces a capture tarball, analyze the tarball and
  keep both outputs attached to the next hardware-focused change.

### Stage-1 Evidence Analyzer Link Scope Fix

Completed:

- Tightened host-side link-up analysis so capture-only evidence must tie
  `carrier=1`, `operstate=up`, `LOWER_UP`, `state UP`, or ethtool link status
  to a `swp*` interface.
- Kept explicit validator PASS lines such as `front-panel link is up: swpN` and
  `at least one swp link is up: swpN` as valid front-panel link evidence.
- Updated the stage-1 plan to document that management `eth*` link state cannot
  satisfy the front-panel link checkpoint.

Verified:

- `sh -n scripts/analyze-redstone-stage1-evidence.sh`
- Analyzer rejects capture evidence where only `eth0` has `carrier=1`.
- Analyzer accepts capture evidence where `swp1` has `carrier=1`.

Next checkpoint:

- Keep using `redstone-stage1-validate --iface <swpN> --peer <peer-ip> --strict`
  for acceptance; capture-only bundles remain diagnostic unless strict validation
  output is present.
