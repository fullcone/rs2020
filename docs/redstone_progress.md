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

### Stage-3 OpenBCM Source Seed

Completed:

- Added `scripts/prepare-openbcm.sh` to fetch, pin, and sanity-check the
  OpenBCM 6.5.27 source seed under the ignored `build/openbcm/` tree.
- Wired `make openbcm-source` to fetch and check the source seed.
- Extended Redstone source preflight so the OpenBCM source-seed script must be
  present, shell-valid, and tracked executable.
- Updated the SDK decision and stage plan to document that OpenBCM is a
  generated source input, not vendored SDK code.

Verified:

- `sh -n scripts/prepare-openbcm.sh`
- `./scripts/prepare-openbcm.sh print-env`
- `./scripts/prepare-openbcm.sh fetch`
- `./scripts/prepare-openbcm.sh check`
- `make openbcm-source`

Next checkpoint:

- Use the pinned source seed to build the OpenBCM Linux BDE modules for Linux
  5.10 and PowerPC32 big-endian.
- Do not claim L3/ACL/ECMP offload until OpenBCM userland and BDE have run on
  Redstone hardware.

### Stage-3 OpenBCM BDE Build Probe

Completed:

- Added `scripts/build-openbcm-bde.sh` to generate a Redstone OpenBCM target
  file under the ignored source seed, copy BDE sources into temporary Kbuild
  module directories, and compile Linux BDE modules against the Redstone Linux
  5.10.224 build tree.
- Wired `make openbcm-bde-check` and `make openbcm-bde` into the top-level
  build system.
- Extended the Redstone source preflight so the OpenBCM BDE build helper must
  be present, shell-valid, and tracked executable.
- Documented that this is a build probe only, not a hardware offload claim.

Verified:

- `wsl sh -n scripts/build-openbcm-bde.sh`
- `wsl sh scripts/build-openbcm-bde.sh check`
- `wsl sh scripts/build-openbcm-bde.sh all`
- Built `build/openbcm/redstone-bde/linux-kernel-bde.ko`.
- Built `build/openbcm/redstone-bde/linux-user-bde.ko`.
- The local build emitted OpenBCM common-symbol modpost warnings for
  `___strtok` and `nodevices`; those warnings did not block module output.
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`

Next checkpoint:

- Load `linux-kernel-bde.ko` and `linux-user-bde.ko` on Redstone hardware.
- Confirm BCM56846 appears through BDE device nodes before starting any
  OpenBCM userland SDK init work.

### Stage-3 OpenBCM BDE Hardware Bundle

Completed:

- Added a `bundle` command to `scripts/build-openbcm-bde.sh` that copies the
  built OpenBCM BDE module pair into `output/openbcm-bde/`.
- The bundle writes `redstone-openbcm-bde.manifest` with the OpenBCM tree head,
  Redstone kernel release, target name, module metadata, optional hashes, and
  the hardware smoke-test load order.
- Wired `make openbcm-bde-bundle` into the top-level build system.
- Extended Redstone source preflight to keep the OpenBCM BDE bundle path
  visible as part of the stage-3 SDK proof trail.
- Documented that the bundle is a lab artifact and does not replace the
  default stage-1 image BDE modules until Redstone hardware proves load and
  BCM56846 enumeration.

Verified:

- `wsl sh -n scripts/build-openbcm-bde.sh`
- `wsl sh scripts/build-openbcm-bde.sh bundle`
- `wsl make openbcm-bde-bundle`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`

Next checkpoint:

- Copy `output/openbcm-bde/` to the Redstone bench system.
- Load `linux-kernel-bde.ko` first with `dma_size=4`, then
  `linux-user-bde.ko`.
- Capture `/dev/linux-*-bde`, `dmesg`, and `lspci -nn` evidence showing
  `14e4:b846` before starting any OpenBCM userland SDK init work.

### Stage-3 OpenBCM BDE Hardware Smoke Helper

Completed:

- Added `scripts/redstone-openbcm-bde-smoke.sh`, a device-side smoke helper for
  the OpenBCM BDE bundle.
- The helper loads `linux-kernel-bde.ko` with `dma_size=4`, then
  `linux-user-bde.ko`, checks `/dev/linux-*-bde`, captures focused module and
  `dmesg` output, and verifies BCM56846 as `14e4:b846` through `lspci` or PCI
  sysfs.
- The helper refuses to treat already loaded same-named BDE modules as OpenBCM
  proof unless `--reload-existing` is passed explicitly.
