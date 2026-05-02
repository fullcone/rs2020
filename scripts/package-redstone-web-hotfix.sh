#!/bin/sh
# Build the Redstone live-system web/SSH hotfix tarball.
#
# This is for lab systems already booted from an older stage-1 image. It does
# not replace the system BusyBox. Instead it installs a fallback BusyBox under
# /usr/sbin and invokes its httpd applet through an applet-named symlink.

set -eu

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_TAR=${REDSTONE_WEB_HOTFIX_TAR:-"$TOPDIR/output/images/redstone-web-ssh-hotfix.tar"}
OUT_TARGZ=${REDSTONE_WEB_HOTFIX_TARGZ:-"$OUT_TAR.gz"}
WORKDIR=${REDSTONE_WEB_HOTFIX_WORKDIR:-"$TOPDIR/output/redstone-web-ssh-hotfix-root"}
STAGING=${REDSTONE_WEB_HOTFIX_STAGING:-"$TOPDIR/output/rootfs/staging"}

usage() {
    cat >&2 <<EOF
Usage: $0 [package|print-env]

Environment:
  REDSTONE_WEB_HOTFIX_TAR      output tar path, default output/images/redstone-web-ssh-hotfix.tar
  REDSTONE_WEB_HOTFIX_TARGZ    output gzip path, default tar path plus .gz
  REDSTONE_WEB_HOTFIX_WORKDIR  temporary root, default output/redstone-web-ssh-hotfix-root
  REDSTONE_WEB_HOTFIX_STAGING  assembled rootfs staging, default output/rootfs/staging
EOF
    exit 1
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_file() {
    [ -f "$1" ] || fail "missing required file: $1"
}

require_dir() {
    [ -d "$1" ] || fail "missing required directory: $1"
}

copy_file() {
    src=$1
    dst=$2
    require_file "$src"
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1"
    else
        fail "missing checksum tool: sha256sum or shasum"
    fi
}

canonical_path() {
    if command -v realpath >/dev/null 2>&1 && realpath -m "$1" >/dev/null 2>&1; then
        realpath -m "$1"
    else
        fail "missing realpath -m support for path safety checks"
    fi
}

print_env() {
    cat <<EOF
topdir=$TOPDIR
staging=$STAGING
workdir=$WORKDIR
tar=$OUT_TAR
targz=$OUT_TARGZ
EOF
}

copy_rootfs_file() {
    rel=$1
    if [ -f "$TOPDIR/config/rootfs/overlay/$rel" ]; then
        copy_file "$TOPDIR/config/rootfs/overlay/$rel" "$WORKDIR/$rel"
    elif [ -f "$STAGING/$rel" ]; then
        copy_file "$STAGING/$rel" "$WORKDIR/$rel"
    else
        fail "missing required file: $STAGING/$rel"
    fi
}

copy_rootfs_tree() {
    rel=$1
    mkdir -p "$(dirname "$WORKDIR/$rel")"
    if [ -d "$TOPDIR/config/rootfs/overlay/$rel" ]; then
        cp -a "$TOPDIR/config/rootfs/overlay/$rel" "$(dirname "$WORKDIR/$rel")/"
    elif [ -d "$STAGING/$rel" ]; then
        cp -a "$STAGING/$rel" "$(dirname "$WORKDIR/$rel")/"
    else
        fail "missing required directory: $STAGING/$rel"
    fi
}

package() {
    top_real=$(canonical_path "$TOPDIR")
    output_real="$top_real/output"
    image_real="$output_real/images"
    out_tar_real=$(canonical_path "$OUT_TAR")
    out_targz_real=$(canonical_path "$OUT_TARGZ")
    workdir_real=$(canonical_path "$WORKDIR")

    case "$out_tar_real" in
        "$image_real"/*) ;;
        *) fail "refusing hotfix tar outside output/images: $OUT_TAR" ;;
    esac
    case "$out_targz_real" in
        "$image_real"/*) ;;
        *) fail "refusing hotfix gzip outside output/images: $OUT_TARGZ" ;;
    esac
    case "$workdir_real" in
        "$output_real"/*) ;;
        *) fail "refusing hotfix workdir outside output/: $WORKDIR" ;;
    esac

    OUT_TAR=$out_tar_real
    OUT_TARGZ=$out_targz_real
    WORKDIR=$workdir_real

    require_dir "$STAGING"
    require_file "$STAGING/bin/busybox"
    require_file "$TOPDIR/config/rootfs/overlay/usr/sbin/redstone-mgmt-web"
    require_file "$TOPDIR/scripts/redstone-openbcm-bde-smoke.sh"
    require_file "$TOPDIR/config/bcm/redstone-stage1.bcm"
    require_file "$TOPDIR/config/bcm/redstone-original-active-sdk.manifest"

    rm -rf "$WORKDIR"
    mkdir -p "$WORKDIR"

    for rel in \
        etc/init.d/S38devpts \
        etc/init.d/S41redstone-mgmt-web \
        usr/sbin/redstone-stage1-capture \
        usr/sbin/redstone-stage1-validate \
        usr/sbin/redstone-stage1-bench-run \
        usr/sbin/redstone-mgmt-artifact \
        usr/sbin/redstone-mgmt-evidence \
        usr/sbin/redstone-mgmt-status \
        usr/sbin/redstone-mgmt-web \
        www/cgi-bin/redstone-artifact \
        www/cgi-bin/redstone-evidence \
        www/cgi-bin/redstone-status \
        www/cgi-bin/redstone-action
    do
        copy_rootfs_file "$rel"
        chmod 755 "$WORKDIR/$rel"
    done

    copy_file "$TOPDIR/scripts/redstone-openbcm-bde-smoke.sh" \
        "$WORKDIR/usr/sbin/redstone-openbcm-bde-smoke.sh"
    chmod 755 "$WORKDIR/usr/sbin/redstone-openbcm-bde-smoke.sh"

    if [ -f "$TOPDIR/output/openbcm-init/redstone-openbcm-init-probe" ]; then
        copy_file "$TOPDIR/output/openbcm-init/redstone-openbcm-init-probe" \
            "$WORKDIR/usr/sbin/redstone-openbcm-init-probe"
        chmod 755 "$WORKDIR/usr/sbin/redstone-openbcm-init-probe"
    elif [ -f "$STAGING/usr/sbin/redstone-openbcm-init-probe" ]; then
        copy_file "$STAGING/usr/sbin/redstone-openbcm-init-probe" \
            "$WORKDIR/usr/sbin/redstone-openbcm-init-probe"
        chmod 755 "$WORKDIR/usr/sbin/redstone-openbcm-init-probe"
    fi

    if [ -f "$TOPDIR/output/openbcm-init/redstone-openbcm-init-probe.manifest" ]; then
        copy_file "$TOPDIR/output/openbcm-init/redstone-openbcm-init-probe.manifest" \
            "$WORKDIR/usr/share/edgenos/openbcm/redstone-openbcm-init-probe.manifest"
    elif [ -f "$STAGING/usr/share/edgenos/openbcm/redstone-openbcm-init-probe.manifest" ]; then
        copy_file "$STAGING/usr/share/edgenos/openbcm/redstone-openbcm-init-probe.manifest" \
            "$WORKDIR/usr/share/edgenos/openbcm/redstone-openbcm-init-probe.manifest"
    fi

    if [ -f "$STAGING/etc/edgenos/board" ]; then
        copy_rootfs_file etc/edgenos/board
    fi

    copy_rootfs_tree www/redstone

    mkdir -p "$WORKDIR/etc/switchd"
    cp -p "$TOPDIR/config/bcm/"* "$WORKDIR/etc/switchd/"

    mkdir -p "$WORKDIR/usr/sbin/redstone-httpd"
    cp -p "$STAGING/bin/busybox" "$WORKDIR/usr/sbin/redstone-busybox"
    chmod 755 "$WORKDIR/usr/sbin/redstone-busybox"
    ln -s ../redstone-busybox "$WORKDIR/usr/sbin/redstone-httpd/httpd"

    mkdir -p "$(dirname "$OUT_TAR")"
    rm -f "$OUT_TAR" "$OUT_TARGZ"
    (
        cd "$WORKDIR"
        tar --numeric-owner --owner=0 --group=0 -cf "$OUT_TAR" etc usr www
    )
    gzip -n -c "$OUT_TAR" > "$OUT_TARGZ"

    sha256_file "$OUT_TAR"
    sha256_file "$OUT_TARGZ"
}

case "${1:-package}" in
    package) package ;;
    print-env) print_env ;;
    *) usage ;;
esac
