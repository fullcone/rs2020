#!/bin/sh
# Fetch and sanity-check the OpenBCM source baseline used for Redstone SDK proof.

set -eu

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"

OPENBCM_REPO_URL="${OPENBCM_REPO_URL:-https://github.com/Broadcom-Network-Switching-Software/OpenBCM.git}"
OPENBCM_REF="${OPENBCM_REF:-6d2330ce1b4fc49d681cffcf09af408661be4c62}"
OPENBCM_VERSION="${OPENBCM_VERSION:-6.5.27}"
OPENBCM_WORKDIR="${OPENBCM_WORKDIR:-$TOPDIR/build/openbcm}"
OPENBCM_TREE="${OPENBCM_TREE:-$OPENBCM_WORKDIR/OpenBCM}"
OPENBCM_SDK_BASENAME="sdk-$OPENBCM_VERSION"
OPENBCM_SDK="${OPENBCM_SDK:-$OPENBCM_TREE/$OPENBCM_SDK_BASENAME}"

FAILURES=0

usage() {
    cat <<EOF
Usage: $0 <command>

Commands:
  fetch      Clone or update the pinned OpenBCM source seed
  check      Check that the source seed has Redstone-relevant SDK evidence
  print-env  Print the resolved OpenBCM source paths and pin
  clean      Remove the generated OpenBCM source seed

Environment overrides:
  OPENBCM_REPO_URL=$OPENBCM_REPO_URL
  OPENBCM_REF=$OPENBCM_REF
  OPENBCM_VERSION=$OPENBCM_VERSION
  OPENBCM_WORKDIR=$OPENBCM_WORKDIR
EOF
}

ok() {
    printf 'ok: %s\n' "$*"
}

fail() {
    FAILURES=$((FAILURES + 1))
    printf 'fail: %s\n' "$*" >&2
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

shell_quote() {
    printf "'"
    printf "%s" "$1" | sed "s/'/'\\\\''/g"
    printf "'"
}

print_var() {
    name=$1
    eval "value=\${$name}"
    printf '%s=' "$name"
    shell_quote "$value"
    printf '\n'
}

fetch_openbcm() {
    need_cmd git

    mkdir -p "$OPENBCM_WORKDIR"

    if [ ! -d "$OPENBCM_TREE/.git" ]; then
        git clone --filter=blob:none --sparse "$OPENBCM_REPO_URL" "$OPENBCM_TREE"
    else
        git -C "$OPENBCM_TREE" remote set-url origin "$OPENBCM_REPO_URL"
    fi

    git -C "$OPENBCM_TREE" sparse-checkout set "$OPENBCM_SDK_BASENAME"
    if ! git -C "$OPENBCM_TREE" fetch --depth 1 origin "$OPENBCM_REF"; then
        git -C "$OPENBCM_TREE" fetch origin "$OPENBCM_REF"
    fi
    git -C "$OPENBCM_TREE" checkout --detach FETCH_HEAD

    ok "OpenBCM source seed ready at $OPENBCM_SDK"
    ok "OpenBCM ref: $(git -C "$OPENBCM_TREE" rev-parse HEAD)"
}

check_rel_file() {
    desc=$1
    rel=$2

    if [ -f "$OPENBCM_SDK/$rel" ]; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

check_rel_dir() {
    desc=$1
    rel=$2

    if [ -d "$OPENBCM_SDK/$rel" ]; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

check_rel_text() {
    desc=$1
    rel=$2
    pattern=$3

    if [ ! -f "$OPENBCM_SDK/$rel" ]; then
        fail "$desc"
        return
    fi

    if LC_ALL=C grep -Eq "$pattern" "$OPENBCM_SDK/$rel"; then
        ok "$desc"
    else
        fail "$desc"
    fi
}

check_openbcm() {
    if [ ! -d "$OPENBCM_SDK" ]; then
        fail "OpenBCM SDK directory exists: $OPENBCM_SDK"
    else
        ok "OpenBCM SDK directory exists: $OPENBCM_SDK"
    fi

    if [ -d "$OPENBCM_SDK" ]; then
        check_rel_text "BCM56846 device evidence exists" \
            "include/soc/devids.h" 'BCM56846|0x[bB]846'
        check_rel_file "Trident source exists" "src/soc/esw/trident.c"
        check_rel_dir "Linux BDE source directory exists" "systems/bde/linux"
        check_rel_file "Linux kernel BDE source exists" \
            "systems/bde/linux/kernel/linux-kernel-bde.c"
        check_rel_file "Linux user BDE source exists" \
            "systems/bde/linux/user/kernel/linux-user-bde.c"
        check_rel_text "L3 route API evidence exists" \
            "include/bcm/l3.h" 'bcm_l3_route_add'
        check_rel_text "Field Processor API evidence exists" \
            "include/bcm/field.h" 'bcm_field_entry_create'
    fi

    if [ "$FAILURES" -ne 0 ]; then
        printf 'OpenBCM source seed check failed: %s failure(s)\n' "$FAILURES" >&2
        exit 1
    fi

    printf 'OpenBCM source seed check passed\n'
}

print_env() {
    print_var OPENBCM_REPO_URL
    print_var OPENBCM_REF
    print_var OPENBCM_VERSION
    print_var OPENBCM_WORKDIR
    print_var OPENBCM_TREE
    print_var OPENBCM_SDK
}

case "${1:-check}" in
    fetch)
        fetch_openbcm
        ;;
    check)
        check_openbcm
        ;;
    print-env)
        print_env
        ;;
    clean)
        rm -rf "$OPENBCM_WORKDIR"
        ok "removed $OPENBCM_WORKDIR"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
