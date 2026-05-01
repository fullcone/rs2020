# Redstone Hardware Inventory

This is the first-pass hardware inventory for Redstone Linux 5.10 DTS and
platform work. It separates facts extracted from the original Redstone system
from AS5610-derived EdgeNOS placeholders.

Status meanings:

- Confirmed: observed in the extracted Redstone firmware, original DTB, ZebOS
  startup scripts, or BCM SDK config files.
- Pending hardware proof: plausible from extracted files, but needs live
  Redstone boot output before it becomes a DTS or driver claim.
- Placeholder: current EdgeNOS AS5610 code only; do not treat it as Redstone
  board evidence.

## Source Evidence

- `../../redstone_feasibility_and_onl_vs_sonic.md`
- `../../boot_original/p2020rdb.dtb`, decompiled with `dtc -I dtb -O dts`
- `../../cf_card/ZEBOS/zebos.sh`
- `../../cf_card/ZEBOS/bcm/config.bcm`
- `../../cf_card/ZEBOS/bcm/config-4x10G.bcm`
- `../../cf_card/ZEBOS/bcm/startup`
- `../../cf_card/ZEBOS/bcm/qsfp_led.soc`
- `../../cf_card/ZEBOS/module/sfp.ko`
- `../../cf_card/ZEBOS/module/hsl_module.ko`
- `platform/i2c/i2c_init.sh`
- `platform/onlp/sfpi.c`
- `platform/cpld/accton_as5610_52x_cpld.c`

## Confirmed Board Facts

| Area | Extracted evidence | Linux 5.10 work item | Status |
| --- | --- | --- | --- |
| Board identity | `zebos.sh` derives `BOARD` from the kernel suffix and reads `PRONAME` from `/sys/class/eeprom/pro_name`. Redstone branches cover `D2012` and `D2020`. | Preserve runtime board selection for `redstone`, `redstone_t`, `rs2020`, and `r0678`; expose product EEPROM early in boot. | Confirmed |
| CPU | Original DTB reports `model = "fsl,P2020"` and `compatible = "fsl,P2020RDB"`. Existing ELF evidence is PowerPC 32-bit big-endian. | Keep PowerPC32 big-endian toolchain and Linux 5.10 e500 target. | Confirmed |
| ASIC | Firmware evidence identifies BCM56846 / Trident+. BCM config and `Trident_MMU*.soc` files are present. | Prove Linux 5.10 BDE can enumerate and map the device on Redstone hardware. | Confirmed ASIC, hardware proof pending |
| Port layout | `config.bcm` maps 48 10G ports plus 4 40G ports: `portmap_49=61:40`, `portmap_50=57:40`, `portmap_51=69:40`, `portmap_52=65:40`. | Keep this as the default Redstone stage-1 SDK config. | Confirmed |
| Breakout layout | `config-4x10G.bcm` adds 10G breakout mappings for lanes 57-72. | Keep breakout as a later selectable profile, not the initial default. | Confirmed |
| ASIC startup | `startup` runs `rcload rc.soc`, `fixup.soc`, `phy.soc`, and `qsfp_led.soc` through `bcm.user.proxy`. | Stage-1 should retain these files as compatibility reference inputs while switchd/BDE proof is still narrow. | Confirmed |
| Original data-plane stack | `zebos.sh` loads `linux-kernel-bde.ko`, `linux-uk-proxy.ko`, `linux-bcm-diag-full.ko`, runs `bcm.user.proxy < startup`, then loads `sfp.ko` and `hsl_module.ko lo_num=8`. | New NOS must prove its own BDE and ASIC init path before claiming L2/L3 offload parity. | Confirmed |

## DTS And Platform Inventory