- Updated `scripts/build-openbcm-bde.sh bundle` so `output/openbcm-bde/`
  includes `redstone-openbcm-bde-smoke.sh` and records it in the manifest.
- Extended Redstone source preflight so the smoke helper must be present,
  shell-valid, copied by the bundle helper, and tracked executable.
- Updated the OpenBCM decision note and stage plan to make the hardware smoke
  command the next Redstone bench checkpoint.

Verified:

- `wsl sh -n scripts/redstone-openbcm-bde-smoke.sh`
- `wsl sh -n scripts/build-openbcm-bde.sh`
- `wsl sh scripts/build-openbcm-bde.sh bundle`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`

Next checkpoint:

- Copy `output/openbcm-bde/` to the Redstone bench system.
- Run `./redstone-openbcm-bde-smoke.sh --strict` before platform BDE modules
  are loaded, or stop `switchd` and run
  `./redstone-openbcm-bde-smoke.sh --reload-existing --strict` on a controlled
  bench system.
- Use the smoke evidence directory as the input for the next OpenBCM userland
  SDK init increment.

### Stage-3 OpenBCM BDE Smoke PCI-ID Specificity Fix

Completed:

- Tightened the BDE smoke helper `lspci` path so it only accepts the exact
  Broadcom BCM56846 PCI ID pair `14e4:b846`.
- Added Redstone preflight coverage to keep vendorless `b846` or `56846`
  `lspci` matches from satisfying the smoke helper.

Verified:

- `wsl sh -n scripts/redstone-openbcm-bde-smoke.sh`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- `git diff --check`
- Temporary `lspci` fixture with `[8086:b846] BCM56846 text` did not satisfy
  the `lspci` BCM56846 detection path.
- Temporary `lspci` fixture with `[14e4:b846]` satisfied the exact BCM56846
  detection path.

Next checkpoint:

- Run the OpenBCM BDE smoke helper on Redstone hardware and keep the evidence
  showing BDE load plus BCM56846 `14e4:b846` enumeration.
- Use that evidence as the prerequisite for any SDK-managed userland init or
  offload claim.

### Stage-3 OpenBCM Userland Init Source Preflight

Completed:

- Added `scripts/check-openbcm-userland-init.sh` to verify that the pinned
  OpenBCM 6.5.27 tree exposes BCM56846 SOC coverage, Linux BDE user/kernel
  entry points, and the OpenNSA demo `linux_bde_create` to `soc_attach` or
  `bcm_attach` to `bcm_init` path.
- The preflight also checks the public L2, VLAN, and port APIs needed for the
  next minimal SDK-managed data-path probe.
- Wired `make openbcm-userland-check` into the top-level build system.
- Extended Redstone source preflight so the userland init source check must be
  present, shell-valid, executable, and visible from the Makefile.
- Updated the OpenBCM decision note and stage plan to place this preflight
  before a Redstone-specific SDK init tool.

Verified:

- `wsl sh -n scripts/check-openbcm-userland-init.sh`
- `wsl sh scripts/check-openbcm-userland-init.sh`
- `wsl make openbcm-userland-check`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- `git diff --check`

Next checkpoint:

- Run the OpenBCM BDE hardware smoke helper on Redstone and keep the evidence
  showing BDE load plus BCM56846 `14e4:b846` enumeration.
- Implement the minimal Redstone OpenBCM init tool only after that hardware
  BDE smoke evidence exists.

### Stage-3 OpenBCM Userland BDE Path Review Fix

Completed:

- Updated `scripts/check-openbcm-userland-init.sh` so the user BDE source
  checks follow the repository's actual OpenBCM BDE build path:
  `systems/bde/linux/user/kernel/linux-user-bde.c`.
- Added the matching `linux-user-bde.h` check and replaced stale assumptions
  that the user BDE source implements `linux_bde_create` directly. The preflight
  now checks the actual OpenBCM 6.5.27 structure: user BDE `_init` attaches
  through the public kernel BDE `linux_bde_create`, cleanup destroys `user_bde`,
  and the `linux-user-bde` gmodule exposes the ioctl bridge.
- Updated the stage plan and OpenBCM decision note to name that user BDE source
  location and bridge structure explicitly.

Verified:

- `wsl sh -n scripts/check-openbcm-userland-init.sh`
- `wsl sh scripts/check-openbcm-userland-init.sh`
- `wsl make openbcm-userland-check`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- `git diff --check`

Next checkpoint:

- Run the OpenBCM BDE hardware smoke helper on Redstone and keep the evidence
  showing BDE load plus BCM56846 `14e4:b846` enumeration.
- Implement the minimal Redstone OpenBCM init tool only after that hardware
  BDE smoke evidence exists.

### Stage-3 OpenBCM BDE Smoke Evidence Analyzer

Completed:

- Added `scripts/analyze-redstone-openbcm-bde-smoke.sh` as a host-side analyzer
  for Redstone OpenBCM BDE smoke evidence directories or `.tar.gz` archives.
- The analyzer requires the smoke log to prove both OpenBCM BDE modules loaded
  from the bundle, both BDE device nodes exist, and BCM56846 is identified by
  the exact PCI ID `14e4:b846` or exact sysfs vendor/device IDs.
- Wired `make openbcm-bde-smoke-analyze` into the top-level Makefile with an
  explicit `OPENBCM_BDE_SMOKE_EVIDENCE=/path/to/evidence` input.
- Extended Redstone source preflight so the analyzer must be present,
  shell-valid, executable, and guarded against generic BCM56846 text matches.
- Updated the OpenBCM decision note and stage plan with the evidence-analysis
  workflow.

Verified:

- `wsl sh -n scripts/analyze-redstone-openbcm-bde-smoke.sh`
- `wsl sh -n scripts/check-redstone-stage1.sh`
- Temporary complete smoke evidence directory passed `--strict` analysis.
- Temporary complete smoke evidence tarball passed `--strict` analysis.
- `wsl make openbcm-bde-smoke-analyze` passed against complete smoke evidence.
- Temporary evidence missing user BDE bundle-load proof failed as expected.
- Temporary evidence with only `[8086:b846] BCM56846 text` failed as expected.
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- `git diff --check`

Next checkpoint:

- Run the OpenBCM BDE hardware smoke helper on Redstone and keep the evidence
  showing BDE load plus BCM56846 `14e4:b846` enumeration.
- Use analyzed BDE smoke evidence as the prerequisite for the first minimal
  Redstone SDK-managed init probe.

### Stage-3 Redstone OpenBCM Init Probe Gate

Completed:

- Added `asic/openbcm-init/redstone-openbcm-init-probe.c`, a target-side
  wrapper for gating the OpenBCM demo init binary behind Redstone-specific
  checks. It does not implement or copy Broadcom SDK logic.
- The probe defaults to `--dry-run`, checks both BDE device nodes, requires
  exact BCM56846 PCI ID `14e4:b846`, validates the Redstone BCM config path,
  and refuses `--exec` unless `--i-accept-hardware-reset-risk` is present.
- Added `scripts/build-openbcm-init-probe.sh` with `check`, `build`, `bundle`,
  `print-env`, and `clean` commands.
- Wired `make openbcm-init-probe-check`, `make openbcm-init-probe`, and
  `make openbcm-init-probe-bundle` into the top-level build system.
- Extended Redstone source preflight so the init probe source, build helper,
  Makefile targets, exact PCI ID gate, reset-risk gate, and `BCM_CONFIG_FILE`
  handoff are tracked.

Verified:

- `wsl sh -n scripts/build-openbcm-init-probe.sh`
- `wsl sh scripts/build-openbcm-init-probe.sh check`
- `wsl sh scripts/build-openbcm-init-probe.sh build`
- `wsl make openbcm-init-probe`
- `wsl make openbcm-init-probe-bundle`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- `git diff --check`

Next checkpoint:

- Package the probe into the Redstone rootfs, then deploy it with
  `redstone-stage1.bcm` and the BDE smoke bundle on the Redstone bench system.
- Run `./redstone-openbcm-init-probe --dry-run` first. Only run
  `./redstone-openbcm-init-probe --exec --i-accept-hardware-reset-risk` after
  strict BDE smoke evidence exists and the reset risk is accepted for the
  bench session.
- Treat a successful init probe as the start of the L2/VLAN/one-port link-up
  path, not as proof of L3/ACL/ECMP offload.

### Stage-3 Redstone OpenBCM Init Probe Rootfs Wiring

Completed:

- Added `scripts/install-openbcm-init-probe.sh` to install the built probe into
  a Redstone rootfs as `/usr/sbin/redstone-openbcm-init-probe` and, when
  available, its manifest under `/usr/share/edgenos/openbcm/`.
- Wired the installer into both `scripts/build-rootfs.sh assemble` and the
  Buildroot post-build hook. The installer is Redstone-only and remains
  optional unless `REQUIRE_OPENBCM_INIT_PROBE=1` is set.
- Extended `scripts/check-redstone-image.sh` so a packaged probe must be
  executable and must carry a manifest identifying `sdk_baseline=openbcm-6.5.27`.
- Extended first-boot capture and validation so the Redstone rootfs records
  `redstone-openbcm-init-probe --dry-run` output without running the risky
  `--exec` path.
- Tightened `redstone-stage1-validate` so the `lspci` path accepts only the
  exact BCM56846 PCI ID `14e4:b846`, matching the OpenBCM BDE smoke helper.

Verified:

- `wsl sh -n scripts/install-openbcm-init-probe.sh`
- `wsl sh -n scripts/check-redstone-image.sh`
- `wsl sh -n config/rootfs/overlay/usr/sbin/redstone-stage1-capture`
- `wsl sh -n config/rootfs/overlay/usr/sbin/redstone-stage1-validate`
- `wsl sh scripts/build-openbcm-init-probe.sh bundle`
- Installer skip/required-failure temp-rootfs checks for a missing probe binary.
- Installer temp-rootfs check with the built probe and
  `sdk_baseline=openbcm-6.5.27` manifest.
- `wsl env EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh assemble`
- `wsl env REQUIRE_OPENBCM_INIT_PROBE=1 sh scripts/check-redstone-image.sh`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- `git diff --check`

Next checkpoint:

- Build the installer image with the probe-bearing Redstone rootfs and keep the
  same forced image check in the release path.
- On hardware, run `redstone-stage1-validate --capture` and keep the dry-run
  evidence before attempting the reset-risk-gated `--exec` path.

### Stage-3 Redstone OpenBCM Init Probe Output Fix

Completed:

- Replaced the probe's literal `\n` output sequences with real newline escapes
  so `--help`, `--dry-run`, `--exec`, warnings, and failures remain readable and
  line-oriented.
- Rebuilt the probe bundle and reassembled the Redstone rootfs staging image so
  `/usr/sbin/redstone-openbcm-init-probe` carries the refreshed output strings.

Verified:

- `rg -n "\\\\n" asic/openbcm-init/redstone-openbcm-init-probe.c` returned no
  literal backslash-n output strings.
- `wsl sh -n scripts/build-openbcm-init-probe.sh`
- `wsl sh -n scripts/install-openbcm-init-probe.sh`
- `wsl sh scripts/build-openbcm-init-probe.sh build`
- `wsl sh scripts/build-openbcm-init-probe.sh bundle`
- `wsl env EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh assemble`
- `wsl env REQUIRE_OPENBCM_INIT_PROBE=1 sh scripts/check-redstone-image.sh`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- `strings output/openbcm-init/redstone-openbcm-init-probe | grep -F "\\n"`
  returned no literal backslash-n strings in the built probe.
- `git diff --check`

### Stage-3 Redstone Review Gate Fixes

Completed:

- Honored optional OpenBCM init probe packaging by requiring the probe manifest
  only when `REQUIRE_OPENBCM_INIT_PROBE=1`, while still validating it when an
  optional manifest is present.
- Tightened stage-1 evidence analysis so BCM56846 PCIe proof must be exact
  `14e4:b846` or exact sysfs `vendor=0x14e4 device=0xb846` evidence.
- Converted Redstone source preflight vendorless-ID guards to regex checks and
  added analyzer coverage for the exact BCM56846 PCI proof gate.

Verified:

- `wsl sh -n scripts/check-redstone-image.sh`
- `wsl sh -n scripts/analyze-redstone-stage1-evidence.sh`
- `wsl sh -n scripts/check-redstone-stage1.sh`
- Optional probe binary image check passes without a manifest when
  `REQUIRE_OPENBCM_INIT_PROBE` is not set.
- Negative evidence fixture with `[8086:b846] BCM56846 text only` fails exact
  BCM56846 PCI proof.
- Positive evidence fixture with `[14e4:b846] BCM56846` passes exact BCM56846
  PCI proof.
- `wsl env REQUIRE_OPENBCM_INIT_PROBE=1 sh scripts/check-redstone-image.sh`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- `git diff --check`

### Stage-3 Redstone Installer Image Gate

Completed:

- Extended `scripts/check-redstone-image.sh` to inspect either rootfs staging
  or packed `rootfs.sqsh` via `--squashfs`.
- Wired `scripts/build-installer.sh image` to verify Redstone `rootfs.sqsh`
  before creating the ONIE installer payload, defaulting
  `REQUIRE_OPENBCM_INIT_PROBE=1` for that release path.
- Wired `scripts/build-all.sh` to install the Redstone OpenBCM init probe
  before squashfs packing and to run the same packed-rootfs check before
  installer packaging.
- Extended `scripts/check-redstone-stage1.sh` so the release-path squashfs
  checks are covered by preflight.

Verified:

- `wsl sh -n scripts/check-redstone-image.sh`
- `wsl sh -n scripts/build-installer.sh`
- `wsl sh -n scripts/build-all.sh`
- `wsl sh -n scripts/check-redstone-stage1.sh`
- `wsl env REQUIRE_OPENBCM_INIT_PROBE=1 sh scripts/check-redstone-image.sh --squashfs output/images/rootfs.sqsh`
- `wsl env REQUIRE_OPENBCM_INIT_PROBE=1 sh scripts/check-redstone-image.sh`
- `wsl env EDGENOS_BOARD=redstone ./scripts/build-installer.sh image`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`

