#!/bin/sh
# Source-tree preflight for the Redstone stage-1 build path.

set -eu

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
BOARD="${1:-${EDGENOS_BOARD:-redstone}}"
FAILURES=0
WARNINGS=0

ok() {
    printf 'ok: %s\n' "$*"
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    printf 'warn: %s\n' "$*" >&2
}

fail() {
    FAILURES=$((FAILURES + 1))
    printf 'fail: %s\n' "$*" >&2
}

check_file() {
    rel=$1
    if [ -f "$TOPDIR/$rel" ]; then
        ok "file exists: $rel"
    else
        fail "missing file: $rel"
    fi
}

check_grep() {
    pattern=$1
    rel=$2
    desc=$3

    if grep -Eq -- "$pattern" "$TOPDIR/$rel"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

check_no_regex() {
    pattern=$1
    rel=$2
    desc=$3

    if grep -Eq -- "$pattern" "$TOPDIR/$rel"; then
        fail "$desc"
    else
        ok "$desc"
    fi
}

LOOSE_BCM56846_SOURCE_RE='(grep[[:space:]].*-[^[:space:]]*E|has_text|file_has_text).*(14e4[.][*]|(^|[^[:alnum:]_:])b846([^[:alnum:]_]|$)|(^|[^[:alnum:]_:])56846([^[:alnum:]_]|$))'

check_alias() {
    alias=$1
    result=$(
        TOPDIR="$TOPDIR" EDGENOS_BOARD="$alias" sh -c '
            . "$TOPDIR/scripts/board-env.sh"
            printf "%s|%s|%s\n" "$EDGENOS_BOARD" "$EDGENOS_DTS_BASENAME" "$EDGENOS_IMAGE_NAME"
        '
    )

    case "$result" in
        redstone\|redstone-stage1\|edgenos-redstone-stage1.bin)
            ok "board alias $alias resolves to Redstone stage-1 artifacts"
            ;;
        *)
            fail "board alias $alias resolved unexpectedly: $result"
            ;;
    esac
}

EDGENOS_BOARD="$BOARD"
export EDGENOS_BOARD
. "$TOPDIR/scripts/board-env.sh"

printf 'Redstone stage-1 preflight\n'
printf '  requested board: %s\n' "$BOARD"
printf '  normalized board: %s\n' "$EDGENOS_BOARD"
printf '  DTS source: %s\n' "$EDGENOS_DTS_SOURCE"
printf '  DTB basename: %s\n' "$EDGENOS_DTS_BASENAME"
printf '  image name: %s\n\n' "$EDGENOS_IMAGE_NAME"

if [ "$EDGENOS_BOARD" != "redstone" ]; then
    fail "expected Redstone board selection, got $EDGENOS_BOARD"
fi
if [ "$EDGENOS_DTS_BASENAME" != "redstone-stage1" ]; then
    fail "expected redstone-stage1 DTB basename, got $EDGENOS_DTS_BASENAME"
fi
if [ "$EDGENOS_IMAGE_NAME" != "edgenos-redstone-stage1.bin" ]; then
    fail "expected Redstone image name, got $EDGENOS_IMAGE_NAME"
fi

for alias in redstone rs2020 r0678; do
    check_alias "$alias"
done

check_file "$EDGENOS_DTS_SOURCE"
check_file "$EDGENOS_KERNEL_DEFCONFIG"
check_file "config/bcm/redstone-stage1.bcm"
check_file "config/bcm/redstone-original-active-sdk.manifest"
check_file "config/rootfs/overlay/usr/sbin/redstone-stage1-capture"
check_file "config/rootfs/overlay/usr/sbin/redstone-stage1-validate"
check_file "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run"
check_file "config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact"
check_file "config/rootfs/overlay/usr/sbin/redstone-mgmt-evidence"
check_file "config/rootfs/overlay/usr/sbin/redstone-mgmt-status"
check_file "config/rootfs/overlay/usr/sbin/redstone-mgmt-web"
check_file "config/rootfs/overlay/www/cgi-bin/redstone-artifact"
check_file "config/rootfs/overlay/www/cgi-bin/redstone-evidence"
check_file "config/rootfs/overlay/www/cgi-bin/redstone-status"
check_file "config/rootfs/overlay/www/cgi-bin/redstone-action"
check_file "config/rootfs/overlay/www/redstone/index.html"
check_file "config/rootfs/overlay/www/redstone/redstone.css"
check_file "config/rootfs/overlay/www/redstone/redstone.js"
check_file "config/rootfs/overlay/usr/sbin/switchd-init"
check_file "config/rootfs/overlay/etc/init.d/S20edgenos"
check_file "config/rootfs/overlay/etc/init.d/S38devpts"
check_file "config/rootfs/overlay/etc/init.d/S41redstone-mgmt-web"
check_file "config/rootfs/overlay/etc/systemd/system/switchd.service"
check_file "scripts/build-rootfs.sh"
check_file "scripts/build-kernel.sh"
check_file "scripts/build-installer.sh"
check_file "scripts/build-modules.sh"
check_file "scripts/build-all.sh"
check_file "scripts/build-redstone-b2-tftp-fit.sh"
check_file "scripts/check-redstone-image.sh"
check_file "scripts/package-redstone-hardware-handoff.sh"
check_file "scripts/package-redstone-web-hotfix.sh"
check_file "scripts/package-redstone-usb-stage1.sh"
check_file "scripts/verify-redstone-usb-stage1-image.sh"
check_file "scripts/verify-redstone-hardware-handoff.sh"
check_file "scripts/prepare-redstone-bench-note.sh"
check_file "scripts/analyze-redstone-stage1-evidence.sh"
check_file "scripts/analyze-redstone-handoff-capture.sh"
check_file "scripts/analyze-redstone-platform-inventory.sh"
check_file "scripts/analyze-redstone-openbcm-bde-smoke.sh"
check_file "scripts/prepare-openbcm.sh"
check_file "scripts/build-openbcm-bde.sh"
check_file "scripts/redstone-openbcm-bde-smoke.sh"
check_file "scripts/check-openbcm-userland-init.sh"
check_file "scripts/build-openbcm-init-probe.sh"
check_file "scripts/install-openbcm-init-probe.sh"
check_file "scripts/generate-redstone-original-active-sdk-reference.sh"
check_file "asic/openbcm-init/redstone-openbcm-init-probe.c"
check_file "docs/redstone_bench_result_template.md"
check_file "docs/redstone_stage1_plan.md"
check_file "docs/redstone_progress.md"
check_file "docs/redstone_web_mgmt_plan.md"
check_file "docs/redstone_usb_stage1_operator_checklist.md"
check_file "kernel/patches/0001-gianfar-log-and-force-invalid-tbi-setup.patch"
check_file "kernel/patches/0002-bcm54616s-redstone-preserve-uboot-sgmii.patch"

check_grep 'redstone-stage1\.bcm' "config/rootfs/overlay/usr/sbin/switchd-init" \
    "switchd-init references Redstone stage-1 config"
check_grep 'BR2_powerpc_e500v2=y' "config/rootfs/buildroot_defconfig" \
    "shared rootfs defconfig preserves AS5610 e500v2 CPU selection"
check_grep 'BR2_TOOLCHAIN_BUILDROOT_GLIBC=y' "config/rootfs/buildroot_defconfig" \
    "shared rootfs defconfig preserves AS5610 glibc"
check_grep 'BR2_INIT_SYSTEMD=y' "config/rootfs/buildroot_defconfig" \
    "shared rootfs defconfig preserves AS5610 systemd"
check_grep 'CONFIG_HTTPD=y' "config/rootfs/busybox-fragment.config" \
    "BusyBox fragment enables optional Redstone management httpd"
check_grep 'CONFIG_FEATURE_HTTPD_CGI=y' "config/rootfs/busybox-fragment.config" \
    "BusyBox fragment enables optional Redstone management CGI"
check_grep 'if \[ "\$EDGENOS_BOARD" = "redstone" \]' "scripts/build-rootfs.sh" \
    "build-rootfs gates Redstone rootfs defconfig overrides on selected board"
check_grep 'BR2_powerpc_8548=y' "scripts/build-rootfs.sh" \
    "build-rootfs selects Redstone P2020/e500v2 SPE CPU in generated defconfig"
check_grep 'BR2_powerpc_SPE=y' "scripts/build-rootfs.sh" \
    "build-rootfs selects Redstone SPE ABI in generated defconfig"
check_grep 'BR2_TOOLCHAIN_BUILDROOT_UCLIBC=y' "scripts/build-rootfs.sh" \
    "build-rootfs selects Redstone uClibc in generated defconfig"
check_grep 'BR2_INIT_BUSYBOX=y' "scripts/build-rootfs.sh" \
    "build-rootfs selects Redstone BusyBox init in generated defconfig"
check_grep 'defconfig\)' "scripts/build-rootfs.sh" \
    "build-rootfs can generate defconfig without running a full Buildroot build"
check_grep 'switchd-init start' "config/rootfs/overlay/etc/init.d/S20edgenos" \
    "BusyBox init starts switchd through switchd-init"
check_grep 'start-foreground' "config/rootfs/overlay/etc/systemd/system/switchd.service" \
    "switchd service uses switchd-init foreground path"
check_grep 'config/rootfs/overlay' "scripts/build-rootfs.sh" \
    "build-rootfs applies the rootfs overlay"
check_grep 'install-openbcm-init-probe\.sh' "scripts/build-rootfs.sh" \
    "build-rootfs installs optional Redstone OpenBCM init probe"
check_grep 'redstone-stage1-bench-run' "scripts/build-rootfs.sh" \
    "build-rootfs preserves Redstone bench runner executable mode"
check_grep 'redstone-mgmt-artifact' "scripts/build-rootfs.sh" \
    "build-rootfs preserves Redstone artifact provider executable mode"
check_grep 'redstone-mgmt-evidence' "scripts/build-rootfs.sh" \
    "build-rootfs preserves Redstone evidence provider executable mode"
check_grep 'redstone-mgmt-status' "scripts/build-rootfs.sh" \
    "build-rootfs preserves Redstone management status executable mode"
check_grep 'S41redstone-mgmt-web' "scripts/build-rootfs.sh" \
    "build-rootfs preserves Redstone management web init executable mode"
check_grep 'www/cgi-bin/redstone-artifact' "scripts/build-rootfs.sh" \
    "build-rootfs preserves Redstone artifact CGI executable mode"
check_grep 'www/cgi-bin/redstone-evidence' "scripts/build-rootfs.sh" \
    "build-rootfs preserves Redstone evidence CGI executable mode"
check_grep 'www/cgi-bin/redstone-status' "scripts/build-rootfs.sh" \
    "build-rootfs preserves Redstone management CGI executable mode"
check_grep 'www/cgi-bin/redstone-action' "scripts/build-rootfs.sh" \
    "build-rootfs preserves Redstone management action CGI executable mode"