| Component | Extracted evidence | Linux 5.10 DTS/platform implication | Status |
| --- | --- | --- | --- |
| Localbus | Original DTB has `localbus@ffe05000`, compatible `fsl,p2020-elbc`, with ranges for NOR, NAND, CPLD, and LPSRAM. | A Redstone DTS should start from this localbus layout, not from AS5610 localbus addresses. | Confirmed |
| CPLD | Original DTB has `CPLD@2,0`, compatible `kennisis_cpld`, `reg = <0x02 0x00 0x80000>`, with `reset@0` and `led@40000`. `zebos.sh` uses `/sys/class/kennisis_cpld` for `redstone` and `/sys/class/cpld` for `redstone_t`. | Write or port a Redstone CPLD driver/sysfs layer. Do not reuse `platform/cpld/accton_as5610_52x_cpld.c` as fact without register proof. | Confirmed interface, driver work pending |
| I2C controller 0 | Original DTB has `i2c@3000` with `rtc@68` (`dallas,ds1339`), `thermal@4b` (`cel,ambient2`), `eyeopen@41` (`cel,eyeopen`), and `eeprom@50` (`cel,eeprom`). | Convert these to Linux 5.10-compatible nodes and identify whether `cel,*` devices need custom drivers or generic bindings. | Confirmed |
| I2C controller 1 | Original DTB has `i2c@3100` with `thermal@4f` (`cel,ambient1`). | Convert thermal sensor handling after identifying the real chip behind the custom compatible. | Confirmed |
| EEPROM identity | Original scripts use `/sys/class/eeprom/pro_name`; `hsl_module.ko` strings reference `/sys/class/eeprom/switch1_mac`. | Add product EEPROM and switch MAC exposure before services depend on board identity. | Confirmed path, implementation pending |
| Management Ethernet | Original DTB exposes three `gianfar` eTSEC nodes at `ethernet@24000`, `ethernet@25000`, and `ethernet@26000`. It wires `ethernet@25000` to external PHY `ethernet-phy@3` under `ethernet@24000/mdio@520`, while `ethernet@25000` owns TBI `tbi-phy@11`. Redstone U-Boot reports PHY `0x03` plus TBI `0x11` on the TFTP MII device, but the U-Boot `ethaddr` value is operator-provided and must not be used alone to map U-Boot names to Linux `ethN`. | Preserve the original cross-MDIO `phy-handle` topology while debugging Linux 5.10 gianfar link/TX behavior. Do not move PHY `0x03` under `ethernet@25000/mdio@520`; hardware reads that endpoint as `phy_id=0x00000000`. | Confirmed original topology, Linux TX/link proof pending |
| PCIe | Original DTB exposes `pcie@ffe09000` and `pcie@ffe0a000`, compatible `fsl,mpc8548-pcie`, with memory windows at `0xa0000000` and `0xc0000000`. | Keep both PCIe controllers in the DTS skeleton, then use `lspci -nn` on hardware to bind BCM56846 to the correct controller. | Confirmed controllers, ASIC bus proof pending |
| Optics | `sfp.ko` describes "Redstone sfp info" and strings reference SFP/QSFP EEPROM fields plus Broadcom callbacks. Current `platform/onlp/sfpi.c` is AS5610-derived and assumes AS5610 mux/PCA GPIO topology. | Treat Redstone optics presence and EEPROM routing as reverse-engineering work. Do not copy AS5610 bus numbers into Redstone DTS until proven. | Original optics module confirmed, routing pending |
| Fans, PSU, thermal | The feasibility note flags CPLD, fan, PSU, SFP, and temperature as ONLP/platform work. Original DTB only proves the two custom thermal compatibles listed above. | Reverse CPLD registers and original diagnostic paths before implementing fan and PSU nodes. | Partial evidence |
| LEDs | `qsfp_led.soc` includes Redstone LED programs for SDK LED processors. Original DTB also has a CPLD LED window. | Split ASIC-port LED programming from CPLD/system LED handling. | Confirmed sources, mapping pending |

## Placeholder Code To Treat Carefully

The following files are useful as EdgeNOS structure references, but they are not
Redstone hardware proof:

- `kernel/dts/as5610-52x.dts`
- `platform/i2c/i2c_init.sh`
- `platform/onlp/sfpi.c`
- `platform/cpld/accton_as5610_52x_cpld.c`

`kernel/dts/redstone-stage1.dts` is now the Redstone stage-1 DTS skeleton. It
captures only extracted original `../../boot_original/p2020rdb.dtb` facts and
keeps AS5610-specific mux, optics, fan, and CPLD assumptions out until hardware
output proves them.

## Live TFTP Stage-1 Management Ethernet Evidence

The first TFTP FIT boot on Redstone proved that U-Boot can transfer the
stage-1 image through `eTSEC2`:

```text
ethact=eTSEC2
eth1addr=00:E0:EC:53:B8:23
eth2addr=00:E0:EC:53:B8:24
mii device: eTSEC2, eTSEC3
mii info on eTSEC2:
  PHY 0x03: OUI = 0xD897, Model = 0x11, Rev = 0x02, 1000baseT, FDX
  PHY 0x11: OUI = 0x0000, Model = 0x00, Rev = 0x00, 1000baseX, HDX
```

Linux 5.10 stage-1 booted the FIT, identified `/etc/edgenos/board` as
`redstone`, and enumerated BCM56846 as PCI `14e4:b846`. The first Linux
management-port test showed `eth1` (`ethernet@25000`, MAC
`00:e0:ec:53:b8:23`) reaching carrier at 1 Gbps full duplex, but ARP from
Redstone did not appear on a Windows `pktmon` capture pinned to the physical
X722 TFTP NIC. The broken DTS binding at that point pointed `eth1` at a PHY
node under `ethernet@24000`.

The first rebuilt `uImage-b2-eth1phy.itb` did not reach Linux because it missed
the Accton U-Boot compatibility alias `serial1 = /soc@ffe00000/serial@4600`;
U-Boot stopped while fixing `linux,stdout-path`. The corrected retest image is
`uImage-b2-eth1phy-fixed.itb`.

The `uImage-b2-eth1phy-fixed.itb` retest reached Linux but invalidated the
moved-PHY hypothesis: Linux exposed `mdio@ffe25520:03`, read
`phy_id=0x00000000`, reported eth1 as 10M/half with no autonegotiation and no
carrier, and therefore transmitted no ARP. A Windows physical X722 capture saw
the U-Boot TFTP-stage ARP from the manually supplied MAC
`00:E0:EC:53:B8:22`, but not a Linux eth1 ARP from MAC
`00:E0:EC:53:B8:23`.

The `uImage-b2-origphy-serial1.itb` image kept the Accton U-Boot `serial1`
alias and restored the original Redstone cross-MDIO PHY topology, but it
re-enabled `pcie@ffe09000` and crashed in early Linux PCI initialization before
network testing. The replacement image is `uImage-b2-origphy-nopci0.itb`: it
keeps external PHY `0x03` under `ethernet@24000/mdio@520`, referenced by
`ethernet@25000`, keeps TBI `0x11` under `ethernet@25000/mdio@520`, and disables
`pcie@ffe09000` while leaving `pcie@ffe0a000` enabled for BCM56846.

`uImage-b2-origphy-nopci0.itb` booted and validated the external PHY placement:
Linux exposes `mdio@ffe24520:03`, reads `phy_id=0x03625d12`, and binds
`Broadcom BCM54616S`. The real management-port test should focus on `eth1`
only. Avoid bringing up `eth0` and `eth2` during this test because their
fixed-link-style nodes can report link independently and trigger `eth0`
watchdog noise that obscures the eth1 TX/ARP evidence.

When eth0 and eth2 were forced down and eth1 was bounced, eth1 reached
`Link is Up - 1Gbps/Full` after roughly six seconds. The first isolated ping
attempt did not validate IP traffic because serial-console interleaving
corrupted the address-assignment command, leaving eth1 without
`10.188.2.16/24`.