### Stage-3 Redstone PCI Guard Review Fix

Completed:

- Fixed the Redstone source preflight guard so it uses a real ERE to reject
  loose BCM56846 PCI matching expressions such as `14e4.*b846`,
  `b846|56846`, or standalone `56846` matches in source checks.
- Kept exact `14e4:b846` and exact sysfs `vendor=0x14e4 device=0xb846`
  evidence paths allowed.

Verified:

- `wsl sh -n scripts/check-redstone-stage1.sh`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- Targeted loose-regex fixtures for `grep -E '14e4.*(b846|56846)|b846|56846'`
  and `has_text '14e4.*b846|b846|56846|BCM56846'` match the guard, while
  exact `14e4:b846` fixture text does not.
- `git diff --check`

Next checkpoint:

- Copy `output/images/edgenos-redstone-stage1.bin` to the ONIE install host
  and boot it on Redstone.
- On hardware, run `redstone-stage1-validate --capture`, analyze the returned
  tarball, and only then consider the reset-risk-gated OpenBCM init probe
  `--exec` path.

### Stage-3 Redstone Hardware Handoff Package

Completed:

- Added `scripts/package-redstone-hardware-handoff.sh` and the top-level
  `make redstone-handoff` target.
- The package verifies the packed Redstone `rootfs.sqsh` with
  `REQUIRE_OPENBCM_INIT_PROBE=1` before copying handoff files.
