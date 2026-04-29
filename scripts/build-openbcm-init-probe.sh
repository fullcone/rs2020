#!/bin/sh
set -eu

TOPDIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

OPENBCM_INIT_SRC=${OPENBCM_INIT_SRC:-"$TOPDIR/asic/openbcm-init/redstone-openbcm-init-probe.c"}
OPENBCM_INIT_OUT=${OPENBCM_INIT_OUT:-"$TOPDIR/output/openbcm-init"}
OPENBCM_INIT_BIN=${OPENBCM_INIT_BIN:-"$OPENBCM_INIT_OUT/redstone-openbcm-init-probe"}
OPENBCM_INIT_MANIFEST=${OPENBCM_INIT_MANIFEST:-"$OPENBCM_INIT_OUT/redstone-openbcm-init-probe.manifest"}
OPENBCM_INIT_DEFAULT_DEMO=${OPENBCM_INIT_DEFAULT_DEMO:-"/usr/sbin/demo_opennsa_init"}
OPENBCM_INIT_DEFAULT_CONFIG=${OPENBCM_INIT_DEFAULT_CONFIG:-"/etc/switchd/redstone-stage1.bcm"}
CROSS_COMPILE=${CROSS_COMPILE:-powerpc-linux-gnu-}
CC=${CC:-"${CROSS_COMPILE}gcc"}
CFLAGS=${CFLAGS:-"-std=c99 -Wall -Wextra -Werror -O2"}

ok() {
    printf 'OK: %s\n' "$*"
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    return 1
}

die() {
    fail "$*"
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

print_env() {
    cat <<EOF
OPENBCM_INIT_SRC=$OPENBCM_INIT_SRC
OPENBCM_INIT_OUT=$OPENBCM_INIT_OUT
OPENBCM_INIT_BIN=$OPENBCM_INIT_BIN
OPENBCM_INIT_MANIFEST=$OPENBCM_INIT_MANIFEST
OPENBCM_INIT_DEFAULT_DEMO=$OPENBCM_INIT_DEFAULT_DEMO
OPENBCM_INIT_DEFAULT_CONFIG=$OPENBCM_INIT_DEFAULT_CONFIG
CROSS_COMPILE=$CROSS_COMPILE
CC=$CC
CFLAGS=$CFLAGS
EOF
}

check_inputs() {
    [ -f "$OPENBCM_INIT_SRC" ] || die "missing init probe source: $OPENBCM_INIT_SRC"
    [ -f "$TOPDIR/config/bcm/redstone-stage1.bcm" ] ||
        die "missing Redstone BCM config: $TOPDIR/config/bcm/redstone-stage1.bcm"
    [ -f "$TOPDIR/scripts/check-openbcm-userland-init.sh" ] || die "missing userland source preflight"
    [ -f "$TOPDIR/scripts/analyze-redstone-openbcm-bde-smoke.sh" ] || die "missing BDE smoke evidence analyzer"

    grep -Fq '14e4:b846' "$OPENBCM_INIT_SRC" ||
        die "init probe must gate exact BCM56846 PCI ID 14e4:b846"
    grep -Fq -- '--i-accept-hardware-reset-risk' "$OPENBCM_INIT_SRC" ||
        die "init probe must require explicit hardware reset risk acknowledgement"
    grep -Fq 'BCM_CONFIG_FILE' "$OPENBCM_INIT_SRC" ||
        die "init probe must set BCM_CONFIG_FILE before OpenBCM demo init execution"

    need_cmd "$CC"
    ok "init probe source/build preflight passed"
}

build_probe() {
    check_inputs
    mkdir -p "$OPENBCM_INIT_OUT"
    "$CC" $CFLAGS -DDEFAULT_DEMO_INIT="\"$OPENBCM_INIT_DEFAULT_DEMO\"" \
        -DDEFAULT_BCM_CONFIG="\"$OPENBCM_INIT_DEFAULT_CONFIG\"" \
        -o "$OPENBCM_INIT_BIN" "$OPENBCM_INIT_SRC"
    chmod 0755 "$OPENBCM_INIT_BIN"
    ok "built $OPENBCM_INIT_BIN"
}

write_manifest() {
    mkdir -p "$OPENBCM_INIT_OUT"
    {
        printf 'openbcm_init_probe_bundle=1\n'
        printf 'sdk_baseline=openbcm-6.5.27\n'
        printf 'source=%s\n' "$OPENBCM_INIT_SRC"
        printf 'binary=%s\n' "$OPENBCM_INIT_BIN"
        printf 'demo_default=%s\n' "$OPENBCM_INIT_DEFAULT_DEMO"
        printf 'config_default=%s\n' "$OPENBCM_INIT_DEFAULT_CONFIG"
        printf 'hardware_gate=requires BDE device nodes, exact BCM56846 PCI ID 14e4:b846, readable BCM config, and explicit reset-risk flag for exec\n'
        printf 'dry_run_command=./redstone-openbcm-init-probe --dry-run\n'
        printf 'exec_command=./redstone-openbcm-init-probe --exec --i-accept-hardware-reset-risk\n'
        if command -v sha256sum >/dev/null 2>&1 && [ -f "$OPENBCM_INIT_BIN" ]; then
            printf 'binary_sha256='
            sha256sum "$OPENBCM_INIT_BIN" | awk '{print $1}'
        fi
    } >"$OPENBCM_INIT_MANIFEST"
    ok "wrote $OPENBCM_INIT_MANIFEST"
}

bundle_probe() {
    build_probe
    write_manifest
    ok "bundle is ready under $OPENBCM_INIT_OUT"
}

clean_probe() {
    rm -rf "$OPENBCM_INIT_OUT"
    ok "removed $OPENBCM_INIT_OUT"
}

usage() {
    cat <<EOF
Usage: $0 <command>

Commands:
  check      Validate init probe source and build prerequisites
  build      Cross-build the Redstone OpenBCM init probe gate
  bundle     Build and write a small deployment manifest
  print-env  Print resolved build environment
  clean      Remove generated init probe output
EOF
}

cmd=${1:-help}
case "$cmd" in
    check)
        check_inputs
        ;;
    build)
        build_probe
        ;;
    bundle)
        bundle_probe
        ;;
    print-env)
        print_env
        ;;
    clean)
        clean_probe
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