A clean follow-up assigned `10.188.2.16/24` to eth1 and used the switch-side
TFTP client to request `redstone-tftp-test.bin` from the Windows TFTP host.
The request timed out before transfer because ARP stayed
`10.188.2.243 dev eth1 INCOMPLETE`. Linux eth1 TX counters and
`eth1_g0_tx` interrupts increased, but RX counters and `eth1_g0_rx` stayed at
zero. A converted Windows `pktmon` capture from the physical X722 TFTP NIC saw
other ARP traffic, but exact searches for Redstone MAC
`00:e0:ec:53:b8:23`, IP `10.188.2.16`, and the expected ARP request string
returned no matches. The remaining management-Ethernet blocker is therefore
inside the gianfar MAC-to-BCM54616S SGMII/TBI path, not the Windows host, IP
assignment, or external PHY placement.

The next hardware image is `output/images/uImage-b2-phytool.itb`. It preserves
the DTB bytes from the last bootable `uImage-b2-origphy-nopci0.itb`, but
rebuilds the rootfs/initramfs with `/usr/bin/phytool` and the enhanced
`redstone-stage1-capture` script. Use a switch-side TFTP GET as the primary
management-Ethernet test because it exercises ARP plus UDP on the same host
path as U-Boot TFTP. Ping is still useful as secondary evidence, but TFTP is
the better bench signal for the current failure. After the TFTP attempt, run
`redstone-stage1-capture --verbose` so the returned bundle contains PHY/TBI
registers and raw eTSEC register snapshots for the gianfar TX/SGMII follow-up.

## First Hardware-Capture Checklist

Run the packaged capture first on a live Redstone boot before turning pending
items into final DTS or driver claims:

```sh
redstone-stage1-capture --verbose
redstone-stage1-validate --iface swpN --peer PEER_IP --strict --capture
```

The validation command is the preferred evidence path when one front-panel link
and a ping peer are available. It embeds the verbose capture into the validation
bundle and prints the host-side analysis command to run after copying the bundle
back.

The verbose capture writes a timestamped directory under
`/var/log/redstone-stage1/` and creates a tarball when `tar` is available. It
includes top-level `capture-summary.txt` and `run_metadata.txt`, command
availability, device-tree properties, full and focused dmesg, exact PCI
driver/resource/config-space data for BCM56846 evidence, BDE/OpenBCM module and
device-node state, switchd service/journal/process state, netdev counters,
ethtool and tc output, passive I2C topology, and sysfs snapshots for EEPROM,
CPLD, hwmon, thermal, LED, GPIO, and platform devices.

Manual console notes are secondary context. Use these only to double-check what
the bundle already captured:

```sh
cat /proc/device-tree/model
cat /proc/device-tree/compatible
cat /sys/class/eeprom/pro_name
cat /sys/class/eeprom/switch1_mac 2>/dev/null || true
lspci -nn
dmesg | grep -iE 'bcm|bde|trident|5684|gianfar|i2c|cpld|sfp|qsfp'
find /sys/class -maxdepth 2 -type f | grep -iE 'cpld|eeprom|fan|psu|sfp|qsfp|thermal'
i2cdetect -l
```

`redstone-stage1-capture` does not run active I2C scans by default. Use
`redstone-stage1-capture --verbose --scan-i2c` only on a bench system where
active probing is acceptable.

## Host Platform Inventory Analysis

After returning a capture or validation bundle to the build host, generate the
platform/DTS follow-up matrix:

```sh
./scripts/analyze-redstone-platform-inventory.sh /path/to/validate-20260429T000000Z.tar.gz
```

From an unpacked hardware handoff package, use the packaged copy:

```sh
./host-tools/analyze-redstone-platform-inventory.sh PATH_TO_VALIDATION_BUNDLE_OR_DIR
```

Treat OBSERVED rows as candidates for Redstone DTS or platform-driver work.
Keep PENDING rows as unclaimed inventory until the next hardware capture proves
the exact bus, GPIO, sysfs, or link behavior.
