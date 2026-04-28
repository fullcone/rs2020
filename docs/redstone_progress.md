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
- Documented that `redstone-stage1.dtb` still uses the AS5610 DTS source as a
  compatibility placeholder until Redstone hardware validation replaces it.

Verified:

- `bash -n` passes for the changed build scripts.
- `sh -n` passes for `scripts/board-env.sh`.
- `EDGENOS_BOARD=redstone` resolves to `redstone-stage1.dtb` and
  `edgenos-redstone-stage1.bin`.
- `git diff --check` passes.

Next checkpoint:

- Add a first-pass Redstone hardware inventory table for DTS work: I2C muxes,
  EEPROMs, CPLD/GPIO, fans, PSU, optics presence, and management Ethernet.
