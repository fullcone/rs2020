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
