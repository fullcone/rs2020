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
2. Load BDE on Redstone and enumerate BCM56846.
3. Run a minimal userland SDK init path.
4. Bring up one front-panel port using SDK-managed PHY programming.
5. Add and verify one L2 entry or VLAN operation.
6. Only then proceed to L3 route, ACL/FP, and ECMP tests.
