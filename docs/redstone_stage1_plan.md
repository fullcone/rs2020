# Redstone Stage-1 Bring-Up Plan

## Goal

Build a Redstone-specific EdgeNOS path without claiming a complete NOS yet.
The first acceptance target is deliberately narrow:

1. boot a Linux 5.10-based image on Redstone,
2. enumerate the BCM56846 on PCIe,
3. start BDE and switchd,
4. bring up one front-panel port,
5. pass one ICMP ping through the ASIC data path.

L3 routing, ACL/FP, ECMP, and production hardware offload are out of scope for
stage 1.

## What This Adds

`config/bcm/redstone-stage1.bcm` contains a Redstone port map for the 48x10G +
4x40G BCM56846 layout. The file is not installed as the default
`/etc/switchd/config.bcm`; the existing AS5610 default remains unchanged.

To build a rootfs that selects it at boot:

```sh
EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh assemble
```

To build Redstone-named kernel and installer artifacts:

```sh
EDGENOS_BOARD=redstone ./scripts/build-kernel.sh download
EDGENOS_BOARD=redstone ./scripts/build-kernel.sh build
EDGENOS_BOARD=redstone ./scripts/build-installer.sh fit
EDGENOS_BOARD=redstone ./scripts/build-installer.sh image
```

Expected Redstone stage-1 outputs:

- `output/kernel/redstone-stage1.dtb`
- `output/images/edgenos-redstone-stage1.bin`

The Redstone DTB now comes from `kernel/dts/redstone-stage1.dts`, a stage-1
skeleton derived from the extracted original Redstone `p2020rdb.dtb` facts. The
build surface is Redstone-specific, but the DTS is not yet hardware-validated.
The FIT config name intentionally stays `accton_as5610_52x` because the current
installer and U-Boot boot command still select `bootm ...#accton_as5610_52x`.

The first-pass hardware inventory for extending that skeleton lives in
`docs/redstone_hardware_inventory.md`. Treat that document as the source of
truth for what has been extracted from Redstone evidence versus what is still
an AS5610-derived platform placeholder.

To select it on an already-running image:

```sh
mkdir -p /etc/edgenos
echo redstone > /etc/edgenos/board
systemctl restart switchd
journalctl -u switchd -f
```

`switchd.service` runs through `switchd-init`, which chooses
`/etc/switchd/redstone-stage1.bcm` when `/etc/edgenos/board` or
`EDGENOS_BOARD` is `redstone`, `rs2020`, or `r0678`.

`switchd` now accepts both config key styles:

- `portmap_N.0=lane:speed`, used by the current AS5610 config.
- `portmap_N=lane:speed`, used by Broadcom SDK-style board configs.

## First-Boot Capture

The rootfs includes `redstone-stage1-capture` for the first hardware boot. It
collects the board selector, device-tree properties, dmesg, PCI, network, BDE,
switchd, EEPROM, CPLD, and hwmon evidence into `/var/log/redstone-stage1/`.
The default mode avoids active I2C probing:

```sh
redstone-stage1-capture
```

On a bench system, after confirming it is safe to touch all discovered I2C
buses, collect an active scan as well:

```sh
redstone-stage1-capture --scan-i2c
```

Use the resulting tarball as the input for DTS and platform-driver changes.
Do not promote pending Redstone assumptions to final board facts without this
kind of live hardware output. The capture script follows `/sys/class` symlinks
when collecting EEPROM, CPLD, and hwmon evidence, because those class entries
normally point into real device directories.

## Source Preflight

Before spending time on a full Redstone rootfs or installer build, run the
source-tree preflight:

```sh
EDGENOS_BOARD=redstone ./scripts/check-redstone-stage1.sh
```

This verifies that the Redstone aliases resolve to `redstone-stage1.dtb` and
`edgenos-redstone-stage1.bin`, that the rootfs overlay contains the capture and
`switchd-init` scripts, that `switchd.service` uses the common init path, and
that `redstone-stage1.bcm` still exposes 52 front-panel port mappings. If `dtc`
is installed, the script also compiles the Redstone DTS skeleton.

The kernel source download and extraction path is generated under `build/` and
is intentionally ignored by git. To seed the Linux 5.10 source tree and install
the selected Redstone DTS before a kernel build:

```sh
EDGENOS_BOARD=redstone ./scripts/build-kernel.sh download
```

## Build Verification

On WSL/Ubuntu, install the PowerPC toolchain and kernel host build tools:

```sh
sudo apt-get update
sudo apt-get install -y gcc-powerpc-linux-gnu binutils-powerpc-linux-gnu make flex bison bc device-tree-compiler u-boot-tools cpio unzip squashfs-tools
```

Clone OpenMDK into the expected local path:

```sh
git clone https://github.com/Broadcom-Network-Switching-Software/OpenMDK.git asic/openmdk
git -C asic/openmdk checkout db9c678696800d1ebb8d331cb462acde85c31ffb
```

Build the OpenMDK static libraries and switch daemon:

```sh
make openmdk
make switchd
file asic/switchd/switchd
```

The stage-1 branch has been verified to build `asic/switchd/switchd` as an
ELF32 big-endian PowerPC static executable with `powerpc-linux-gnu-gcc` 13.3.0.
That verifies the local build path only; it does not replace Redstone hardware
testing.

The Redstone-selected kernel path has also been verified on WSL/Ubuntu with:

```sh
EDGENOS_BOARD=redstone ./scripts/build-kernel.sh build
```

That build produces `output/kernel/uImage`,
`output/kernel/redstone-stage1.dtb`, and `output/kernel/vmlinux`. The kernel
build script refreshes `olddefconfig` before compiling so an interrupted or
stale `.config` cannot force an interactive `syncconfig` prompt during the real
build.

The Redstone rootfs path has been verified with Buildroot 2023.02.9 on WSL.
Buildroot is extracted under `${XDG_CACHE_HOME:-$HOME/.cache}/edgenos/buildroot`
by default, or under `EDGENOS_BUILDROOT_WORKDIR` when that variable is set. Keep
that work tree on a Linux filesystem, not `/mnt/c`, because Buildroot rejects
case-insensitive source directories and inherited WSL paths with spaces can also
break its host-tool checks.

```sh
EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh download
EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh build
EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh assemble
```

The current Redstone stage-1 rootfs intentionally uses:

- `BR2_powerpc_8548=y`
- `BR2_powerpc_SPE=y`
- `BR2_TOOLCHAIN_BUILDROOT_UCLIBC=y`
- `BR2_INIT_BUSYBOX=y`

Buildroot 2023.02 does not offer glibc for `BR2_powerpc_SPE`, and systemd
depends on glibc in that release. For stage 1, Redstone therefore boots through
BusyBox init. `/etc/init.d/S20edgenos` starts `platform-init.sh` and then runs
`switchd-init start`, so the same Redstone board-selection logic is used on the
minimal rootfs. The systemd unit files remain in the overlay for a future
non-SPE or non-Buildroot path, but they are not active in this rootfs profile.

Verified Redstone rootfs outputs:

- `output/rootfs/rootfs.tar`
- `output/rootfs/rootfs.squashfs`
- `output/images/rootfs.sqsh`

## SDK Direction

The open SDK track is OpenBCM 6.5.27. That gives the Redstone fork a public,
auditable baseline instead of depending on private Broadcom SDK artifacts for
new code. OpenBCM 6.5.27 contains BCM56846 device IDs, Trident driver code, L3
APIs, Field Processor APIs, and Linux BDE code with some Linux 5.x
compatibility.

This decision does not make OpenBCM 6.5.27 a stage-1 dependency. It also does
not prove that OpenBCM 6.5.27 is already a drop-in fit for EdgeNOS on a
P2020/PowerPC32 big-endian target. That proof requires building and loading the
BDE modules and userland on Redstone hardware.

The original Redstone firmware evidence points to Broadcom XGS Robo SDK 5.10.2.
That makes SDK 5.10.x the best compatibility reference for board facts, PHY
setup expectations, and regression triage. If an authorized SDK 5.10.x tree is
available, it remains the lowest-risk way to compare Redstone-specific behavior.

## Stage Plan

### Stage 1: Minimal Data Path

- Build kernel/rootfs with Redstone board selection and Redstone switchd config.
- Keep the Redstone DTS marked as a stage-1 skeleton until hardware validation
  proves the board wiring.
- Load BDE and detect BCM56846.
- Start switchd with `redstone-stage1.bcm`.
- Verify one 10G SFP+ port or one 40G QSFP+ port links up.
- Assign test IPs and pass one ping through the ASIC.
- Run `redstone-stage1-capture` and keep the tarball with the hardware test
  notes for follow-up DTS and platform work.

### Stage 2: Platform Inventory

- Add Redstone DTS coverage for I2C muxes, EEPROM, CPLD/GPIO, fans, thermal,
  PSU, and front-panel optical cages.
- Start from the original `p2020rdb.dtb` facts recorded in
  `docs/redstone_hardware_inventory.md`.
- Map Redstone LED and transceiver-present behavior.
- Keep these changes independent from Broadcom SDK integration.

### Stage 3: SDK Proof

- Use OpenBCM 6.5.27 as the primary open SDK proof target.
- Use SDK 5.10.x-era evidence as the compatibility reference because it matches
  the original Redstone firmware lineage.
- Prove the OpenBCM 6.5.27 BDE kernel modules and userland build for Linux 5.10
  and PowerPC32 big-endian before relying on it for production hardware
  programming.
- Do not claim L3/ACL/ECMP hardware offload until SDK APIs are integrated and
  verified on hardware.

### Stage 4: NOS Services

- Integrate FRR or an equivalent routing stack only after the ASIC programming
  layer can install L2/L3/ACL state into hardware.
- Add tests around route installation, neighbor programming, ACL entries, and
  ECMP hashing once those APIs exist.
