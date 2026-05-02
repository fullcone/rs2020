#!/bin/sh
# Install the Redstone OpenBCM BDE smoke helper into a rootfs tree.

set -eu

usage() {
    echo "Usage: $0 <target-rootfs-dir>" >&2
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

log() {
    echo "openbcm bde smoke: $*"
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

if [ "$EDGENOS_BOARD" != "redstone" ]; then
    log "skipped for board $EDGENOS_BOARD"
    exit 0
fi

OPENBCM_BDE_SMOKE_SRC=${OPENBCM_BDE_SMOKE_SRC:-"$TOPDIR/scripts/redstone-openbcm-bde-smoke.sh"}
[ -f "$OPENBCM_BDE_SMOKE_SRC" ] || die "smoke helper missing: $OPENBCM_BDE_SMOKE_SRC"

install -D -m 0755 "$OPENBCM_BDE_SMOKE_SRC" \
    "$TARGET_DIR/usr/sbin/redstone-openbcm-bde-smoke.sh"
log "installed /usr/sbin/redstone-openbcm-bde-smoke.sh"