check_grep 'install-openbcm-init-probe\.sh' "config/rootfs/post-build.sh" \
    "Buildroot post-build installs optional Redstone OpenBCM init probe"
check_grep 'sed -i.*s/\\r\$//' "config/rootfs/post-build.sh" \
    "Buildroot post-build strips CRLF from text overlays"
check_grep 'Redstone stage-1 manual management links' "config/rootfs/post-build.sh" \
    "Redstone post-build keeps eTSEC management links manual"
check_grep 'Redstone var-empty permission repair' "config/rootfs/post-build.sh" \
    "Redstone post-build repairs sshd /var/empty permissions at runtime"
check_grep 'devpts\\t/dev/pts\\tdevpts' "config/rootfs/post-build.sh" \
    "Redstone post-build records devpts for SSH PTY allocation"
check_grep 'redstone-mgmt-artifact' "config/rootfs/post-build.sh" \
    "Redstone post-build normalizes management artifact script"
check_grep 'redstone-mgmt-status' "config/rootfs/post-build.sh" \
    "Redstone post-build normalizes management status script"
check_grep 'redstone-mgmt-evidence' "config/rootfs/post-build.sh" \
    "Redstone post-build normalizes management evidence script"
check_grep 'redstone-httpd/httpd' "config/rootfs/post-build.sh" \
    "Redstone post-build provisions fallback httpd applet symlink"
check_grep 'www/cgi-bin/redstone-artifact' "config/rootfs/post-build.sh" \
    "Redstone post-build marks artifact CGI executable"
check_grep 'www/cgi-bin/redstone-evidence' "config/rootfs/post-build.sh" \
    "Redstone post-build marks evidence CGI executable"
check_grep 'www/cgi-bin/redstone-status' "config/rootfs/post-build.sh" \
    "Redstone post-build marks management CGI executable"
check_grep 'www/cgi-bin/redstone-action' "config/rootfs/post-build.sh" \
    "Redstone post-build marks management action CGI executable"
check_grep 'mktemp -d.*redstone-b2-fit' "scripts/build-redstone-b2-tftp-fit.sh" \
    "B2 TFTP FIT builder uses a Linux temporary workspace"
check_grep 'unsafe FIT image name' "scripts/build-redstone-b2-tftp-fit.sh" \
    "B2 TFTP FIT builder rejects path traversal in image names"
check_grep 'REDSTONE_TFTP_WORKDIR must be under' "scripts/build-redstone-b2-tftp-fit.sh" \
    "B2 TFTP FIT builder constrains custom work directories before deletion"
check_grep 'OUTDIR/rootfs/staging' "scripts/build-redstone-b2-tftp-fit.sh" \
    "B2 TFTP FIT builder prefers assembled rootfs staging when present"
check_grep 'cpio .* -R 0:0' "scripts/build-redstone-b2-tftp-fit.sh" \
    "B2 TFTP FIT builder writes root-owned initramfs entries"
check_grep 'patch -p1 --forward --dry-run' "scripts/build-kernel.sh" \
    "build-kernel applies kernel patches idempotently"
check_no_regex 'Skipping patch|hunks ignored' "scripts/build-kernel.sh" \
    "build-kernel does not treat generic skipped hunks as already applied"
check_grep 'vmlinux\.bin' "scripts/build-kernel.sh" \
    "build-kernel exports the raw PowerPC kernel payload for B2 FIT tests"
check_grep 'Redstone TBI.*0xffff|BMSR read returned all ones' \
    "kernel/patches/0001-gianfar-log-and-force-invalid-tbi-setup.patch" \
    "Redstone kernel patch logs and handles invalid all-ones TBI reads"
check_grep 'Redstone TBI: link update' \
    "kernel/patches/0001-gianfar-log-and-force-invalid-tbi-setup.patch" \
    "Redstone kernel patch logs post-link MAC/PCS registers"
check_grep 'brcm,redstone-preserve-uboot-sgmii' \
    "kernel/dts/redstone-stage1.dts" \
    "Redstone DTS marks the U-Boot-preserved BCM54616S SGMII PHY"
check_grep 'preserving U-Boot BCM54616S SGMII/SerDes state' \
    "kernel/patches/0002-bcm54616s-redstone-preserve-uboot-sgmii.patch" \
    "Redstone kernel patch can preserve U-Boot BCM54616S SGMII state"
check_grep 'skipping BCM54616S autoneg setup for preserved SGMII state' \
    "kernel/patches/0002-bcm54616s-redstone-preserve-uboot-sgmii.patch" \
    "Redstone kernel patch can skip BCM54616S autonegotiation on preserved SGMII state"
check_grep 'config/rootfs/overlay' "scripts/build-all.sh" \
    "build-all applies the rootfs overlay"
check_grep 'install-openbcm-init-probe\.sh' "scripts/build-all.sh" \
    "build-all installs required Redstone OpenBCM init probe before squashfs packing"
check_grep '--squashfs' "scripts/check-redstone-image.sh" \
    "image checker can verify packed rootfs.sqsh contents"
check_grep 'redstone-stage1-bench-run' "scripts/check-redstone-image.sh" \
    "image checker requires the Redstone bench runner"
check_grep 'check-redstone-image\.sh.*--squashfs|--squashfs.*check-redstone-image\.sh' \
    "scripts/build-installer.sh" \
    "build-installer checks Redstone rootfs.sqsh before packaging"
check_grep 'REQUIRE_OPENBCM_INIT_PROBE="\$\{REQUIRE_OPENBCM_INIT_PROBE:-0\}"' \
    "scripts/build-installer.sh" \
    "build-installer keeps OpenBCM init probe optional by default"
check_no_regex 'REQUIRE_OPENBCM_INIT_PROBE="\$\{REQUIRE_OPENBCM_INIT_PROBE:-1\}"' \
    "scripts/build-installer.sh" \
    "build-installer does not force OpenBCM init probe in default image builds"
check_grep 'check-redstone-image\.sh.*--squashfs|--squashfs.*check-redstone-image\.sh' \
    "scripts/build-all.sh" \
    "build-all checks Redstone rootfs.sqsh before packaging"
check_grep 'redstone-stage1-hardware-handoff\.tar\.gz' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package writes a stable tarball name"
check_grep 'redstone-web-ssh-hotfix\.tar' \
    "scripts/package-redstone-web-hotfix.sh" \
    "Redstone web hotfix package writes a stable tarball name"
check_grep 'etc/switchd' \
    "scripts/package-redstone-web-hotfix.sh" \
    "Redstone web hotfix package includes switchd config files"
check_grep 'redstone-httpd/httpd' \
    "scripts/package-redstone-web-hotfix.sh" \
    "Redstone web hotfix package creates an applet-named httpd symlink"
check_grep 'S41redstone-mgmt-web' \
    "scripts/package-redstone-web-hotfix.sh" \
    "Redstone web hotfix package includes default web init script"
check_grep 'realpath -m' \
    "scripts/package-redstone-web-hotfix.sh" \
    "Redstone web hotfix package canonicalizes output and work paths"
check_grep 'config/rootfs/overlay' \
    "scripts/package-redstone-web-hotfix.sh" \
    "Redstone web hotfix package can fall back to overlay files before rebuild"
check_grep 'First Hardware Boot Policy' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook starts with a non-destructive first-boot policy"
check_grep 'Do not overwrite internal flash' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook blocks first-run internal flash writes"
check_grep 'not a raw USB disk image' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook distinguishes ONIE payload from raw USB images"
check_grep 'package-redstone-usb-stage1\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook points to the USB stage-1 image builder"
check_grep 'redstone-usb-stage1-boot-capture\.img' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder writes a stable raw image name"
check_grep 'FAT16 type 0x06' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder documents FAT16 U-Boot partition"
check_grep 'type=6, bootable' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder creates bootable FAT16 partition"
check_grep 'Do not run saveenv' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder preserves U-Boot environment"
check_grep 'fatload usb 0:1 1000000 uImage-powerpc\.itb' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder readme uses FIT boot from FAT"
check_grep 'bootm 1000000#\$FIT_CONFIG' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 builder readme boots the selected FIT config"
check_grep 'verify_hash sha256sum' \
    "scripts/verify-redstone-usb-stage1-image.sh" \
    "Redstone USB stage-1 image verifier checks sha256 sidecar"
check_grep 'verify_hash md5sum' \
    "scripts/verify-redstone-usb-stage1-image.sh" \
    "Redstone USB stage-1 image verifier checks md5 sidecar"
check_grep 'fail "\$tool unavailable; cannot verify \$desc sidecar"' \
    "scripts/verify-redstone-usb-stage1-image.sh" \
    "Redstone USB stage-1 image verifier fails when checksum tools are missing"
check_grep 'Disklabel type:' \
    "scripts/verify-redstone-usb-stage1-image.sh" \
    "Redstone USB stage-1 image verifier checks fdisk sidecar"
check_grep 'boot-files\.txt' \
    "scripts/verify-redstone-usb-stage1-image.sh" \
    "Redstone USB stage-1 image verifier checks FAT inventory"
check_grep 'data-files\.txt' \
    "scripts/verify-redstone-usb-stage1-image.sh" \
    "Redstone USB stage-1 image verifier checks data inventory"
check_grep 'redstone_usb_stage1_operator_checklist\.md' \
    "scripts/package-redstone-usb-stage1.sh" \
    "Redstone USB stage-1 image carries the operator checklist"
check_grep 'docs/redstone_usb_stage1_operator_checklist\.md' \
    "scripts/verify-redstone-usb-stage1-image.sh" \
    "Redstone USB stage-1 image verifier requires operator checklist in data inventory"
check_grep 'redstone_usb_stage1_operator_checklist\.md' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook points to the operator checklist"
check_grep 'write_fanxiang_uboot_fat_image\.ps1' \
    "docs/redstone_usb_stage1_operator_checklist.md" \
    "operator checklist uses guarded Windows USB writer"
check_grep 'redstone-usb-stage1-verify' \
    "docs/redstone_usb_stage1_operator_checklist.md" \
    "operator checklist requires read-only USB image verification"
check_grep 'bootm 1000000#accton_as5610_52x' \
    "docs/redstone_usb_stage1_operator_checklist.md" \
    "operator checklist uses temporary FIT boot command"
check_grep 'Do not run `saveenv`' \
    "docs/redstone_usb_stage1_operator_checklist.md" \
    "operator checklist blocks saveenv"
check_grep 'Do not run `onie-nos-install`' \
    "docs/redstone_usb_stage1_operator_checklist.md" \
    "operator checklist blocks ONIE install during stage-1 capture"
check_grep 'redstone-stage1-bench-run --capture-only' \
    "docs/redstone_usb_stage1_operator_checklist.md" \
    "operator checklist includes capture-only command"
check_grep 'redstone-stage1-bench-run --iface' \
    "docs/redstone_usb_stage1_operator_checklist.md" \
    "operator checklist includes strict one-port validation command"
