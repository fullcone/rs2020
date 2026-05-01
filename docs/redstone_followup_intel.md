# Redstone Follow-Up Intelligence

This note records the original firmware evidence that matters after the eth1
management-port fix. USB/flash direct boot is intentionally out of scope for
this pass; the current focus is the later BCM56846, SDK, and front-panel path.

## Fixed Point

The Linux 5.10 stage-1 management port is no longer blocked by routing, Windows
TFTP, or a generic TBI setup failure. The known-good test image was
`uImage-b2-preserve-uboot-sgmii.itb`: switch-side TFTP returned `tftp_rc=0`,
ARP resolved `10.188.2.243` as `REACHABLE`, eth1 RX/TX counters advanced, and
`eth1_g0_rx` interrupts increased.

The root cause was stock Linux BCM54616S SGMII setup overwriting the U-Boot-good
SerDes state. The current fix is the opt-in
`brcm,redstone-preserve-uboot-sgmii` DTS property, which preserves U-Boot's
working BCM54616S state. Direct USB/flash boot without U-Boot network
initialization is not validated here.

## Original Startup Chain

The Redstone original firmware starts Broadcom userland from the ZebOS startup
script, not from the minimal EdgeNOS `switchd` path.

Important original files:

- `startup_redstone_t/ZEBOS/zebos.sh`
- `cf_card/ZEBOS/zebos.sh`
- `startup_redstone_t/ZEBOS/bcm/startup`
- `startup_redstone_t/ZEBOS/bcm/config.bcm.in`
- `startup_redstone_t/ZEBOS/bcm/split.sh`
- `startup_redstone_t/ZEBOS/bcm/mmu.sh`
- `startup_redstone_t/ZEBOS/bcm/fixup.soc`
- `startup_redstone_t/ZEBOS/bcm/phy.soc.in`
- `startup_redstone_t/ZEBOS/bcm/qsfp_led.soc`

The original `zebos.sh` path loads Broadcom kernel/user modules and then runs
the BCM shell input:

- `linux-kernel-bde.ko dmasize=32M himem=1`
- `linux-uk-proxy.ko`
- `linux-bcm-diag-full.ko`
- `split.sh /cf_card/ZEBOS/etc/ZebOS.conf`
- `mmu.sh /cf_card/ZEBOS/etc/ZebOS.conf`
- `./bcm.user.proxy < startup`
- `sfp.ko`
- `hsl_module.ko lo_num=8`

The original `startup` file is short and ordered:

```text
config refresh
rcload rc.soc
rcload fixup.soc
rcload phy.soc
rcload qsfp_led.soc
exit
```

This means later OpenBCM work should not treat `config.bcm` alone as complete.
The runtime chain also depends on SOC register fixups, PHY programming, LED
firmware, SFP support, and the HSL module.

## Active Split Mode

The original runtime config evidence does not match a simple 48x10G + 4x40G
layout. Both `cf_card/startup/ZebOS.conf.disabled` and the saved show-tech log
under `cf_card/ZEBOS/tech/data/normal/20020826180039/imi_show_tech.log` show:

- `split interface fxe49`
- `split interface fxe50`
- `split interface fxe51`
- `fxe52` present as a normal, unsplit interface

`split.sh` turns that into this BCM map shape:

- `fxe49` split:
  `portmap_49=61:10`, `portmap_50=62:10`, `portmap_51=63:10`,
  `portmap_52=64:10`, `xgxs_tx_lane_map_xe48=0x2031`
- `fxe50` split:
  `portmap_53=57:10`, `portmap_54=58:10`, `portmap_55=59:10`,
  `portmap_56=60:10`, `xgxs_tx_lane_map_xe52=0x2031`,
  `port_phy_addr_xe52=0x5c` through `port_phy_addr_xe55=0x5c`
- `fxe51` split:
  `portmap_57=69:10`, `portmap_58=70:10`, `portmap_59=71:10`,
  `portmap_60=72:10`, `xgxs_tx_lane_map_xe56=0x3120`
- `fxe52` unsplit:
  `portmap_61=65:40`, `xgxs_tx_lane_map_xe60=0x2031`

The current `config/bcm/redstone-stage1.bcm` is only a stage-1 portmap
skeleton. It currently uses the 4x40G shape for ports 49-52 and does not encode
the original active 49/50/51 split mode. Keep it stable until a separate
reference or generated config is added and tested.

`config/bcm/redstone-original-active-portmap.bcm` is now a non-default
reference for this active split map. It is not selected by the Redstone board
selector and does not claim full SDK parity.

## BCM Config Gaps

The original `config.bcm.in` includes more than port maps:

- `pbmp_xport_xe=0x1fffffffffffffffe`
- `l2xmsg_chunks=256`
- `l2xmsg_thread_pri=200`
- `xgxs_lcpll_xtal_refclk=1`
- `phy_ext_rom_boot=0`
- `l3_mem_entries=16384`
- `l2_mem_entries=32768`
- `pbmp_oversubscribe=0x1fffffffe`
- `xgxs_rx_lane_map_xe*` values such as `0x3201`
- odd-port `phy_xaui_tx_polarity_flip_xe*` and
  `phy_xaui_rx_polarity_flip_xe*`
- `port_phy_addr_xe*` external PHY addresses
- odd-port `phy_mdi_pair_map_xe*=0x3210`
- `phy_mod_abs=1`
- `phy_84848=1`

`phy.soc.in` then programs the BCM84848 PHYs with repeated MDIO writes such as
`0xa82c`, `0xa82f`, `0xa832`, `0xa838`, `0xa82a`, `0xa82b`, `0xa83b`, and
`0xa8ec` per front-panel port. `fixup.soc` applies MMU and queue fixes,
including CPU queue limits, THDO minimum cells, and a LACP ingress-to-egress
drop workaround. `qsfp_led.soc` loads and starts Broadcom LED programs.

## BDE And SDK Facts

The original Redstone BDE modules are for the old vendor kernel, not the new
Linux 5.10 stage-1 kernel:

- `linux-kernel-bde.ko` has `vermagic=2.6.32.57_redstone_t mod_unload`
- `linux-bcm-diag-full.ko` strings reference `sdk-xgs-robo-5.10.2`
- `linux-kernel-bde.ko` exposes `dmasize` and `himem` parameters
- the original Redstone startup uses `dmasize=32M himem=1`
- the diag module contains BCM56846 identifiers such as `BCM56846_A0` and
  `BCM56846_A1`

Current Linux 5.10 capture evidence shows the PCI device is visible:

- `0001:01:00.0`
- vendor/device `14e4:b846`
- memory window `c0000000-c003ffff`
- IRQ `17`

But BDE device nodes were absent in the captured stage-1 run and `switchd` was
unavailable or failed before an ASIC data-path proof. The next ASIC work must
therefore prove BDE character devices and BCM56846 access before attempting any
front-panel link validation.

## Next Non-USB Order

1. Extend the non-default original-active portmap reference into either a full
   generated SDK config or a checked reference that includes the original
   globals, PHY, MMU, and LED dependencies.
2. Extend the Redstone validation scripts so captures record the intended
   split mode and exact BCM config source.
3. Run the OpenBCM BDE smoke helper on hardware and require BDE device nodes,
   `14e4:b846`, and a clean evidence bundle before loading SDK userland.
4. Run the OpenBCM init probe in dry-run mode with the original-active config.
5. Only after dry-run evidence is sane, run a controlled SDK exec test and then
   a single front-panel link test.
