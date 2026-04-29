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

## First-Boot Validation

The rootfs also includes `redstone-stage1-validate`, a non-destructive
acceptance check for the narrow stage-1 target. It records evidence under
`/var/log/redstone-stage1/validate-*` and checks:

- Redstone board selection.
- `redstone-stage1.bcm` presence and 52-port map coverage.
- packaged and loaded BDE modules.
- `/dev/linux-kernel-bde` and `/dev/linux-user-bde`.
- BCM56846 PCIe presence via `lspci` or sysfs device ID `14e4:b846`.
- `switchd` status and created `swp` interfaces.
- one front-panel link, plus ping reachability when a peer is provided.

For a first smoke test:

```sh
redstone-stage1-validate
```

For the stage-1 acceptance run, pass the interface and peer that are connected
on the bench. `--strict` is intentionally stricter than the smoke test: it
requires an explicit `--iface swpN` front-panel target and `--peer IP`, then
fails nonzero if any required check fails:

```sh
redstone-stage1-validate --iface swp1 --peer 192.0.2.2 --strict
```

Use `--capture` when the same run should also embed the larger
`redstone-stage1-capture` evidence and, when `tar` is available, print a
host-transfer validation bundle:

```sh
redstone-stage1-validate --iface swp1 --peer 192.0.2.2 --strict --capture
```

## Evidence Analysis

After a hardware run, copy the validation directory or validation bundle back to
the build host and run the evidence analyzer:

```sh
./scripts/analyze-redstone-stage1-evidence.sh /path/to/validate-20260429T000000Z
./scripts/analyze-redstone-stage1-evidence.sh /path/to/validate-20260429T000000Z.tar.gz
```

For an acceptance bundle, use `--strict`. Strict mode exits nonzero when
required Stage-1 evidence is missing, including a missing validation log or a
skipped ping:

```sh
./scripts/analyze-redstone-stage1-evidence.sh --strict /path/to/validate-20260429T000000Z
```

The analyzer is host-side only. It does not replace the live hardware run; it
turns the collected `validate-*` directory or validation bundle into a
repeatable PASS/WARN/FAIL checklist for board selection, BCM56846 PCIe
enumeration, BDE modules and device nodes, `switchd`, `swp` interfaces,
`swp*`-scoped link-up, and ping evidence. Embedded capture link evidence must
come from a `swp*` interface section or an `ip link` line for a `swp*`
interface, so a management `eth*` interface cannot satisfy the front-panel link
checkpoint.

Use the platform inventory analyzer on the same returned evidence before
starting DTS or board-driver edits:

```sh
./scripts/analyze-redstone-platform-inventory.sh /path/to/validate-20260429T000000Z.tar.gz
```

This second analyzer is advisory. It prints OBSERVED/PENDING rows for device
tree base facts, BCM56846 PCIe evidence, I2C, CPLD, hwmon, management Ethernet,
front-panel netdevs, optics, fans, PSU, and LEDs. Only OBSERVED rows should be
promoted into Redstone DTS or platform-driver claims.

## Source Preflight

Before spending time on a full Redstone rootfs or installer build, run the
source-tree preflight:

```sh
EDGENOS_BOARD=redstone ./scripts/check-redstone-stage1.sh
```

This verifies that the Redstone aliases resolve to `redstone-stage1.dtb` and
`edgenos-redstone-stage1.bin`, that the rootfs overlay contains the capture,
validation, and `switchd-init` scripts, that the host evidence analyzer is
tracked and executable, that the platform inventory analyzer is packaged, that
`switchd.service` uses the common init path, and
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

Build the external kernel modules required by `platform-init.sh` before
assembling the final rootfs:

```sh
EDGENOS_BOARD=redstone ./scripts/build-modules.sh build
```

This stage checks that the BDE, CPLD, and retimer modules were produced:

- `asic/bde/linux-kernel-bde.ko`
- `asic/bde/linux-user-bde.ko`
- `platform/cpld/accton_as5610_52x_cpld.ko`
- `platform/retimer/retimer_class.ko`
- `platform/retimer/ds100df410.ko`

The Redstone rootfs path has been verified with Buildroot 2023.02.9 on WSL.
Buildroot is extracted under `${XDG_CACHE_HOME:-$HOME/.cache}/edgenos/buildroot`
by default, or under `EDGENOS_BUILDROOT_WORKDIR` when that variable is set. Keep
that work tree on a Linux filesystem, not `/mnt/c`, because Buildroot rejects
case-insensitive source directories and inherited WSL paths with spaces can also
break its host-tool checks.

The checked-in `config/rootfs/buildroot_defconfig` remains the AS5610 default:
e500v2 CPU selection, Buildroot glibc, and systemd. `build-rootfs.sh` derives
the generated Buildroot `edgenos_defconfig` from that shared file for every
board, then applies the Redstone-only rootfs profile when
`EDGENOS_BOARD=redstone` is selected:

- `BR2_powerpc_8548=y`
- `BR2_powerpc_SPE=y`
- `BR2_TOOLCHAIN_BUILDROOT_UCLIBC=y`
- `BR2_INIT_BUSYBOX=y`

This keeps the default AS5610 build on its systemd unit activation path while
letting Redstone use the uClibc/SPE profile needed for the P2020 stage-1 rootfs.
To inspect the generated board defconfig without running a full Buildroot
compile:

```sh
EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh defconfig
```

```sh
EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh download
EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh build
EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh assemble
```

After assembly, verify the generated staging tree contains the stage-1 runtime
pieces that will go into `rootfs.sqsh`:

```sh
EDGENOS_BOARD=redstone ./scripts/check-redstone-image.sh
REQUIRE_OPENBCM_INIT_PROBE=1 ./scripts/check-redstone-image.sh --squashfs output/images/rootfs.sqsh
```

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

The Redstone installer packaging path has been verified from the Redstone
kernel and rootfs outputs with:

```sh
EDGENOS_BOARD=redstone ./scripts/build-installer.sh fit
EDGENOS_BOARD=redstone ./scripts/build-installer.sh image
```

For Redstone, `build-installer.sh image` checks `output/images/rootfs.sqsh`
before creating the ONIE payload tarball. The normal image build keeps the
OpenBCM init probe optional so `EDGENOS_BOARD=redstone make image` is not
blocked by missing optional probe artifacts. Release or handoff gates that need
the probe must run with `REQUIRE_OPENBCM_INIT_PROBE=1`.

`initramfs-build.sh` compiles `initramfs/nos-init.c` as a freestanding
PowerPC raw-syscall init because that source defines `_start` directly and does
not link against libc startup files. The script uses `-nostdlib`,
`-nostartfiles`, `-nodefaultlibs`, and explicit `-lgcc`; the same flags are used
by the Docker fallback path.

Verified Redstone installer outputs:

- `initramfs.cpio.gz`
- `output/images/nos.its`
- `output/images/uImage-powerpc.itb`
- `output/images/payload.tar`
- `output/images/edgenos-redstone-stage1.bin`

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

Seed the public SDK source under the ignored build tree before starting SDK
proof work:

```sh
./scripts/prepare-openbcm.sh fetch
./scripts/prepare-openbcm.sh check
```

The default seed is pinned to OpenBCM commit
`6d2330ce1b4fc49d681cffcf09af408661be4c62` and sparse-checks out
`sdk-6.5.27` under `build/openbcm/OpenBCM/`. The `check` command only proves
that the source baseline has expected BCM56846, Trident, Linux BDE, L3, and FP
source evidence. It does not prove a Redstone hardware offload path.

After the Redstone Linux 5.10.224 kernel tree has been built, compile the
OpenBCM Linux BDE probe modules:

```sh
./scripts/build-openbcm-bde.sh check
./scripts/build-openbcm-bde.sh all
```

or through the top-level build target:

```sh
make openbcm-bde
make openbcm-bde-bundle
```

The helper writes an ignored generated target file under
`build/openbcm/OpenBCM/sdk-6.5.27/make/Makefile.linux-redstone-5_10`, then
copies the BDE sources into ignored temporary Kbuild module directories under
`build/openbcm/redstone-bde/`. The expected outputs are
`build/openbcm/redstone-bde/linux-kernel-bde.ko` and
`build/openbcm/redstone-bde/linux-user-bde.ko`. The bundle target copies those
modules into `output/openbcm-bde/` with `redstone-openbcm-bde-smoke.sh` and
`redstone-openbcm-bde.manifest`, which records the OpenBCM head, Redstone
kernel release, module metadata, and the hardware smoke-test command:

```sh
./redstone-openbcm-bde-smoke.sh --strict
```

The smoke helper writes a timestamped evidence directory under
`/var/log/redstone-stage1/`, checks the BDE character devices, captures focused
module and `dmesg` output, and verifies BCM56846 through the exact
`14e4:b846` PCI ID pair from `lspci` or PCI sysfs. If same-named BDE modules
are already loaded from the default stage-1 image, the helper fails by default;
stop `switchd` and pass
`--reload-existing` when intentionally replacing the in-image BDE modules with
the OpenBCM bundle on a bench system.

After copying the smoke evidence back to the build host, run the host-side
analyzer:

```sh
./scripts/analyze-redstone-openbcm-bde-smoke.sh --strict /path/to/openbcm-bde-smoke-20260429T000000Z
make openbcm-bde-smoke-analyze OPENBCM_BDE_SMOKE_EVIDENCE=/path/to/openbcm-bde-smoke-20260429T000000Z
```

The analyzer requires the smoke log to show the two OpenBCM BDE modules loaded
from the bundle, the `linux-kernel-bde` and `linux-user-bde` device nodes, and
an exact BCM56846 PCI ID of `14e4:b846`. It deliberately does not accept generic
`b846` or `56846` text as device proof.

This is a build and packaging proof only; hardware loading, BCM56846
enumeration through BDE, and any SDK-managed switching/offload still require
Redstone hardware validation.

Before writing a Redstone-specific OpenBCM init tool, verify that the pinned
public SDK tree still exposes the expected userland init path and first L2/VLAN
APIs:

```sh
./scripts/check-openbcm-userland-init.sh
make openbcm-userland-check
```

This checks BCM56846 SOC coverage, Linux BDE user/kernel entry points
including `systems/bde/linux/user/kernel/linux-user-bde.c`, the user BDE
`_init` attach through the public kernel BDE `linux_bde_create`, the
`linux-user-bde` gmodule/ioctl bridge, the OpenNSA demo `linux_bde_create` to
`soc_attach` or `bcm_attach` to `bcm_init` path, and public L2, VLAN, and port
APIs. It is a source/API preflight only; it does not load hardware or prove
offload.

The Redstone-specific init probe wrapper can be built before bench hardware is
available:

```sh
./scripts/build-openbcm-init-probe.sh check
./scripts/build-openbcm-init-probe.sh build
make openbcm-init-probe
make openbcm-init-probe-bundle
```

This wrapper is a safety gate around the OpenBCM demo init binary. Its default
`--dry-run` path checks the BDE device nodes, exact BCM56846 PCI ID
`14e4:b846`, and Redstone BCM config readability. Its `--exec` path remains
blocked unless `--i-accept-hardware-reset-risk` is passed on a bench system
after strict BDE smoke evidence exists. It does not implement SDK init logic
or prove switching/offload by itself.

When `output/openbcm-init/redstone-openbcm-init-probe` exists, Redstone rootfs
assembly installs it as `/usr/sbin/redstone-openbcm-init-probe` and installs
the generated manifest under `/usr/share/edgenos/openbcm/`. This packaging is
Redstone-only and optional by default:

```sh
EDGENOS_BOARD=redstone ./scripts/build-rootfs.sh assemble
REQUIRE_OPENBCM_INIT_PROBE=1 ./scripts/check-redstone-image.sh
REQUIRE_OPENBCM_INIT_PROBE=1 ./scripts/check-redstone-image.sh --squashfs output/images/rootfs.sqsh
```

`build-installer.sh image` uses the same packed-rootfs Redstone image check
before packaging, but leaves the init probe optional unless
`REQUIRE_OPENBCM_INIT_PROBE=1` is explicitly exported. `build-all.sh` also
installs the Redstone OpenBCM init probe into the rootfs staging tree before
squashfs packing, so its generated `rootfs.sqsh` is checked rather than only
the pre-pack staging directory.

The first-boot capture and validation tools record the probe's `--dry-run`
output. They do not run `--exec`; that remains a manual bench step after BDE
smoke evidence exists.

The original Redstone firmware evidence points to Broadcom XGS Robo SDK 5.10.2.
That makes SDK 5.10.x the best compatibility reference for board facts, PHY
setup expectations, and regression triage. If an authorized SDK 5.10.x tree is
available, it remains the lowest-risk way to compare Redstone-specific behavior.

## Hardware Handoff Package

Once the Redstone installer, packed rootfs, DTB, OpenBCM BDE bundle, and
OpenBCM init probe bundle exist, build the bench handoff set with:

```sh
EDGENOS_BOARD=redstone make redstone-handoff
```

The target writes `output/redstone-handoff/` and
`output/redstone-stage1-hardware-handoff.tar.gz`. The package includes the
ONIE installer image, `rootfs.sqsh`, Redstone DTB, OpenBCM BDE modules and
smoke helper, OpenBCM init probe bundle, the host-side stage-1 evidence
analyzer, the combined host handoff/capture analyzer, the host-side platform
inventory analyzer, the host-side handoff verifier, the bench result template
under `bench-results/`, `RUNBOOK.md`, and `MANIFEST.txt` with sizes and SHA-256
hashes.

The package script forces the packed-rootfs image check with
`REQUIRE_OPENBCM_INIT_PROBE=1`, so it fails before handoff if the stage-1
rootfs does not contain the Redstone OpenBCM init probe and manifest.

The generated `RUNBOOK.md` separates first-boot smoke capture from acceptance:
`redstone-stage1-bench-run --capture-only` is inventory evidence only.
Stage-1 acceptance requires a real front-panel target and peer, using
placeholders such as `REDSTONE_IFACE=swpN`,
`REDSTONE_LOCAL_CIDR=192.0.2.1/24`, and `REDSTONE_PEER=192.0.2.2`, then
running `redstone-stage1-bench-run --iface "$REDSTONE_IFACE" --local-cidr "$REDSTONE_LOCAL_CIDR" --peer "$REDSTONE_PEER"`.
The bench runner preserves the validator output, parses the returned
`Validation bundle:` or `Evidence directory:` line, and prints the exact
`host-tools/analyze-redstone-handoff-capture.sh` command to run on the host.
The package also includes
`bench-results/REDSTONE-BENCH-RESULT-TEMPLATE.md` and
`host-tools/prepare-redstone-bench-note.sh`; run the helper for each bench run
to create a timestamped note in a results directory outside the verified
handoff package, then keep the completed note beside the returned strict
validation bundle and console log. The helper refuses result directories inside
an unpacked handoff directory, because the manifest verifier rejects files that
are not listed in `MANIFEST.txt`.
Before using an unpacked handoff directory on the bench host, run
`./host-tools/verify-redstone-hardware-handoff.sh .` from the package root, or
verify the tarball from the source tree with:

```sh
make redstone-handoff-verify REDSTONE_HANDOFF_PATH=output/redstone-stage1-hardware-handoff.tar.gz
```

After the Redstone hardware run returns a strict validation bundle, verify the
handoff and analyze the validation evidence together from the unpacked package:

```sh
./host-tools/analyze-redstone-handoff-capture.sh . PATH_TO_VALIDATION_BUNDLE_OR_DIR
```

The same combined check is available from the source tree:

```sh
make redstone-handoff-analyze REDSTONE_HANDOFF_PATH=output/redstone-stage1-hardware-handoff.tar.gz REDSTONE_CAPTURE_PATH=/path/to/validate-20260429T000000Z.tar.gz
```

The combined check resolves its verifier and analyzer from the directory that
contains the wrapper: `host-tools/` in an unpacked handoff package, or
`scripts/` in the source tree. A handoff tarball passed through
`REDSTONE_HANDOFF_PATH` is input data only; it is never used as the source of
executable host tools. The combined check verifies the handoff manifest and
hashes first, then runs the strict stage-1 evidence analyzer against the
returned validation evidence. It then runs the platform inventory analyzer so
the same returned evidence produces a DTS/platform follow-up matrix.

This is handoff material for the stage-1 bench run only. It still does not
prove L3 routing, ACL, ECMP, or production offload. The init probe `--exec`
path remains reset-risk-gated and should only run after strict OpenBCM BDE
smoke evidence exists on Redstone hardware.

## Stage Plan

### Stage 1: Minimal Data Path

- Build kernel/rootfs with Redstone board selection and Redstone switchd config.
- Keep the Redstone DTS marked as a stage-1 skeleton until hardware validation
  proves the board wiring.
- Load BDE and detect BCM56846.
- Start switchd with `redstone-stage1.bcm`.
- Verify one 10G SFP+ port or one 40G QSFP+ port links up.
- Assign test IPs and pass one ping through the ASIC.
- Run `redstone-stage1-bench-run --iface <swpN> --local-cidr <local-cidr> --peer <peer-ip>`.
- Keep the printed strict validation bundle with the hardware test notes for
  follow-up DTS and platform work.
- Complete the packaged bench result template so the accept/reject decision is
  explicit for that hardware run, and store the completed note outside the
  verified handoff package.

### Stage 2: Platform Inventory

- Add Redstone DTS coverage for I2C muxes, EEPROM, CPLD/GPIO, fans, thermal,
  PSU, and front-panel optical cages.
- Start from the original `p2020rdb.dtb` facts recorded in
  `docs/redstone_hardware_inventory.md`.
- Run `analyze-redstone-platform-inventory.sh` against the returned validation
  bundle and promote only OBSERVED rows into DTS or driver work.
- Map Redstone LED and transceiver-present behavior.
- Keep these changes independent from Broadcom SDK integration.

### Stage 3: SDK Proof

- Use OpenBCM 6.5.27 as the primary open SDK proof target.
- Keep OpenBCM 6.5.27 as an ignored generated source seed from
  `scripts/prepare-openbcm.sh`; do not vendor SDK source into this fork.
- Use SDK 5.10.x-era evidence as the compatibility reference because it matches
  the original Redstone firmware lineage.
- Prove the OpenBCM 6.5.27 BDE kernel modules and userland build for Linux 5.10
  and PowerPC32 big-endian before relying on it for production hardware
  programming.
- Keep OpenBCM BDE hardware-smoke bundles under `output/openbcm-bde/` until the
  smoke helper has loaded the bundle modules on Redstone and BCM56846
  enumeration is captured.
- Pass the OpenBCM userland init source preflight and build the Redstone init
  probe gate. Package it into the Redstone rootfs for dry-run capture, but only
  run its `--exec` path after hardware BDE smoke evidence exists and reset-risk
  acceptance is explicit for that bench session.
- Do not claim L3/ACL/ECMP hardware offload until SDK APIs are integrated and
  verified on hardware.

### Stage 4: NOS Services

- Integrate FRR or an equivalent routing stack only after the ASIC programming
  layer can install L2/L3/ACL state into hardware.
- Add tests around route installation, neighbor programming, ACL entries, and
  ECMP hashing once those APIs exist.