check_grep 'bench-run-[*]' \
    "docs/redstone_usb_stage1_operator_checklist.md" \
    "operator checklist asks operators to return bench-run diagnostic snapshots"
check_grep 'PATH_TO_VALIDATION_BUNDLE_OR_DIR' \
    "docs/redstone_usb_stage1_operator_checklist.md" \
    "operator checklist includes host analysis command"
check_grep '14e4:b846' \
    "docs/redstone_usb_stage1_operator_checklist.md" \
    "operator checklist names exact BCM56846 PCI ID evidence"
check_grep 'Optional ONIE Install' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook keeps ONIE install optional after external boot proof"
check_grep 'check-redstone-image\.sh.*--squashfs|--squashfs.*check-redstone-image\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package verifies packed rootfs.sqsh"
check_grep 'verify-redstone-hardware-handoff\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package bundles host manifest verifier"
check_grep 'analyze-redstone-handoff-capture\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package bundles combined host capture analyzer"
check_grep 'host-tools/analyze-redstone-platform-inventory\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package bundles the platform inventory analyzer"
check_grep 'bench-results/REDSTONE-BENCH-RESULT-TEMPLATE\.md' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package bundles the bench result template"
check_grep 'host-tools/prepare-redstone-bench-note\.sh' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff package bundles the bench note helper"
check_grep 'prepare-redstone-bench-note\.sh[[:space:]]+[.]' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook uses the bench note helper"
check_grep 'REDSTONE_RESULT_DIR' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook writes per-run bench notes outside the verified package"
check_no_regex 'cp[[:space:]]+bench-results/REDSTONE-BENCH-RESULT-TEMPLATE[.]md[[:space:]]+bench-results/' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook does not add per-run notes into the verified package"
check_grep 'refusing to write bench notes inside the manifest-verified handoff directory' \
    "scripts/prepare-redstone-bench-note.sh" \
    "bench note helper refuses handoff-internal result paths"
check_grep 'bench-results/REDSTONE-BENCH-RESULT-TEMPLATE\.md' \
    "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier requires the bench result template"
check_grep 'host-tools/analyze-redstone-handoff-capture\.sh' \
    "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier requires the combined host capture analyzer"
check_grep 'host-tools/analyze-redstone-platform-inventory\.sh' \
    "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier requires the platform inventory analyzer"
check_grep 'host-tools/prepare-redstone-bench-note\.sh' \
    "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier requires the bench note helper"
check_grep 'analyze-redstone-handoff-capture\.sh[[:space:]]+[.][[:space:]]+PATH_TO_VALIDATION_BUNDLE_OR_DIR' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook verifies handoff and validation bundle through one host command"
check_grep 'Stage-1 accepted: yes/no' \
    "docs/redstone_bench_result_template.md" \
    "bench result template records the stage-1 acceptance decision"
check_grep 'Strict validation bundle or directory' \
    "docs/redstone_bench_result_template.md" \
    "bench result template records strict validation evidence"
check_grep 'First Hardware Run Order' \
    "docs/redstone_stage1_plan.md" \
    "stage plan documents first hardware run order"
check_grep 'redstone_usb_uboot_fat_general4g\.img' \
    "docs/redstone_stage1_plan.md" \
    "stage plan references the known-good R0678 recovery USB artifact"
check_grep 'edgenos-redstone-stage1\.bin.*ONIE-style installer payload' \
    "docs/redstone_stage1_plan.md" \
    "stage plan distinguishes the EdgeNOS ONIE payload from raw USB images"
check_grep 'A Redstone USB stage-1 package is a separate deliverable' \
    "docs/redstone_stage1_plan.md" \
    "stage plan keeps the future USB stage-1 package as a separate non-destructive deliverable"
check_grep 'redstone-usb-stage1-boot-capture\.img' \
    "docs/redstone_stage1_plan.md" \
    "stage plan documents the Redstone USB stage-1 raw image path"
check_grep 'verify-redstone-hardware-handoff\.sh' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer runs the handoff verifier"
check_grep 'analyze-redstone-stage1-evidence\.sh' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer runs the stage-1 evidence analyzer"
check_grep 'analyze-redstone-platform-inventory\.sh' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer runs the platform inventory analyzer"
check_grep 'VERIFY_TOOL="\$SCRIPT_DIR/verify-redstone-hardware-handoff\.sh"' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer uses trusted adjacent verifier"
check_grep 'ANALYZE_TOOL="\$SCRIPT_DIR/analyze-redstone-stage1-evidence\.sh"' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer uses trusted adjacent evidence analyzer"
check_grep 'PLATFORM_TOOL="\$SCRIPT_DIR/analyze-redstone-platform-inventory\.sh"' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer uses trusted adjacent platform analyzer"
check_grep 'sh "[$]ANALYZE_TOOL" --strict' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer enforces strict capture analysis"
check_grep 'sh "[$]PLATFORM_TOOL"' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer runs platform inventory after strict analysis"
check_no_regex 'HANDOFF_ROOT|host-tools/verify-redstone-hardware-handoff\.sh|host-tools/analyze-redstone-stage1-evidence\.sh|host-tools/analyze-redstone-platform-inventory\.sh|tar[[:space:]]+-xzf.*HANDOFF' \
    "scripts/analyze-redstone-handoff-capture.sh" \
    "combined host capture analyzer avoids executing tools from handoff payloads"
check_grep 'redstone-stage1-bench-run --capture-only' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook includes first-boot capture"
check_grep 'Validation bundle:' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator emits a host-transfer validation bundle path"
check_grep 'capture-evidence' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator embeds capture evidence under its validation output"
check_grep 'Redstone stage-1 capture written to' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator parses the capture evidence path for bundling"
check_grep 'validation bundle' \
    "Makefile" \
    "Makefile documents validation bundle handoff analysis"
check_grep 'not[[:space:]]+stage-1[[:space:]]+acceptance' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook marks smoke capture as non-acceptance"
check_grep 'REDSTONE_IFACE=swpN' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook declares strict interface placeholder"
check_grep 'REDSTONE_PEER=192\.0\.2\.2' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook declares strict peer placeholder"
check_grep 'redstone-stage1-bench-run --iface' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook uses the bench runner for strict acceptance"
check_grep '--local-cidr "\\[$]REDSTONE_LOCAL_CIDR"' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook has the bench runner configure the local CIDR"
check_grep 'redstone-openbcm-bde-smoke\.sh --strict --capture' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook includes BDE smoke capture"
check_grep 'i-accept-hardware-reset-risk' \
    "scripts/package-redstone-hardware-handoff.sh" \
    "Redstone handoff runbook keeps init probe exec reset-risk gated"
check_grep 'bundle' "scripts/build-openbcm-bde.sh" \
    "OpenBCM BDE helper can bundle hardware-load artifacts"
check_grep 'redstone-openbcm-bde-smoke\.sh' "scripts/build-openbcm-bde.sh" \
    "OpenBCM BDE bundle includes the hardware smoke helper"
check_grep '14e4:b846' "scripts/redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke helper requires exact BCM56846 PCI ID"
check_no_regex "$LOOSE_BCM56846_SOURCE_RE" "scripts/redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke helper avoids vendorless lspci matches"
check_grep '14e4:b846' "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "Redstone validator checks exact BCM56846 PCI ID"
check_no_regex "$LOOSE_BCM56846_SOURCE_RE" "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "Redstone validator avoids vendorless lspci matches"
check_grep 'has_exact_bcm56846_pci_evidence' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer requires exact BCM56846 PCI ID evidence"
check_no_regex "$LOOSE_BCM56846_SOURCE_RE" "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer avoids vendorless PCI ID text matches"
check_grep 'capture-summary\.txt' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer checks expanded capture summary"
check_grep 'run_metadata\.txt' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer checks expanded run metadata"
check_grep 'pci_driver_details\.txt' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer checks PCI driver detail capture"
check_grep 'net_counters\.txt' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer checks net counter capture"
check_grep 'i2c_devices\.txt' "scripts/analyze-redstone-stage1-evidence.sh" \
    "stage-1 evidence analyzer checks passive I2C topology capture"
check_grep 'openbcm-userland-check' "Makefile" \
    "Makefile exposes OpenBCM userland init source check"
check_grep 'openbcm-bde-smoke-analyze' "Makefile" \
    "Makefile exposes OpenBCM BDE smoke evidence analyzer"
check_grep 'openbcm-init-probe' "Makefile" \
    "Makefile exposes Redstone OpenBCM init probe gate targets"
check_grep 'redstone-handoff' "Makefile" \
    "Makefile exposes Redstone hardware handoff package target"
check_grep 'redstone-handoff-verify' "Makefile" \
    "Makefile exposes Redstone hardware handoff verification target"
check_grep 'redstone-handoff-analyze' "Makefile" \
    "Makefile exposes combined Redstone handoff and capture analysis target"
check_grep 'redstone-platform-inventory-analyze' "Makefile" \
    "Makefile exposes Redstone platform inventory analysis target"
check_grep 'redstone-usb-stage1-check' "Makefile" \
    "Makefile exposes Redstone USB stage-1 prerequisite check target"
check_grep 'redstone-usb-stage1' "Makefile" \
    "Makefile exposes Redstone USB stage-1 image target"
check_grep 'redstone-usb-stage1-verify' "Makefile" \
    "Makefile exposes Redstone USB stage-1 image verifier target"
check_grep 'manifest has [$]entry_count file entries' "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier checks manifest entries"
check_grep 'sha256 mismatch' "scripts/verify-redstone-hardware-handoff.sh" \
    "Redstone handoff verifier checks file hashes"
check_grep 'loaded OpenBCM linux-kernel-bde.*ko from bundle' \
    "scripts/analyze-redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke analyzer requires kernel bundle-load proof"
check_grep 'loaded OpenBCM linux-user-bde.*ko from bundle' \
    "scripts/analyze-redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke analyzer requires user bundle-load proof"
check_grep '14e4:b846' "scripts/analyze-redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke analyzer requires exact BCM56846 PCI ID"
check_grep 'vendor=0x14e4.*device=0xb846' \
    "scripts/analyze-redstone-openbcm-bde-smoke.sh" \
    "OpenBCM BDE smoke analyzer accepts exact BCM56846 sysfs IDs"
check_grep 'BCM56846_DEVICE_ID' "scripts/check-openbcm-userland-init.sh" \
    "OpenBCM userland init preflight checks BCM56846 source coverage"
check_grep 'bcm_attach' "scripts/check-openbcm-userland-init.sh" \
    "OpenBCM userland init preflight checks SDK attach path"
check_grep 'bcm_l2_addr_add' "scripts/check-openbcm-userland-init.sh" \
    "OpenBCM userland init preflight checks L2 API path"
