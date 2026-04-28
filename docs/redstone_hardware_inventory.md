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
| Management Ethernet | Original DTB exposes three `gianfar` eTSEC nodes at `ethernet@24000`, `ethernet@25000`, and `ethernet@26000`; `ethernet@24000` has a fixed 1G RGMII path. | Keep all three nodes in the DTS skeleton until hardware boot logs identify the active management port. | Confirmed nodes, live port proof pending |
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

## First Hardware-Capture Checklist

Collect these on a live Redstone boot before turning pending items into final
DTS or driver claims:

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
