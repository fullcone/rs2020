# Redstone USB Stage-1 Operator Checklist

This checklist is for the first non-destructive Redstone USB boot and capture
run. It is an external boot workflow only. Do not flash internal storage, do not
run ONIE install, and do not save U-Boot environment variables while proving
stage 1.

## Scope

Allowed:

- Boot the generated Redstone USB stage-1 image from an external USB stick.
- Run capture-only diagnostics.
- Run one strict front-panel link and ping test after the bench link is ready.
- Return the generated bundle or evidence directory plus the full serial log.

Blocked during this stage:

- Do not overwrite internal flash, NAND, NOR, or local disks.
- Do not run `saveenv`.
- Do not run `onie-nos-install`.
- Do not edit persistent U-Boot environment to make this boot path work.
- Do not treat capture-only output as stage-1 acceptance.

## Host Build And Verify

From the EdgeNOS source tree:

```sh
EDGENOS_BOARD=redstone make redstone-usb-stage1-check
sudo EDGENOS_BOARD=redstone make redstone-usb-stage1
EDGENOS_BOARD=redstone make redstone-usb-stage1-verify
```

The verify step is mandatory before writing media. It is host-side and
read-only. Missing `sha256sum` or `md5sum` must fail verification.

## Guarded USB Write

Writing the image overwrites only the selected USB disk. On the Windows host,
open PowerShell as Administrator and use the existing guarded writer with the
exact disk name and size range:

```powershell
cd C:\other_project\R0678
.\write_fanxiang_uboot_fat_image.ps1 `
  -ImagePath C:\other_project\R0678\redstone_system_extracted\_external\edgenos\output\images\redstone-usb-stage1-boot-capture.img `
  -DiskName "General UDisk" `
  -MinSizeGB 3 `
  -MaxSizeGB 5
```

Do not write the ONIE-style `edgenos-redstone-stage1.bin` payload directly to a
USB stick for the Redstone U-Boot 2009.11 path.

## U-Boot Temporary Boot

Keep the original recovery USB and a full serial log. Use temporary U-Boot
commands only:

```text
usb stop
usb reset
usb storage
fatls usb 0:1 /
fatload usb 0:1 1000000 uImage-powerpc.itb
bootm 1000000#accton_as5610_52x
```

Stop and return the serial log if `fatls` cannot list the FAT partition or if
the FIT boot command fails. Do not run `saveenv` to work around a failure.

## First Boot Capture

After Linux boots:

```sh
cat /etc/edgenos/board
redstone-stage1-bench-run --capture-only
```

Return the printed evidence directory or validation bundle path, and the full
serial console log. Capture-only output is inventory evidence only.

## Strict One-Port Validation

Run this only after the intended front-panel interface and peer are physically
connected on the bench:

```sh
REDSTONE_IFACE=swpN
REDSTONE_LOCAL_CIDR=192.0.2.1/24
REDSTONE_PEER=192.0.2.2

redstone-stage1-bench-run --iface "$REDSTONE_IFACE" --local-cidr "$REDSTONE_LOCAL_CIDR" --peer "$REDSTONE_PEER"
```

Return the printed validation bundle or evidence directory, plus the full
serial log.

## Host Analysis

After copying back the strict validation bundle or evidence directory, unpack
the Redstone handoff package and run:

```sh
./host-tools/analyze-redstone-handoff-capture.sh . PATH_TO_VALIDATION_BUNDLE_OR_DIR
./host-tools/prepare-redstone-bench-note.sh . "${REDSTONE_RESULT_DIR:-../redstone-bench-results}"
```

The analysis should prove the exact BCM56846 PCI ID `14e4:b846`, BDE/switchd
evidence, a Redstone board selector, and the strict one-port ping result.

## Abort And Return Evidence

Abort the run and return logs if any of these occur:

- U-Boot cannot list the USB FAT partition.
- The FIT image does not boot.
- `/etc/edgenos/board` is not `redstone`.
- Exact BCM56846 PCI ID `14e4:b846` is missing.
- BDE device nodes or switchd startup evidence is missing.
- No expected `swpN` interface appears.
- Link does not come up on the selected bench port.
- Ping to the configured peer fails.

Do not perform a persistent install to fix any of the above. Return the serial
log and generated evidence so the next code change can be based on the real
failure point.