check_grep '14e4:b846' "asic/openbcm-init/redstone-openbcm-init-probe.c" \
    "OpenBCM init probe gates exact BCM56846 PCI ID"
check_grep 'i-accept-hardware-reset-risk' \
    "asic/openbcm-init/redstone-openbcm-init-probe.c" \
    "OpenBCM init probe requires explicit hardware reset risk acknowledgement"
check_grep 'BCM_CONFIG_FILE' "asic/openbcm-init/redstone-openbcm-init-probe.c" \
    "OpenBCM init probe sets BCM_CONFIG_FILE before demo init execution"
check_grep 'sdk_baseline=openbcm-6\.5\.27' "scripts/build-openbcm-init-probe.sh" \
    "OpenBCM init probe manifest records SDK baseline"
check_grep 'redstone-openbcm-init-probe --dry-run' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records OpenBCM init probe dry-run evidence"
check_grep 'capture_shell redstone_mgmt_status' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records Redstone management status JSON"
check_grep 'Usage: redstone-stage1-capture \[--scan-i2c\] \[--verbose\]' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture supports verbose progress output for hardware runs"
check_grep 'REDSTONE_CAPTURE_VERBOSE' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture supports a verbose environment override"
check_grep 'run_metadata\.txt' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture writes run metadata for handoff correlation"
check_grep 'capture-summary\.txt' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture writes a top-level triage summary"
check_grep 'capture_shell command_inventory' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records command availability"
check_grep 'capture_shell pci_driver_details' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records PCI driver and resource details"
check_grep 'capture_shell net_counters' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records net counters and ethtool diagnostics"
check_grep 'capture_shell modinfo_bringup' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records module metadata for bring-up drivers"
check_grep 'capture_shell i2c_devices' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records passive I2C device topology"
check_grep 'sys_class_thermal' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records thermal sysfs evidence"
check_grep 'sys_bus_platform_devices' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
    "capture records platform bus sysfs evidence"
check_grep 'redstone-openbcm-init-probe --dry-run' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator records OpenBCM init probe dry-run evidence"
check_grep 'redstone-stage1-capture --verbose' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator captures verbose hardware diagnostics"
check_grep 'strict requires --iface swpN' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator strict mode requires explicit front-panel interface"
check_grep 'strict requires --peer IP' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator strict mode requires ping peer"
check_grep 'strict --iface must be a swpN front-panel interface' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
    "validator strict mode rejects non-swp interface targets"
check_grep 'run_validate --iface "[$]IFACE" --peer "[$]PEER" --ping-count "[$]PING_COUNT" --strict --capture' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner invokes strict validation with capture"
check_grep 'redstone-stage1-validate "[$]@"' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner routes validation through the live validator"
check_grep 'Return validation bundle to the host' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner prints the host-transfer validation bundle path"
check_grep 'analyze-redstone-handoff-capture\.sh' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner prints the combined host analysis command"
check_grep 'REDSTONE_BENCH_VALIDATE_LOG' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner exposes validation log override for diagnostics"
check_grep 'REDSTONE_BENCH_DIR' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner exposes bench evidence directory override"
check_grep 'BENCH_BASE_DIR_EXPLICIT' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner tracks explicit bench evidence directory overrides"
check_grep 'failed to create explicit REDSTONE_BENCH_DIR' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner fails fast when explicit bench evidence directory is unusable"
check_grep 'capture_bench_snapshot[[:space:]]+pre' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner captures pre-run diagnostic snapshot"
check_grep 'capture_bench_snapshot[[:space:]]+prepared' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner captures prepared-interface diagnostic snapshot"
check_grep 'capture_bench_snapshot[[:space:]]+post' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner captures post-validation diagnostic snapshot"
check_grep 'Return bench run evidence directory to the host' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner prints the host-transfer bench evidence path"
check_grep 'validate-console[.]log' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner preserves validator console output"
check_grep 'phase}_bde_pci' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner snapshots BDE and PCI state"
check_grep 'dmesg_focus' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner snapshots focused kernel diagnostics"
check_grep '--local-cidr' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner supports local CIDR setup"
check_grep 'redstone-openbcm-bde-smoke\.sh' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner can locate the optional OpenBCM BDE smoke helper"
check_no_regex 'i-accept-hardware-reset-risk|redstone-openbcm-init-probe[[:space:]]+--exec' \
    "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
    "bench runner does not invoke reset-risk init probe exec path"
check_grep 'redstone-mgmt-status' \
    "config/rootfs/overlay/www/cgi-bin/redstone-status" \
    "management CGI delegates to the read-only status provider"
check_grep 'redstone-mgmt-artifact' \
    "config/rootfs/overlay/www/cgi-bin/redstone-artifact" \
    "artifact CGI delegates to the read-only artifact provider"
check_grep 'exec /usr/sbin/redstone-mgmt-artifact' \
    "config/rootfs/overlay/www/cgi-bin/redstone-artifact" \
    "artifact CGI uses an absolute provider path"
check_grep 'redstone-mgmt-evidence' \
    "config/rootfs/overlay/www/cgi-bin/redstone-evidence" \
    "evidence CGI delegates to the read-only evidence provider"
check_grep 'exec /usr/sbin/redstone-mgmt-evidence' \
    "config/rootfs/overlay/www/cgi-bin/redstone-evidence" \
    "evidence CGI uses an absolute provider path"
check_grep 'capture_runs' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-evidence" \
    "evidence provider lists capture runs"
check_grep 'validation_runs' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-evidence" \
    "evidence provider lists validation runs"
check_grep 'bench_runs' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-evidence" \
    "evidence provider lists bench runs"
check_grep 'web_actions' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-evidence" \
    "evidence provider lists web actions"
check_grep 'redstone-mgmt-artifact.v1' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact" \
    "artifact provider emits a versioned schema"
check_grep 'resolve_run_dir' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact" \
    "artifact provider constrains reads to known run directories"
check_grep 'file_key.*_files|emit_file_list' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact" \
    "artifact provider can list run files for development diagnostics"
check_grep 'Content-Disposition: attachment' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact" \
    "artifact provider supports safe downloads"
check_no_regex 'i-accept-hardware-reset-risk|redstone-openbcm-init-probe[[:space:]]+--exec|saveenv|onie-nos-install' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact" \
    "artifact provider does not expose destructive actions"
check_grep 'capture|validate-capture|bench-capture' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI accepts the capture action"
check_grep 'capture|validate-capture|bench-capture' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI accepts validation capture"
check_grep 'capture|validate-capture|bench-capture' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI accepts bench capture"
check_grep 'validate-strict' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI accepts strict validation"
check_grep 'bde-smoke' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI accepts BDE smoke"
check_grep 'init-probe-dry-run' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI accepts init-probe dry run"
check_grep 'redstone-stage1-capture --verbose' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI runs the capture tool"
check_grep '/usr/sbin/redstone-stage1-capture --verbose' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI uses an absolute capture tool path"
check_grep 'redstone-stage1-validate --capture' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI runs non-strict validation capture"
check_grep '/usr/sbin/redstone-stage1-validate --capture' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI uses an absolute validation tool path"
check_grep 'redstone-stage1-bench-run --capture-only' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI runs capture-only bench evidence"
check_grep '/usr/sbin/redstone-stage1-bench-run --capture-only' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI uses an absolute bench tool path"
check_grep 'redstone-stage1-bench-run --iface' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI runs parameterized strict validation"
check_grep 'redstone-openbcm-bde-smoke\.sh --strict --capture' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI runs BDE smoke capture"
check_grep '/usr/sbin/redstone-openbcm-init-probe --dry-run' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI runs init-probe dry run only"
check_grep 'mkdir "\$LOCK_DIR"' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI uses a single-action lock"
check_grep '\[ -d "\$LOCK_DIR" \]' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI reports running only for existing lock directories"
check_no_regex 'i-accept-hardware-reset-risk|redstone-openbcm-init-probe[[:space:]]+--exec|saveenv|onie-nos-install' \
    "config/rootfs/overlay/www/cgi-bin/redstone-action" \
    "management action CGI does not expose destructive actions"
check_grep '0[.]0[.]0[.]0:8080' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-web" \
    "management web launcher binds externally by default in development builds"
check_grep 'redstone-mgmt-web' \
    "config/rootfs/overlay/etc/init.d/S41redstone-mgmt-web" \
    "management web UI auto-starts from Redstone BusyBox init"
check_grep 'redstone|rs2020|r0678' \
    "config/rootfs/overlay/etc/init.d/S41redstone-mgmt-web" \
    "management web init is gated to Redstone board aliases"
check_grep 'httpd_help_looks_usable' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-web" \
    "management web launcher validates httpd before exec"
check_grep 'httpd_help_looks_usable' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-status" \
    "management status validates runnable httpd applet availability"
check_no_regex 'redstone-mgmt-web|httpd' \
    "config/rootfs/overlay/etc/init.d/S20edgenos" \
    "legacy switchd init does not start the management web UI"
check_no_regex 'redstone-mgmt-web|httpd' \
    "config/rootfs/overlay/etc/systemd/system/switchd.service" \
    "management web UI is not auto-started by switchd service"
check_no_regex 'i-accept-hardware-reset-risk|redstone-openbcm-init-probe[[:space:]]+--exec|saveenv|onie-nos-install' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management web UI does not expose destructive actions"
check_no_regex 'i-accept-hardware-reset-risk|redstone-openbcm-init-probe[[:space:]]+--exec|saveenv|onie-nos-install' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-evidence" \
    "evidence provider does not expose destructive actions"
check_grep 'web_action' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-status" \
    "management status reports latest web action"
check_grep 'latest_validate_dir' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-status" \
    "management status reports latest validation evidence"
check_grep 'validation_summary' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-status" \
    "management status reports validation summary counts"
check_grep 'log_exists' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-status" \
    "management status reports validation log existence"
check_grep 'init_probe_dry_run' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-status" \
    "management status reports init-probe dry-run evidence"
check_grep 'bde_smoke_exit' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-status" \
    "management status reports BDE smoke evidence"
check_grep 'front_panel' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-status" \
    "management status reports front-panel port state"
check_grep 'profile' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-status" \
    "management status reports development profile"
check_grep 'analysis' \
    "config/rootfs/overlay/usr/sbin/redstone-mgmt-status" \
    "management status reports gate analysis"
