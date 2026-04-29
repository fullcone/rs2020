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

    if grep -Eq "$pattern" "$TOPDIR/$rel"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

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
check_file "config/rootfs/overlay/usr/sbin/redstone-stage1-capture"
check_file "config/rootfs/overlay/usr/sbin/redstone-stage1-validate"
check_file "config/rootfs/overlay/usr/sbin/switchd-init"
check_file "config/rootfs/overlay/etc/init.d/S20edgenos"
check_file "config/rootfs/overlay/etc/systemd/system/switchd.service"
check_file "scripts/build-rootfs.sh"
check_file "scripts/build-kernel.sh"
check_file "scripts/build-installer.sh"
check_file "scripts/build-modules.sh"
check_file "scripts/build-all.sh"
check_file "scripts/check-redstone-image.sh"
check_file "scripts/analyze-redstone-stage1-evidence.sh"
check_file "scripts/prepare-openbcm.sh"
check_file "scripts/build-openbcm-bde.sh"

check_grep 'redstone-stage1\.bcm' "config/rootfs/overlay/usr/sbin/switchd-init" \
    "switchd-init references Redstone stage-1 config"
check_grep 'BR2_TOOLCHAIN_BUILDROOT_UCLIBC=y' "config/rootfs/buildroot_defconfig" \
    "rootfs defconfig selects uClibc for PowerPC SPE"
check_grep 'BR2_INIT_BUSYBOX=y' "config/rootfs/buildroot_defconfig" \
    "rootfs defconfig selects BusyBox init"
check_grep 'switchd-init start' "config/rootfs/overlay/etc/init.d/S20edgenos" \
    "BusyBox init starts switchd through switchd-init"
check_grep 'start-foreground' "config/rootfs/overlay/etc/systemd/system/switchd.service" \
    "switchd service uses switchd-init foreground path"
check_grep 'config/rootfs/overlay' "scripts/build-rootfs.sh" \
    "build-rootfs applies the rootfs overlay"
check_grep 'config/rootfs/overlay' "scripts/build-all.sh" \
    "build-all applies the rootfs overlay"
check_grep 'bundle' "scripts/build-openbcm-bde.sh" \
    "OpenBCM BDE helper can bundle hardware-load artifacts"

portmaps=$(grep -Ec '^portmap_[0-9]+=' "$TOPDIR/config/bcm/redstone-stage1.bcm" || true)
if [ "$portmaps" -eq 52 ]; then
    ok "Redstone port map has 52 front-panel entries"
else
    fail "Redstone port map has $portmaps entries, expected 52"
fi

if command -v sh >/dev/null 2>&1; then
    for script in \
        scripts/board-env.sh \
        scripts/build-rootfs.sh \
        scripts/build-kernel.sh \
        scripts/build-installer.sh \
        scripts/build-modules.sh \
        scripts/build-all.sh \
        scripts/check-redstone-image.sh \
        scripts/analyze-redstone-stage1-evidence.sh \
        scripts/prepare-openbcm.sh \
        scripts/build-openbcm-bde.sh \
        config/rootfs/post-build.sh \
        config/rootfs/overlay/etc/init.d/S20edgenos \
        config/rootfs/overlay/usr/sbin/redstone-stage1-capture \
        config/rootfs/overlay/usr/sbin/redstone-stage1-validate \
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
        scripts/check-redstone-image.sh |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "check-redstone-image.sh is tracked executable"
    else
        fail "check-redstone-image.sh git mode is ${mode:-missing}, expected 100755"
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
        config/rootfs/overlay/etc/init.d/S20edgenos |
        awk '{print $1; exit}')
    if [ "$mode" = "100755" ]; then
        ok "S20edgenos is tracked executable"
    else
        fail "S20edgenos git mode is ${mode:-missing}, expected 100755"
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