- The handoff directory collects the ONIE installer image, packed rootfs, DTB,
  OpenBCM BDE modules and smoke helper, OpenBCM init probe bundle, and the
  host-side stage-1 evidence analyzer under `output/redstone-handoff/`.
- The package writes `RUNBOOK.md`, `MANIFEST.txt`, and
  `output/redstone-stage1-hardware-handoff.tar.gz`.
- Extended stage-1 preflight and the stage-1 plan so the hardware handoff
  package remains tracked by source checks and docs.

Verified:

- `wsl sh -n scripts/package-redstone-hardware-handoff.sh`
- `wsl env EDGENOS_BOARD=redstone sh scripts/package-redstone-hardware-handoff.sh`
- `wsl env EDGENOS_BOARD=redstone make redstone-handoff`
- `wsl sh -c "tar tzf output/redstone-stage1-hardware-handoff.tar.gz | head -n 40"`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- `git diff --check`
- `git diff --cached --check`

Next checkpoint:

- Transfer `output/redstone-stage1-hardware-handoff.tar.gz` to the ONIE/test
  host, or copy `output/redstone-handoff/images/edgenos-redstone-stage1.bin`
  directly to the ONIE install host.
- On Redstone hardware, install the image, run
  `redstone-stage1-validate --capture`, analyze the returned tarball with the
  bundled host analyzer, and only then consider the reset-risk-gated OpenBCM
  init probe `--exec` path.