check_grep 'latest-validate-dir' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays validation evidence directory"
check_grep 'validation-summary' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays validation summary"
check_grep 'bench-validate-exit' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays bench validation exit"
check_grep 'init-probe' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays init-probe dry-run status"
check_grep 'run-capture' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page exposes the capture action button"
check_grep 'run-validate' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page exposes the validation capture action button"
check_grep 'run-bench' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page exposes the bench capture action button"
check_grep 'run-strict' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page exposes the strict validation action button"
check_grep 'strict-local-cidr' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page exposes local CIDR input"
check_grep 'run-bde-smoke' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page exposes the BDE smoke action button"
check_grep 'run-init-probe' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page exposes the init-probe dry-run action button"
check_grep 'front-panel-ports' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays front-panel ports"
check_grep 'Analysis Summary' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays gate analysis summary"
check_grep 'capture-runs' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays capture evidence runs"
check_grep 'validation-runs' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays validation evidence runs"
check_grep 'bench-runs' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays bench evidence runs"
check_grep 'action-runs' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays web action evidence runs"
check_grep 'artifact-detail-panel' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays artifact details"
check_grep 'artifact-download' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page exposes artifact downloads"
check_grep 'OpenBCM Tools' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays OpenBCM tool readiness"
check_grep 'Direct Boot Gate' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management page displays direct-boot management Ethernet caveat"
check_grep 'validationLabel' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management UI formats validation summary"
check_grep 'log_exists' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management UI gates validation state on log existence"
check_grep 'probeLabel' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management UI formats init-probe dry-run status"
check_grep 'redstone-action[?]action=capture|actionUrl' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management UI calls the capture action endpoint"
check_grep 'redstone-evidence|evidenceUrl' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management UI calls the evidence endpoint"
check_grep 'redstone-artifact|artifactUrl' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management UI calls the artifact endpoint"
check_grep 'startActionPolling' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management UI polls status after web actions"
check_grep 'showArtifact' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management UI renders artifact detail content"
check_grep 'actionParams' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management UI passes action parameters"
check_grep 'renderFrontPanel' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management UI renders front-panel port tiles"
check_grep '_files' \
    "config/rootfs/overlay/www/redstone/redstone.js" \
    "management UI can list files in a run directory"
check_grep 'artifact-tail' \
    "config/rootfs/overlay/www/redstone/redstone.css" \
    "management stylesheet formats artifact detail text"
check_grep 'field-grid' \
    "config/rootfs/overlay/www/redstone/redstone.css" \
    "management stylesheet formats strict validation inputs"
check_grep 'port-grid' \
    "config/rootfs/overlay/www/redstone/redstone.css" \
    "management stylesheet formats front-panel ports"
check_grep 'validate-capture' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management UI can run validation capture"
check_grep 'bench-capture' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management UI can run bench capture"
check_grep 'validate-strict' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management UI can run strict validation"
check_grep 'bde-smoke' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management UI can run BDE smoke"
check_grep 'init-probe-dry-run' \
    "config/rootfs/overlay/www/redstone/index.html" \
    "management UI can run init-probe dry run"
check_grep 'redstone-mgmt-status' "docs/redstone_web_mgmt_plan.md" \
    "web management plan documents the read-only status provider"
check_grep 'redstone-mgmt-evidence' "docs/redstone_web_mgmt_plan.md" \
    "web management plan documents the read-only evidence provider"
check_grep 'redstone-mgmt-artifact' "docs/redstone_web_mgmt_plan.md" \
    "web management plan documents the artifact provider"
check_grep 'redstone-evidence' "docs/redstone_web_mgmt_plan.md" \
    "web management plan documents the evidence CGI endpoint"
check_grep 'redstone-artifact' "docs/redstone_web_mgmt_plan.md" \
    "web management plan documents the artifact CGI endpoint"
check_grep 'redstone-action[?]action=capture' "docs/redstone_web_mgmt_plan.md" \
    "web management plan documents the capture action endpoint"
check_grep 'redstone-action[?]action=validate-capture' "docs/redstone_web_mgmt_plan.md" \
    "web management plan documents the validation capture action endpoint"
check_grep 'redstone-action[?]action=bench-capture' "docs/redstone_web_mgmt_plan.md" \
    "web management plan documents the bench capture action endpoint"
check_grep '0[.]0[.]0[.]0:8080' "docs/redstone_web_mgmt_plan.md" \
    "web management plan documents development default bind"
check_grep 'must not:' "docs/redstone_web_mgmt_plan.md" \
    "web management plan records safety boundaries"
check_grep 'redstone-mgmt-web' "docs/redstone_stage1_plan.md" \
    "stage plan documents web management launcher"
check_grep 'redstone-mgmt-evidence' "docs/redstone_stage1_plan.md" \
    "stage plan documents the web evidence provider"
check_grep 'redstone-mgmt-artifact' "docs/redstone_stage1_plan.md" \
    "stage plan documents the web artifact provider"
check_grep 'U-Boot-good BCM54616S/SerDes' "docs/redstone_stage1_plan.md" \
    "stage plan records the management SGMII boot caveat"
check_grep 'Direct USB/flash boot management matrix' "docs/redstone_stage1_plan.md" \
    "stage plan records the direct boot management validation matrix"
check_grep 'redstone-original-active-sdk' "docs/redstone_stage1_plan.md" \
    "stage plan documents the original-active SDK reference manifest"
check_grep 'redstone-original-active-sdk' "docs/redstone_progress.md" \
    "progress log records the original-active SDK reference work"
check_grep 'redstone-original-active-sdk' "docs/redstone_followup_intel.md" \
    "follow-up intelligence names the original-active SDK reference"
check_grep 'validate-capture' "docs/redstone_progress.md" \
    "progress log records the validation capture web action"
check_grep 'ordinary U-Boot boot path' "docs/redstone_followup_intel.md" \
    "follow-up intelligence records the direct-boot SGMII caveat"

check_unusable_explicit_dir() {
    label=$1
    env_name=$2
    script=$3
    expected=$4
    shift 4

    tmpdir=$(mktemp -d)
    bad_path=$tmpdir/not-a-directory
    out=$tmpdir/${label}.out
    : > "$bad_path"

    if env "$env_name=$bad_path" sh "$TOPDIR/$script" "$@" > "$out" 2>&1; then
        fail "$label accepts unusable explicit $env_name"
    elif grep -q "$expected" "$out"; then
        ok "$label rejects unusable explicit $env_name"
    else
        fail "$label rejection did not identify explicit $env_name"
    fi

    rm -rf "$tmpdir"
}

check_mgmt_status_portmap_formats() {
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/switchd"
    cat > "$tmpdir/switchd/redstone-stage1.bcm" <<EOF
portmap_1.0=1:10
portmap_49.0=61:40
EOF
    printf 'redstone\n' > "$tmpdir/board"
    REDSTONE_BOARD_FILE="$tmpdir/board" \
        REDSTONE_SWITCHD_CONFIG_DIR="$tmpdir/switchd" \
        sh "$TOPDIR/config/rootfs/overlay/usr/sbin/redstone-mgmt-status" > "$tmpdir/status.json"

    if grep -q '"portmap_count": 2' "$tmpdir/status.json" && \
        grep -q '"split_mode": "stage1-skeleton-4x40g"' "$tmpdir/status.json"; then
        ok "management status counts portmap_N.0 config keys"
    else
        fail "management status does not count portmap_N.0 config keys"
    fi

    rm -rf "$tmpdir"
}

check_mgmt_status_evidence_index() {
    tmpdir=$(mktemp -d)
    evidence="$tmpdir/evidence"
    mkdir -p "$tmpdir/switchd" \
        "$tmpdir/net/swp1" \
        "$evidence/20260304T010203Z" \
        "$evidence/validate-20260304T010204Z" \
        "$evidence/bench-run-20260304T010205Z" \
        "$evidence/web-actions/20260304T010206Z-capture"
    cat > "$tmpdir/switchd/redstone-stage1.bcm" <<EOF
portmap_1=1:10
portmap_49=61:40
EOF
    printf 'redstone\n' > "$tmpdir/board"
    printf '1\n' > "$tmpdir/net/swp1/carrier"
    printf 'up\n' > "$tmpdir/net/swp1/operstate"
    printf '00:e0:ec:53:b8:31\n' > "$tmpdir/net/swp1/address"
    printf 'summary\n' > "$evidence/20260304T010203Z/capture-summary.txt"
    : > "$evidence/20260304T010203Z.tar.gz"
    : > "$evidence/validate-20260304T010204Z.tar.gz"
    cat > "$evidence/validate-20260304T010204Z/validate.log" <<EOF
PASS: config present
WARN: switchd stopped
FAIL: bde missing
Redstone stage-1 validation complete: 1 pass, 1 warning(s), 1 failure(s)
Evidence directory: /var/log/redstone-stage1/validate-20260304T010204Z
Validation bundle: /var/log/redstone-stage1/validate-20260304T010204Z.tar.gz
EOF
    cat > "$evidence/validate-20260304T010204Z/openbcm_init_probe_dry_run.txt" <<EOF
$ redstone-openbcm-init-probe --dry-run

exit=0
EOF
    cat > "$evidence/bench-run-20260304T010205Z/bench-run.log" <<EOF
capture_only=0
validate_exit=0
validation_bundle=/var/log/redstone-stage1/validate-20260304T010204Z.tar.gz
validation_evidence_dir=/var/log/redstone-stage1/validate-20260304T010204Z
bde_smoke_exit=0
EOF
    cat > "$evidence/web-actions/20260304T010206Z-capture/result.env" <<EOF
action=capture
status=success
exit=0
started_at=2026-03-04T01:02:06Z
finished_at=2026-03-04T01:02:07Z
run_dir=/var/log/redstone-stage1/web-actions/20260304T010206Z-capture
log=/var/log/redstone-stage1/web-actions/20260304T010206Z-capture/action.log
evidence_dir=/var/log/redstone-stage1/20260304T010203Z
message=capture completed
EOF

    REDSTONE_BOARD_FILE="$tmpdir/board" \
        REDSTONE_SWITCHD_CONFIG_DIR="$tmpdir/switchd" \
        REDSTONE_CAPTURE_DIR="$evidence" \
        REDSTONE_VALIDATE_DIR="$evidence" \
        REDSTONE_BENCH_DIR="$evidence" \
        REDSTONE_WEB_ACTION_DIR="$evidence/web-actions" \
        REDSTONE_NET_CLASS_DIR="$tmpdir/net" \
        sh "$TOPDIR/config/rootfs/overlay/usr/sbin/redstone-mgmt-status" > "$tmpdir/status.json"

    if grep -q '"latest_capture_dir":' "$tmpdir/status.json" && \
        grep -q '"latest_validate_dir":' "$tmpdir/status.json" && \
        grep -q '"latest_bench_dir":' "$tmpdir/status.json" && \
        grep -q '"log_exists": true' "$tmpdir/status.json" && \
        grep -q '"pass_count": 1' "$tmpdir/status.json" && \
        grep -q '"warn_count": 1' "$tmpdir/status.json" && \
        grep -q '"fail_count": 1' "$tmpdir/status.json" && \
        grep -q '"validate_exit": "0"' "$tmpdir/status.json" && \
        grep -q '"bde_smoke_exit": "0"' "$tmpdir/status.json" && \
        grep -q '"web_action":' "$tmpdir/status.json" && \
        grep -q '"action": "capture"' "$tmpdir/status.json" && \
        grep -q '"init_probe_dry_run":' "$tmpdir/status.json" && \
        grep -q '"exit": "0"' "$tmpdir/status.json" && \
        grep -q '"front_panel":' "$tmpdir/status.json" && \
        grep -q '"swp_present_count": 1' "$tmpdir/status.json" && \
        grep -q '"swp_link_up_count": 1' "$tmpdir/status.json" && \
        grep -q '"name": "swp1"' "$tmpdir/status.json" && \
        grep -q '"analysis":' "$tmpdir/status.json" && \
        grep -q '"strict_validation_ready": true' "$tmpdir/status.json"; then
        ok "management status indexes capture, validation, bench, web action, and dry-run evidence"
    else
        fail "management status does not index evidence outputs"
    fi

    rm -rf "$tmpdir"
}

