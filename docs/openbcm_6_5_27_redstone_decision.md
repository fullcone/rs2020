# OpenBCM 6.5.27 Decision for Redstone

## Decision

Use OpenBCM 6.5.27 as the primary open SDK baseline for the Redstone fork.

This is a source and integration target, not a claim that OpenBCM 6.5.27 is
already hardware-proven on Redstone. Stage 1 remains independent of OpenBCM and
continues to target boot, BCM56846 detection, one port link-up, and one ping.

## Source Seed

The Redstone fork keeps OpenBCM as a generated source input, not vendored SDK
code. The default source seed is pinned to OpenBCM commit
`6d2330ce1b4fc49d681cffcf09af408661be4c62` and sparse-checks out only
`sdk-6.5.27` under the ignored `build/openbcm/` tree.

```sh
./scripts/prepare-openbcm.sh fetch
./scripts/prepare-openbcm.sh check
./scripts/prepare-openbcm.sh print-env
```

`OPENBCM_REF`, `OPENBCM_REPO_URL`, `OPENBCM_VERSION`, and
`OPENBCM_WORKDIR` can be overridden for intentional refreshes or local mirrors,
but refreshes should be explicit commits because the SDK source seed is part of
the proof trail.

## BDE Build Probe

The first Redstone OpenBCM build proof is the Linux BDE module pair, built
against the generated Linux 5.10.224 Redstone kernel tree with a PowerPC
big-endian cross toolchain:

```sh
./scripts/build-openbcm-bde.sh check
./scripts/build-openbcm-bde.sh all
```

The helper generates an ignored OpenBCM target file,
`build/openbcm/OpenBCM/sdk-6.5.27/make/Makefile.linux-redstone-5_10`, then
copies the BDE sources into ignored temporary Kbuild module directories under
`build/openbcm/redstone-bde/`. This avoids the legacy OpenBCM SDK-side
precompile path and lets the Redstone Linux kernel build system compile the
module objects directly. The expected probe outputs are:

- `build/openbcm/redstone-bde/linux-kernel-bde.ko`
- `build/openbcm/redstone-bde/linux-user-bde.ko`

Create the hardware-load bundle after both modules exist:

```sh
./scripts/build-openbcm-bde.sh bundle
```

or through the top-level target:

```sh
make openbcm-bde-bundle
```

The bundle is written to `output/openbcm-bde/` by default and contains:

- `linux-kernel-bde.ko`
- `linux-user-bde.ko`
- `redstone-openbcm-bde-smoke.sh`
- `redstone-openbcm-bde.manifest`

The manifest records the OpenBCM tree head, target name, Redstone kernel
release, module sizes, optional hashes, and the first hardware smoke-test
command. The smoke helper loads the bundle modules in order, checks
`/dev/linux-*-bde`, captures focused `dmesg`, and verifies BCM56846 through
the exact `14e4:b846` PCI ID pair from `lspci` or PCI sysfs.

Run the helper from the bundle directory on a bench Redstone system:

```sh
./redstone-openbcm-bde-smoke.sh --strict
```

Then copy the smoke evidence directory back to the build host and verify it:

```sh
./scripts/analyze-redstone-openbcm-bde-smoke.sh --strict /path/to/openbcm-bde-smoke-20260429T000000Z
make openbcm-bde-smoke-analyze OPENBCM_BDE_SMOKE_EVIDENCE=/path/to/openbcm-bde-smoke-20260429T000000Z
```

The analyzer requires bundle-loaded OpenBCM BDE module proof, both BDE device
nodes, and an exact BCM56846 PCI identity of `14e4:b846` before the evidence can
unlock a Redstone SDK-managed init probe.

If the default stage-1 image has already loaded its in-image BDE modules, stop
`switchd` and run the helper with explicit replacement:

```sh
switchd-init stop
./redstone-openbcm-bde-smoke.sh --reload-existing --strict
```

Without `--reload-existing`, the helper fails instead of treating already
loaded same-named BDE modules as OpenBCM proof. This bundle is still a lab
artifact; it is not installed into the default stage-1 image until Redstone
hardware proves the OpenBCM BDE modules can load and enumerate BCM56846.

This probe has been built locally with `powerpc-linux-gnu-gcc` against the
Redstone Linux 5.10.224 tree. It proves only that the public OpenBCM BDE code
can be compiled for the current Redstone Linux 5.10/PPC32 target. It does not
prove that the modules load on Redstone hardware, that BCM56846 is reachable
through the BDE device nodes, or that SDK-managed switching/offload is working.

## Userland Init Source Preflight

After the source seed and BDE build proof, the next non-hardware check is the
userland SDK init source/API preflight:

```sh
./scripts/check-openbcm-userland-init.sh
make openbcm-userland-check
```

This checks the pinned OpenBCM tree for BCM56846 SOC coverage, Linux BDE
user/kernel entry points including `systems/bde/linux/user/kernel/linux-user-bde.c`,
the user BDE `_init` attach through the public kernel BDE `linux_bde_create`,
the `linux-user-bde` gmodule/ioctl bridge, the OpenNSA demo init path from
`bde_create` to `linux_bde_create`, `soc_attach` or `bcm_attach`, and
`bcm_init`, plus public L2, VLAN, and port APIs needed for the first
SDK-managed data-path probe.

This is still a source-tree check. It does not load the BDE modules, initialize
BCM56846, program PHYs, or prove hardware offload.

## Redstone Init Probe Gate

The next source-side artifact is a Redstone wrapper around the OpenBCM demo
init binary:

```sh
./scripts/build-openbcm-init-probe.sh check
./scripts/build-openbcm-init-probe.sh build
make openbcm-init-probe
make openbcm-init-probe-bundle
```

The wrapper builds to `output/openbcm-init/redstone-openbcm-init-probe` and is
intentionally conservative. On target, start with:

```sh
./redstone-openbcm-init-probe --dry-run
```

The dry run checks the BDE device nodes, exact BCM56846 PCI ID `14e4:b846`,
and `BCM_CONFIG_FILE` readability. It does not initialize the ASIC. The actual
execution path is:

```sh
./redstone-openbcm-init-probe --exec --i-accept-hardware-reset-risk
```

Run that only after strict OpenBCM BDE smoke evidence exists on the Redstone
bench system. The wrapper sets `BCM_CONFIG_FILE` and execs the OpenBCM demo
init binary, but it is not itself a Broadcom SDK implementation and does not
prove L2, L3, ACL, ECMP, or hardware offload.

For Redstone rootfs builds, the probe is packaged only when the built binary is
present under `output/openbcm-init/`. The helper
`scripts/install-openbcm-init-probe.sh` installs it and its manifest into the
rootfs, and `REQUIRE_OPENBCM_INIT_PROBE=1 ./scripts/check-redstone-image.sh`
can make that packaging mandatory for lab images. First-boot capture and
validation record `redstone-openbcm-init-probe --dry-run` evidence only; they
do not call the reset-risk-gated execution path.

## Why 6.5.27

The local OpenBCM 6.5.27 tree has the pieces a Redstone SDK proof needs:

- BCM56846 PCI device ID coverage in the Linux kernel BDE path.
- BCM56846 constants in public SOC device headers.
- Trident driver and memory-configuration entry points.
- L3 route APIs, L3 egress APIs, and Field Processor APIs.
- Linux BDE code with some Linux 5.x compatibility changes.

That makes it the best public baseline to audit, patch, and discuss in a fork.

## What It Does Not Prove

OpenBCM 6.5.27 still needs a real build-and-boot proof for this target:

- CPU: P2020, PowerPC32, big-endian.
- Kernel: Linux 5.10.x.
- ASIC: BCM56846 / Trident+.
- Board: Redstone front-panel, external PHY, polarity, I2C, CPLD, and thermal
  layout.

Until that proof exists, OpenBCM 6.5.27 should not be used to claim production
L3 routing, ACL, ECMP, or full hardware offload.

## Role of SDK 5.10.x Evidence

The original Redstone firmware points to Broadcom XGS Robo SDK 5.10.2. That
older SDK line remains the compatibility reference for:

- board properties and port mapping,
- PHY address and lane expectations,
- polarity and MDI quirks,
- startup script behavior,
- diagnosing differences when OpenBCM 6.5.27 behaves differently.

Do not copy proprietary SDK implementation code into this fork. Treat SDK
5.10.x evidence as compatibility evidence unless an authorized source tree is
available for a separate private build.

## Required Proof Before Offload Claims

Before saying the Redstone fork has hardware offload through OpenBCM 6.5.27:

1. Build BDE kernel modules for Linux 5.10 and PowerPC32 big-endian.
2. Bundle the built BDE modules with their manifest for hardware smoke testing.
3. Run the bundle smoke helper on Redstone and enumerate BCM56846.
4. Pass the userland init source preflight against the pinned OpenBCM tree.
5. Build the Redstone init probe gate, then run its `--exec` path only after
   strict BDE smoke evidence and explicit reset-risk acceptance.
6. Bring up one front-panel port using SDK-managed PHY programming.
7. Add and verify one L2 entry or VLAN operation.
8. Only then proceed to L3 route, ACL/FP, and ECMP tests.
