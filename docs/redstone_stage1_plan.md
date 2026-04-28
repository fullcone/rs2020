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

To select it on a Redstone image:

```sh
cp /etc/switchd/redstone-stage1.bcm /etc/switchd/config.bcm
systemctl restart switchd
journalctl -u switchd -f
```

`switchd` now accepts both config key styles:

- `portmap_N.0=lane:speed`, used by the current AS5610 config.
- `portmap_N=lane:speed`, used by Broadcom SDK-style board configs.

## Build Verification

On WSL/Ubuntu, install the PowerPC toolchain:

```sh
sudo apt-get update
sudo apt-get install -y gcc-powerpc-linux-gnu binutils-powerpc-linux-gnu make
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

- Build kernel/rootfs with Redstone DTS and Redstone switchd config.
- Load BDE and detect BCM56846.
- Start switchd with `redstone-stage1.bcm`.
- Verify one 10G SFP+ port or one 40G QSFP+ port links up.
- Assign test IPs and pass one ping through the ASIC.

### Stage 2: Platform Inventory

- Add Redstone DTS coverage for I2C muxes, EEPROM, CPLD/GPIO, fans, thermal,
  PSU, and front-panel optical cages.
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