check_mgmt_evidence_index() {
    tmpdir=$(mktemp -d)
    evidence="$tmpdir/evidence"
    mkdir -p \
        "$evidence/20260304T010203Z" \
        "$evidence/validate-20260304T010204Z" \
        "$evidence/bench-run-20260304T010205Z" \
        "$evidence/web-actions/20260304T010206Z-capture"

    printf 'summary line\n' > "$evidence/20260304T010203Z/capture-summary.txt"
    : > "$evidence/20260304T010203Z.tar.gz"
    : > "$evidence/validate-20260304T010204Z.tar.gz"
    cat > "$evidence/validate-20260304T010204Z/validate.log" <<EOF
PASS: config present
WARN: switchd stopped
FAIL: bde missing
Redstone stage-1 validation complete: 1 pass, 1 warning(s), 1 failure(s)
Evidence directory: /var/log/redstone-stage1/validate-20260304T010204Z
Validation bundle: /var/log/redstone-stage1/validate-20260304T010204Z.tar.gz
EOF
    cat > "$evidence/bench-run-20260304T010205Z/bench-run.log" <<EOF
capture_only=1
validate_exit=0
validation_bundle=/var/log/redstone-stage1/validate-20260304T010204Z.tar.gz
validation_evidence_dir=/var/log/redstone-stage1/validate-20260304T010204Z
bde_smoke_exit=
EOF
    cat > "$evidence/web-actions/20260304T010206Z-capture/result.env" <<EOF
action=capture
status=success
exit=0
started_at=2026-03-04T01:02:06Z
finished_at=2026-03-04T01:02:07Z
run_dir=/var/log/redstone-stage1/web-actions/20260304T010206Z-capture
log=$evidence/web-actions/20260304T010206Z-capture/action.log
evidence_dir=/var/log/redstone-stage1/20260304T010203Z
message=capture completed
EOF
    printf 'fake action log\n' > "$evidence/web-actions/20260304T010206Z-capture/action.log"

    REDSTONE_CAPTURE_DIR="$evidence" \
        REDSTONE_VALIDATE_DIR="$evidence" \
        REDSTONE_BENCH_DIR="$evidence" \
        REDSTONE_WEB_ACTION_DIR="$evidence/web-actions" \
        REDSTONE_EVIDENCE_LIMIT=4 \
        sh "$TOPDIR/config/rootfs/overlay/usr/sbin/redstone-mgmt-evidence" > "$tmpdir/evidence.json"

    if grep -q '"schema": "redstone-mgmt-evidence.v1"' "$tmpdir/evidence.json" && \
        grep -q '"capture_runs":' "$tmpdir/evidence.json" && \
        grep -q '"validation_runs":' "$tmpdir/evidence.json" && \
        grep -q '"bench_runs":' "$tmpdir/evidence.json" && \
        grep -q '"web_actions":' "$tmpdir/evidence.json" && \
        grep -q '"pass_count": 1' "$tmpdir/evidence.json" && \
        grep -q '"warn_count": 1' "$tmpdir/evidence.json" && \
        grep -q '"fail_count": 1' "$tmpdir/evidence.json" && \
        grep -q '"capture_only": "1"' "$tmpdir/evidence.json" && \
        grep -q '"status": "success"' "$tmpdir/evidence.json" && \
        grep -q '"log_tail":' "$tmpdir/evidence.json"; then
        ok "management evidence provider indexes recent capture, validation, bench, and action runs"
    else
        fail "management evidence provider does not index recent runs"
    fi

    rm -rf "$tmpdir"
}

check_mgmt_artifact_provider() {
    tmpdir=$(mktemp -d)
    evidence="$tmpdir/evidence"
    mkdir -p \
        "$evidence/20260304T010203Z" \
        "$evidence/validate-20260304T010204Z" \
        "$evidence/bench-run-20260304T010205Z" \
        "$evidence/web-actions/20260304T010206Z-capture"

    cat > "$evidence/20260304T010203Z/capture-summary.txt" <<EOF
capture summary first
capture summary second
EOF
    printf 'registers\n' > "$evidence/20260304T010203Z/gianfar_registers.txt"
    printf 'archive bytes\n' > "$evidence/20260304T010203Z.tar.gz"
    printf 'PASS: validation\n' > "$evidence/validate-20260304T010204Z/validate.log"
    printf 'bench log\n' > "$evidence/bench-run-20260304T010205Z/bench-run.log"
    printf 'action log\n' > "$evidence/web-actions/20260304T010206Z-capture/action.log"

    REQUEST_METHOD=GET \
        QUERY_STRING='kind=capture&run=20260304T010203Z&file=capture-summary.txt' \
        REDSTONE_CAPTURE_DIR="$evidence" \
        sh "$TOPDIR/config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact" > "$tmpdir/artifact.json"
    if grep -q '"schema": "redstone-mgmt-artifact.v1"' "$tmpdir/artifact.json" && \
        grep -q '"status": "ok"' "$tmpdir/artifact.json" && \
        grep -q 'capture summary second' "$tmpdir/artifact.json" && \
        grep -q '"download_url":' "$tmpdir/artifact.json"; then
        ok "artifact provider returns safe capture file details"
    else
        fail "artifact provider did not return capture file details"
    fi

    REQUEST_METHOD=GET \
        QUERY_STRING='kind=capture&run=20260304T010203Z&file=gianfar_registers.txt' \
        REDSTONE_CAPTURE_DIR="$evidence" \
        sh "$TOPDIR/config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact" > "$tmpdir/registers.json"
    if grep -q '"status": "ok"' "$tmpdir/registers.json" && \
        grep -q 'registers' "$tmpdir/registers.json"; then
        ok "artifact provider allows development access to safe run files"
    else
        fail "artifact provider blocked a safe run file"
    fi

    REQUEST_METHOD=GET \
        QUERY_STRING='kind=capture&run=20260304T010203Z&file=_files' \
        REDSTONE_CAPTURE_DIR="$evidence" \
        sh "$TOPDIR/config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact" > "$tmpdir/files.json"
    if grep -q '"files":' "$tmpdir/files.json" && \
        grep -q '"capture-summary.txt"' "$tmpdir/files.json" && \
        grep -q '"gianfar_registers.txt"' "$tmpdir/files.json"; then
        ok "artifact provider lists direct run files"
    else
        fail "artifact provider did not list direct run files"
    fi

    REQUEST_METHOD=GET \
        QUERY_STRING='kind=capture&run=20260304T010203Z&file=archive&download=1' \
        REDSTONE_CAPTURE_DIR="$evidence" \
        sh "$TOPDIR/config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact" > "$tmpdir/download.bin"
    if grep -q 'Content-Disposition: attachment; filename="20260304T010203Z.tar.gz"' "$tmpdir/download.bin" && \
        grep -q 'archive bytes' "$tmpdir/download.bin"; then
        ok "artifact provider serves safe run downloads"
    else
        fail "artifact provider did not serve safe run download"
    fi

    REQUEST_METHOD=GET \
        QUERY_STRING='kind=capture&run=../bad&file=capture-summary.txt' \
        REDSTONE_CAPTURE_DIR="$evidence" \
        sh "$TOPDIR/config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact" > "$tmpdir/reject.json"
    if grep -q '"status": "rejected"' "$tmpdir/reject.json"; then
        ok "artifact provider rejects path traversal selectors"
    else
        fail "artifact provider did not reject path traversal selectors"
    fi

    rm -rf "$tmpdir"
}

check_mgmt_status_missing_validation_log() {
    tmpdir=$(mktemp -d)
    evidence="$tmpdir/evidence"
    mkdir -p "$tmpdir/switchd" "$evidence/validate-20260304T020304Z"
    cat > "$tmpdir/switchd/redstone-stage1.bcm" <<EOF
portmap_1=1:10
EOF
    printf 'redstone\n' > "$tmpdir/board"

    REDSTONE_BOARD_FILE="$tmpdir/board" \
        REDSTONE_SWITCHD_CONFIG_DIR="$tmpdir/switchd" \
        REDSTONE_VALIDATE_DIR="$evidence" \
        sh "$TOPDIR/config/rootfs/overlay/usr/sbin/redstone-mgmt-status" > "$tmpdir/status.json"

    if grep -q '"latest_validate_dir":' "$tmpdir/status.json" && \
        grep -q '"log_exists": false' "$tmpdir/status.json" && \
        grep -q '"pass_count": 0' "$tmpdir/status.json" && \
        grep -q '"warn_count": 0' "$tmpdir/status.json" && \
        grep -q '"fail_count": 0' "$tmpdir/status.json"; then
        ok "management status marks missing validation log explicitly"
    else
        fail "management status does not mark missing validation log explicitly"
    fi

    rm -rf "$tmpdir"
}

