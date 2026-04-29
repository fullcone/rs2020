#!/bin/sh
# Install the optional Redstone OpenBCM init probe into a rootfs tree.

set -eu

usage() {
    echo "Usage: $0 <target-rootfs-dir>" >&2
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

log() {
    echo "openbcm init probe: $*"
}

[ "$#" -eq 1 ] || {
    usage
    exit 2
}

TARGET_DIR="$1"
[ -d "$TARGET_DIR" ] || die "target rootfs directory does not exist: $TARGET_DIR"

TOPDIR=${TOPDIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
EDGENOS_BOARD=${EDGENOS_BOARD:-as5610-52x}
if [ -f "$TOPDIR/scripts/board-env.sh" ]; then
    # shellcheck disable=SC1091
    . "$TOPDIR/scripts/board-env.sh"
fi

REQUIRE_OPENBCM_INIT_PROBE=${REQUIRE_OPENBCM_INIT_PROBE:-0}
case "$REQUIRE_OPENBCM_INIT_PROBE" in
    1|yes|true|TRUE|on|ON)
        REQUIRE_OPENBCM_INIT_PROBE=1
        ;;
    0|no|false|FALSE|off|OFF|"")
        REQUIRE_OPENBCM_INIT_PROBE=0
        ;;
    *)
        die "invalid REQUIRE_OPENBCM_INIT_PROBE=$REQUIRE_OPENBCM_INIT_PROBE"
        ;;
esac

if [ "$EDGENOS_BOARD" != "redstone" ]; then
    log "skipped for board $EDGENOS_BOARD"
    exit 0
fi

OPENBCM_INIT_BIN=${OPENBCM_INIT_BIN:-"$TOPDIR/output/openbcm-init/redstone-openbcm-init-probe"}
OPENBCM_INIT_MANIFEST=${OPENBCM_INIT_MANIFEST:-"$TOPDIR/output/openbcm-init/redstone-openbcm-init-probe.manifest"}

if [ ! -f "$OPENBCM_INIT_BIN" ]; then
    if [ "$REQUIRE_OPENBCM_INIT_PROBE" = "1" ]; then
        die "required probe binary is missing: $OPENBCM_INIT_BIN"
    fi
    log "binary not present; skipped ($OPENBCM_INIT_BIN)"
    exit 0
fi

install -D -m 0755 "$OPENBCM_INIT_BIN" \
    "$TARGET_DIR/usr/sbin/redstone-openbcm-init-probe"
log "installed /usr/sbin/redstone-openbcm-init-probe"

if [ -f "$OPENBCM_INIT_MANIFEST" ]; then
    install -D -m 0644 "$OPENBCM_INIT_MANIFEST" \
        "$TARGET_DIR/usr/share/edgenos/openbcm/redstone-openbcm-init-probe.manifest"
    log "installed /usr/share/edgenos/openbcm/redstone-openbcm-init-probe.manifest"
elif [ "$REQUIRE_OPENBCM_INIT_PROBE" = "1" ]; then
    die "required probe manifest is missing: $OPENBCM_INIT_MANIFEST"
else
    log "manifest not present; binary installed without manifest"
fi