### Stage-3 Redstone Strict Validation Gate

Completed:

- Tightened `redstone-stage1-validate --strict` so it is an acceptance gate
  rather than a loose smoke test.
- Strict mode now requires an explicit `--iface swpN` front-panel target and
  `--peer IP` before any hardware checks run.
- Strict mode rejects non-front-panel targets such as `eth0`, so the stage-1
  acceptance command cannot accidentally prove host networking instead of a
  Redstone `swp` link.
- Extended source preflight so the strict target requirements stay covered.
- Updated the stage-1 plan to document the difference between smoke validation
  and strict acceptance validation.

Verified:

- `wsl sh -n config/rootfs/overlay/usr/sbin/redstone-stage1-validate`
- `wsl sh -n scripts/check-redstone-stage1.sh`
- Missing `--iface` with `--strict` exits 2 and reports
  `strict requires --iface swpN`.
- Non-swp `--iface eth0` with `--strict` exits 2 and reports
  `strict --iface must be a swpN front-panel interface`.
- Missing `--peer` with `--strict --iface swp1` exits 2 and reports
  `strict requires --peer IP`.
- `--strict --iface swp1 --peer 192.0.2.2` passes argument validation and
  proceeds to hardware checks instead of exiting 2.
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`

Next checkpoint:

- Run the strict validator on Redstone hardware with the real bench interface
  and peer, then analyze the evidence bundle before attempting the reset-risk
  gated OpenBCM init probe `--exec` path.

### Stage-3 Redstone Handoff Runbook Acceptance Path

Completed:

- Updated the generated hardware handoff `RUNBOOK.md` so first-boot
  `redstone-stage1-validate --capture` is explicitly smoke/inventory evidence,
  not stage-1 acceptance.
- Added explicit bench placeholders for `REDSTONE_IFACE=swpN`,
  `REDSTONE_LOCAL_CIDR=192.0.2.1/24`, and `REDSTONE_PEER=192.0.2.2`.
- Made the handoff acceptance command use
  `redstone-stage1-validate --iface "$REDSTONE_IFACE" --peer "$REDSTONE_PEER" --strict --capture`.
- Extended source preflight so the generated runbook keeps that strict
  acceptance path.

Verified:

- `wsl sh -n scripts/package-redstone-hardware-handoff.sh`
- `wsl sh -n scripts/check-redstone-stage1.sh`
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- `wsl env EDGENOS_BOARD=redstone sh scripts/package-redstone-hardware-handoff.sh`
- `wsl env EDGENOS_BOARD=redstone make redstone-handoff`
- Generated `output/redstone-handoff/RUNBOOK.md` contains the
  non-acceptance smoke note, strict bench placeholders, and strict
  `redstone-stage1-validate --iface "$REDSTONE_IFACE" --peer "$REDSTONE_PEER" --strict --capture`
  command.
- The generated handoff tarball still contains `RUNBOOK.md`, `MANIFEST.txt`,
  and the bundled host evidence analyzer.
- `git diff --check`

Next checkpoint:

- Transfer `output/redstone-stage1-hardware-handoff.tar.gz` to the bench host,
  run the strict acceptance command from `RUNBOOK.md` on Redstone hardware, and
  analyze the returned capture tarball.

### Stage-3 Redstone Handoff Package Verifier

Completed:

- Added `scripts/verify-redstone-hardware-handoff.sh` so the generated handoff
  directory or tarball can be checked before use on the bench.
- The verifier checks `MANIFEST.txt`, Redstone board/image/DTB metadata,
  required handoff files, file sizes, SHA-256 hashes, and manifest coverage.
- The handoff package now bundles the verifier under `host-tools/` and the
  generated `RUNBOOK.md` runs it before strict host evidence analysis.
- Added `make redstone-handoff-verify REDSTONE_HANDOFF_PATH=...` for source-tree
  verification of a handoff directory or tarball.
- Extended source preflight so the verifier stays present, executable, bundled,
  and covered by the generated runbook.

Verified:

- `wsl env EDGENOS_BOARD=redstone sh scripts/package-redstone-hardware-handoff.sh`
- `wsl sh scripts/verify-redstone-hardware-handoff.sh output/redstone-handoff`
- `wsl sh scripts/verify-redstone-hardware-handoff.sh output/redstone-stage1-hardware-handoff.tar.gz`
- `wsl make redstone-handoff-verify REDSTONE_HANDOFF_PATH=output/redstone-stage1-hardware-handoff.tar.gz`
- Directory verification reported `46 pass, 0 warning(s), 0 failure(s)`.
- Tarball and make-target verification reported `47 pass, 0 warning(s), 0 failure(s)`.
- `wsl env EDGENOS_BOARD=redstone sh scripts/check-redstone-stage1.sh`
- `git diff --check`
- `git diff --cached --check`

Next checkpoint:

- Transfer `output/redstone-stage1-hardware-handoff.tar.gz` to the bench host,
  run `./host-tools/verify-redstone-hardware-handoff.sh .` after unpacking,
  then run the strict acceptance command from `RUNBOOK.md` on Redstone hardware.
- Feed the returned capture tarball to the bundled strict evidence analyzer
  before considering the reset-risk-gated OpenBCM init probe `--exec` path.