check_web_action_cgi() {
    tmpdir=$(mktemp -d)
    fake_capture="$tmpdir/fake-capture.sh"
    fake_validate="$tmpdir/fake-validate.sh"
    fake_bench="$tmpdir/fake-bench.sh"
    fake_strict="$tmpdir/fake-strict.sh"
    fake_bde="$tmpdir/fake-bde.sh"
    fake_probe="$tmpdir/fake-probe.sh"
    cat > "$fake_capture" <<EOF
#!/bin/sh
echo "fake capture"
echo "Redstone stage-1 capture written to /var/log/redstone-stage1/20260304T020000Z"
EOF
    cat > "$fake_validate" <<EOF
#!/bin/sh
echo "fake validation"
echo "Redstone stage-1 validation complete: 1 pass, 0 warning(s), 0 failure(s)"
echo "Evidence directory: /var/log/redstone-stage1/validate-20260304T020100Z"
echo "Validation bundle: /var/log/redstone-stage1/validate-20260304T020100Z.tar.gz"
EOF
    cat > "$fake_bench" <<EOF
#!/bin/sh
echo "fake bench capture"
echo "Return bench run evidence directory to the host: /var/log/redstone-stage1/bench-run-20260304T020200Z"
EOF
    cat > "$fake_strict" <<EOF
#!/bin/sh
echo "fake strict validation"
echo "Return bench run evidence directory to the host: /var/log/redstone-stage1/bench-run-20260304T020300Z"
EOF
    cat > "$fake_bde" <<EOF
#!/bin/sh
echo "fake BDE smoke"
echo "Evidence directory: /var/log/redstone-stage1/openbcm-bde-smoke-20260304T020400Z"
EOF
    cat > "$fake_probe" <<EOF
#!/bin/sh
echo "fake init probe dry run"
echo "Evidence directory: /var/log/redstone-stage1/init-probe-dry-run-20260304T020500Z"
EOF

    REQUEST_METHOD=POST \
        PATH=/usr/bin:/bin \
        QUERY_STRING=action=capture \
        REDSTONE_WEB_ACTION_DIR="$tmpdir/actions" \
        REDSTONE_WEB_ACTION_LOCK="$tmpdir/action.lock" \
        REDSTONE_CAPTURE_CMD="sh $fake_capture" \
        sh "$TOPDIR/config/rootfs/overlay/www/cgi-bin/redstone-action" > "$tmpdir/capture.json"
    result_env=$(find "$tmpdir/actions" -name result.env -type f 2>/dev/null | head -n 1)

    if grep -q '"status": "success"' "$tmpdir/capture.json" && \
        grep -q '"action": "capture"' "$tmpdir/capture.json" && \
        grep -q '"evidence_dir": "/var/log/redstone-stage1/20260304T020000Z"' "$tmpdir/capture.json" && \
        [ -n "$result_env" ] && \
        grep -q '^status=success$' "$result_env"; then
        ok "management action CGI runs capture and records action evidence"
    else
        fail "management action CGI did not record a successful capture action"
    fi

    REQUEST_METHOD=POST \
        PATH=/usr/bin:/bin \
        QUERY_STRING=action=validate-capture \
        REDSTONE_WEB_ACTION_DIR="$tmpdir/validate-actions" \
        REDSTONE_WEB_ACTION_LOCK="$tmpdir/validate.lock" \
        REDSTONE_VALIDATE_CMD="sh $fake_validate" \
        sh "$TOPDIR/config/rootfs/overlay/www/cgi-bin/redstone-action" > "$tmpdir/validate.json"
    if grep -q '"status": "success"' "$tmpdir/validate.json" && \
        grep -q '"action": "validate-capture"' "$tmpdir/validate.json" && \
        grep -q '"evidence_dir": "/var/log/redstone-stage1/validate-20260304T020100Z"' "$tmpdir/validate.json"; then
        ok "management action CGI runs validation capture and returns evidence"
    else
        fail "management action CGI did not record validation capture evidence"
    fi

    REQUEST_METHOD=POST \
        PATH=/usr/bin:/bin \
        QUERY_STRING=action=bench-capture \
        REDSTONE_WEB_ACTION_DIR="$tmpdir/bench-actions" \
        REDSTONE_WEB_ACTION_LOCK="$tmpdir/bench.lock" \
        REDSTONE_BENCH_CMD="sh $fake_bench" \
        sh "$TOPDIR/config/rootfs/overlay/www/cgi-bin/redstone-action" > "$tmpdir/bench.json"
    if grep -q '"status": "success"' "$tmpdir/bench.json" && \
        grep -q '"action": "bench-capture"' "$tmpdir/bench.json" && \
        grep -q '"evidence_dir": "/var/log/redstone-stage1/bench-run-20260304T020200Z"' "$tmpdir/bench.json"; then
        ok "management action CGI runs bench capture and returns evidence"
    else
        fail "management action CGI did not record bench capture evidence"
    fi

    REQUEST_METHOD=POST \
        PATH=/usr/bin:/bin \
        QUERY_STRING='action=validate-strict&iface=swp1&local_cidr=192.0.2.1%2F24&peer=192.0.2.2&ping_count=3' \
        REDSTONE_WEB_ACTION_DIR="$tmpdir/strict-actions" \
        REDSTONE_WEB_ACTION_LOCK="$tmpdir/strict.lock" \
        REDSTONE_STRICT_CMD="sh $fake_strict" \
        sh "$TOPDIR/config/rootfs/overlay/www/cgi-bin/redstone-action" > "$tmpdir/strict.json"
    strict_env=$(find "$tmpdir/strict-actions" -name result.env -type f 2>/dev/null | head -n 1)
    if grep -q '"status": "success"' "$tmpdir/strict.json" && \
        grep -q '"action": "validate-strict"' "$tmpdir/strict.json" && \
        grep -q '"evidence_dir": "/var/log/redstone-stage1/bench-run-20260304T020300Z"' "$tmpdir/strict.json" && \
        [ -n "$strict_env" ] && \
        grep -q '^local_cidr=192.0.2.1/24$' "$strict_env"; then
        ok "management action CGI runs strict validation with safe parameters"
    else
        fail "management action CGI did not record strict validation evidence"
    fi

    REQUEST_METHOD=POST \
        PATH=/usr/bin:/bin \
        QUERY_STRING='action=validate-strict&iface=eth1&local_cidr=192.0.2.1%2F24&peer=192.0.2.2' \
        REDSTONE_WEB_ACTION_DIR="$tmpdir/strict-reject-actions" \
        REDSTONE_WEB_ACTION_LOCK="$tmpdir/strict-reject.lock" \
        REDSTONE_STRICT_CMD="sh $fake_strict" \
        sh "$TOPDIR/config/rootfs/overlay/www/cgi-bin/redstone-action" > "$tmpdir/strict-reject.json"
    if grep -q '"status": "rejected"' "$tmpdir/strict-reject.json"; then
        ok "management action CGI rejects non-front-panel strict validation interfaces"
    else
        fail "management action CGI accepted an invalid strict validation interface"
    fi

    REQUEST_METHOD=POST \
        PATH=/usr/bin:/bin \
        QUERY_STRING=action=bde-smoke \
        REDSTONE_WEB_ACTION_DIR="$tmpdir/bde-actions" \
        REDSTONE_WEB_ACTION_LOCK="$tmpdir/bde.lock" \
        REDSTONE_BDE_SMOKE_CMD="sh $fake_bde" \
        sh "$TOPDIR/config/rootfs/overlay/www/cgi-bin/redstone-action" > "$tmpdir/bde.json"
    if grep -q '"status": "success"' "$tmpdir/bde.json" && \
        grep -q '"action": "bde-smoke"' "$tmpdir/bde.json" && \
        grep -q '"evidence_dir": "/var/log/redstone-stage1/openbcm-bde-smoke-20260304T020400Z"' "$tmpdir/bde.json"; then
        ok "management action CGI runs BDE smoke and returns evidence"
    else
        fail "management action CGI did not record BDE smoke evidence"
    fi

    REQUEST_METHOD=POST \
        PATH=/usr/bin:/bin \
        QUERY_STRING='action=init-probe-dry-run&config=original-active' \
        REDSTONE_WEB_ACTION_DIR="$tmpdir/probe-actions" \
        REDSTONE_WEB_ACTION_LOCK="$tmpdir/probe.lock" \
        REDSTONE_INIT_PROBE_CMD="sh $fake_probe" \
        sh "$TOPDIR/config/rootfs/overlay/www/cgi-bin/redstone-action" > "$tmpdir/probe.json"
    probe_env=$(find "$tmpdir/probe-actions" -name result.env -type f 2>/dev/null | head -n 1)
    if grep -q '"status": "success"' "$tmpdir/probe.json" && \
        grep -q '"action": "init-probe-dry-run"' "$tmpdir/probe.json" && \
        grep -q '"evidence_dir": "/var/log/redstone-stage1/init-probe-dry-run-20260304T020500Z"' "$tmpdir/probe.json" && \
        [ -n "$probe_env" ] && \
        grep -q '^config=original-active$' "$probe_env"; then
        ok "management action CGI runs init-probe dry run with selected config"
    else
        fail "management action CGI did not record init-probe dry-run evidence"
    fi

    REQUEST_METHOD=POST \
        PATH=/usr/bin:/bin \
        QUERY_STRING=action=reset \
        REDSTONE_WEB_ACTION_DIR="$tmpdir/reject-actions" \
        REDSTONE_WEB_ACTION_LOCK="$tmpdir/reject.lock" \
        REDSTONE_CAPTURE_CMD="sh $fake_capture" \
        sh "$TOPDIR/config/rootfs/overlay/www/cgi-bin/redstone-action" > "$tmpdir/reject.json"
    if grep -q '"status": "rejected"' "$tmpdir/reject.json"; then
        ok "management action CGI rejects unsupported actions"
    else
        fail "management action CGI did not reject unsupported actions"
    fi

    mkdir "$tmpdir/held.lock"
    REQUEST_METHOD=POST \
        PATH=/usr/bin:/bin \
        QUERY_STRING=action=capture \
        REDSTONE_WEB_ACTION_DIR="$tmpdir/locked-actions" \
        REDSTONE_WEB_ACTION_LOCK="$tmpdir/held.lock" \
        REDSTONE_CAPTURE_CMD="sh $fake_capture" \
        sh "$TOPDIR/config/rootfs/overlay/www/cgi-bin/redstone-action" > "$tmpdir/locked.json"
    if grep -q '"status": "running"' "$tmpdir/locked.json"; then
        ok "management action CGI reports an already-running action"
    else
        fail "management action CGI did not report an already-running action"
    fi

    : > "$tmpdir/not-a-lock-dir"
    REQUEST_METHOD=POST \
        PATH=/usr/bin:/bin \
        QUERY_STRING=action=capture \
        REDSTONE_WEB_ACTION_DIR="$tmpdir/lock-failed-actions" \
        REDSTONE_WEB_ACTION_LOCK="$tmpdir/not-a-lock-dir" \
        REDSTONE_CAPTURE_CMD="sh $fake_capture" \
        sh "$TOPDIR/config/rootfs/overlay/www/cgi-bin/redstone-action" > "$tmpdir/lock-failed.json"
    if grep -q '"status": "failed"' "$tmpdir/lock-failed.json" && \
        grep -q '"message": "cannot create action lock"' "$tmpdir/lock-failed.json"; then
        ok "management action CGI reports lock creation failures explicitly"
    else
        fail "management action CGI masks lock creation failures as running"
    fi

    rm -rf "$tmpdir"
}

if command -v mktemp >/dev/null 2>&1; then
    check_mgmt_status_portmap_formats
    check_mgmt_status_evidence_index
    check_mgmt_evidence_index
    check_mgmt_artifact_provider
    check_mgmt_status_missing_validation_log
    check_web_action_cgi
    check_unusable_explicit_dir \
        "bench runner" \
        REDSTONE_BENCH_DIR \
        "config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run" \
        "failed to create explicit REDSTONE_BENCH_DIR" \
        --capture-only
    check_unusable_explicit_dir \
        "capture tool" \
        REDSTONE_CAPTURE_DIR \
        "config/rootfs/overlay/usr/sbin/redstone-stage1-capture" \
        "cannot create REDSTONE_CAPTURE_DIR"
    check_unusable_explicit_dir \
        "validator" \
        REDSTONE_VALIDATE_DIR \
        "config/rootfs/overlay/usr/sbin/redstone-stage1-validate" \
        "cannot create REDSTONE_VALIDATE_DIR"
else
    warn "mktemp unavailable; skipped explicit evidence directory regression checks"
fi
check_grep 'REQUIRE_OPENBCM_INIT_PROBE' "scripts/check-redstone-image.sh" \
    "image checker can enforce OpenBCM init probe packaging"

portmaps=$(grep -Ec '^portmap_[0-9]+=' "$TOPDIR/config/bcm/redstone-stage1.bcm" || true)
if [ "$portmaps" -eq 52 ]; then
    ok "Redstone port map has 52 front-panel entries"
else
    fail "Redstone port map has $portmaps entries, expected 52"
fi

check_grep '^generated_config_portmap_count=61$' \
    "config/bcm/redstone-original-active-sdk.manifest" \
    "original-active SDK manifest records the 61-entry active split port map"
check_grep '^generated_config_split_10g_portmap_count=12$' \
    "config/bcm/redstone-original-active-sdk.manifest" \
    "original-active SDK manifest records twelve 10G split port maps"
check_grep '^generated_has_unsplit_fxe52=true$' \
    "config/bcm/redstone-original-active-sdk.manifest" \
    "original-active SDK manifest records fxe52 as unsplit 40G"
check_grep '^generated_has_l2xmsg_chunks=true$' \
    "config/bcm/redstone-original-active-sdk.manifest" \
    "original-active SDK manifest includes original SDK global tuning"
if [ -d "$TOPDIR/../../startup_redstone_t/ZEBOS/bcm" ]; then
    if sh "$TOPDIR/scripts/generate-redstone-original-active-sdk-reference.sh" check >/dev/null; then
        ok "original-active SDK reference manifest regenerates from extracted source"
    else
        fail "original-active SDK reference manifest does not regenerate from extracted source"
    fi
else
    ok "original-active SDK source tree is absent; manifest structural checks retained"
fi

if command -v sh >/dev/null 2>&1; then
    for script in \
        scripts/board-env.sh \
        scripts/build-rootfs.sh \
        scripts/build-kernel.sh \
        scripts/build-installer.sh \
        scripts/build-modules.sh \
        scripts/build-all.sh \
        scripts/build-redstone-b2-tftp-fit.sh \
        scripts/check-redstone-image.sh \
        scripts/package-redstone-hardware-handoff.sh \
        scripts/package-redstone-web-hotfix.sh \
        scripts/package-redstone-usb-stage1.sh \
        scripts/verify-redstone-usb-stage1-image.sh \
        scripts/verify-redstone-hardware-handoff.sh \
        scripts/prepare-redstone-bench-note.sh \
        scripts/analyze-redstone-stage1-evidence.sh \
        scripts/analyze-redstone-handoff-capture.sh \
        scripts/analyze-redstone-platform-inventory.sh \
        scripts/analyze-redstone-openbcm-bde-smoke.sh \
        scripts/prepare-openbcm.sh \
        scripts/build-openbcm-bde.sh \
        scripts/redstone-openbcm-bde-smoke.sh \
        scripts/check-openbcm-userland-init.sh \
        scripts/build-openbcm-init-probe.sh \
        scripts/install-openbcm-init-probe.sh \
        scripts/generate-redstone-original-active-sdk-reference.sh \
        config/rootfs/post-build.sh \
        config/rootfs/overlay/etc/init.d/S20edgenos \
        config/rootfs/overlay/etc/init.d/S38devpts \
        config/rootfs/overlay/etc/init.d/S41redstone-mgmt-web \
        config/rootfs/overlay/usr/sbin/redstone-stage1-capture \
        config/rootfs/overlay/usr/sbin/redstone-stage1-validate \
        config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run \
        config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact \
        config/rootfs/overlay/usr/sbin/redstone-mgmt-evidence \
        config/rootfs/overlay/usr/sbin/redstone-mgmt-status \
        config/rootfs/overlay/usr/sbin/redstone-mgmt-web \
        config/rootfs/overlay/www/cgi-bin/redstone-artifact \
        config/rootfs/overlay/www/cgi-bin/redstone-evidence \
        config/rootfs/overlay/www/cgi-bin/redstone-status \
        config/rootfs/overlay/www/cgi-bin/redstone-action \
        config/rootfs/overlay/usr/sbin/switchd-init
    do
        if sh -n "$TOPDIR/$script"; then
            ok "shell syntax: $script"
        else
            fail "shell syntax failed: $script"
        fi
    done
fi

if command -v dtc >/dev/null 2>&1; then
    tmp_dtb=$(mktemp)
    if dtc -I dts -O dtb -o "$tmp_dtb" "$TOPDIR/$EDGENOS_DTS_SOURCE"; then
        ok "DTS compiles with dtc: $EDGENOS_DTS_SOURCE"
    else
        fail "DTS compile failed: $EDGENOS_DTS_SOURCE"
    fi
    rm -f "$tmp_dtb"
else
    warn "dtc unavailable; skipped DTS compile check"
fi

if command -v git >/dev/null 2>&1; then
    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/check-redstone-stage1.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "check-redstone-stage1.sh is tracked executable"
    else
        fail "check-redstone-stage1.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/build-modules.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "build-modules.sh is tracked executable"
    else
        fail "build-modules.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/build-redstone-b2-tftp-fit.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "build-redstone-b2-tftp-fit.sh is tracked executable"
    else
        fail "build-redstone-b2-tftp-fit.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/check-redstone-image.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "check-redstone-image.sh is tracked executable"
    else
        fail "check-redstone-image.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/package-redstone-hardware-handoff.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "package-redstone-hardware-handoff.sh is tracked executable"
    else
        fail "package-redstone-hardware-handoff.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/package-redstone-web-hotfix.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "package-redstone-web-hotfix.sh is tracked executable"
    else
        fail "package-redstone-web-hotfix.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/package-redstone-usb-stage1.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "package-redstone-usb-stage1.sh is tracked executable"
    else
        fail "package-redstone-usb-stage1.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/verify-redstone-usb-stage1-image.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "verify-redstone-usb-stage1-image.sh is tracked executable"
    else
        fail "verify-redstone-usb-stage1-image.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/verify-redstone-hardware-handoff.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "verify-redstone-hardware-handoff.sh is tracked executable"
    else
        fail "verify-redstone-hardware-handoff.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/prepare-redstone-bench-note.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "prepare-redstone-bench-note.sh is tracked executable"
    else
        fail "prepare-redstone-bench-note.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/analyze-redstone-stage1-evidence.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "analyze-redstone-stage1-evidence.sh is tracked executable"
    else
        fail "analyze-redstone-stage1-evidence.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/analyze-redstone-handoff-capture.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "analyze-redstone-handoff-capture.sh is tracked executable"
    else
        fail "analyze-redstone-handoff-capture.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/analyze-redstone-platform-inventory.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "analyze-redstone-platform-inventory.sh is tracked executable"
    else
        fail "analyze-redstone-platform-inventory.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/analyze-redstone-openbcm-bde-smoke.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "analyze-redstone-openbcm-bde-smoke.sh is tracked executable"
    else
        fail "analyze-redstone-openbcm-bde-smoke.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/prepare-openbcm.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "prepare-openbcm.sh is tracked executable"
    else
        fail "prepare-openbcm.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/build-openbcm-bde.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "build-openbcm-bde.sh is tracked executable"
    else
        fail "build-openbcm-bde.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/redstone-openbcm-bde-smoke.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-openbcm-bde-smoke.sh is tracked executable"
    else
        fail "redstone-openbcm-bde-smoke.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/check-openbcm-userland-init.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "check-openbcm-userland-init.sh is tracked executable"
    else
        fail "check-openbcm-userland-init.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/build-openbcm-init-probe.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "build-openbcm-init-probe.sh is tracked executable"
    else
        fail "build-openbcm-init-probe.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/install-openbcm-init-probe.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "install-openbcm-init-probe.sh is tracked executable"
    else
        fail "install-openbcm-init-probe.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        scripts/generate-redstone-original-active-sdk-reference.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "generate-redstone-original-active-sdk-reference.sh is tracked executable"
    else
        fail "generate-redstone-original-active-sdk-reference.sh git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/usr/sbin/redstone-stage1-capture |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-stage1-capture is tracked executable"
    else
        fail "redstone-stage1-capture git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/usr/sbin/redstone-stage1-validate |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-stage1-validate is tracked executable"
    else
        fail "redstone-stage1-validate git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/usr/sbin/redstone-stage1-bench-run |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-stage1-bench-run is tracked executable"
    else
        fail "redstone-stage1-bench-run git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/usr/sbin/redstone-mgmt-artifact |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-mgmt-artifact is tracked executable"
    else
        fail "redstone-mgmt-artifact git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/usr/sbin/redstone-mgmt-evidence |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-mgmt-evidence is tracked executable"
    else
        fail "redstone-mgmt-evidence git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/usr/sbin/redstone-mgmt-status |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-mgmt-status is tracked executable"
    else
        fail "redstone-mgmt-status git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/usr/sbin/redstone-mgmt-web |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-mgmt-web is tracked executable"
    else
        fail "redstone-mgmt-web git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/etc/init.d/S41redstone-mgmt-web |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "S41redstone-mgmt-web is tracked executable"
    else
        fail "S41redstone-mgmt-web git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/www/cgi-bin/redstone-artifact |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-artifact CGI is tracked executable"
    else
        fail "redstone-artifact CGI git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/www/cgi-bin/redstone-evidence |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-evidence CGI is tracked executable"
    else
        fail "redstone-evidence CGI git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/www/cgi-bin/redstone-status |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-status CGI is tracked executable"
    else
        fail "redstone-status CGI git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/www/cgi-bin/redstone-action |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "redstone-action CGI is tracked executable"
    else
        fail "redstone-action CGI git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/etc/init.d/S20edgenos |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "S20edgenos is tracked executable"
    else
        fail "S20edgenos git mode is ${mode:-missing}, expected 100755"
    fi

    mode=$(git -C "$TOPDIR" ls-files --stage -- \
        config/rootfs/overlay/etc/init.d/S38devpts |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "S38devpts is tracked executable"
    else
        fail "S38devpts git mode is ${mode:-missing}, expected 100755"
    fi
else
    warn "git unavailable; skipped executable-mode check"
fi

printf '\n'
if [ "$FAILURES" -ne 0 ]; then
    printf 'Redstone stage-1 preflight failed: %s failure(s), %s warning(s)\n' \
        "$FAILURES" "$WARNINGS" >&2
    exit 1
fi

printf 'Redstone stage-1 preflight passed: %s warning(s)\n' "$WARNINGS"
