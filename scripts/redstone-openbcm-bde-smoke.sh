#!/bin/sh
# Redstone hardware smoke test for an OpenBCM BDE bundle.

set -u

BUNDLE_DIR=${OPENBCM_BDE_BUNDLE_DIR:-.}
BASE_DIR=${REDSTONE_OPENBCM_SMOKE_DIR:-/var/log/redstone-stage1}
DMA_SIZE=${OPENBCM_BDE_DMA_SIZE:-4}
STRICT=0
LOAD_MODULES=1
RELOAD_EXISTING=0
UNLOAD_AFTER=0
RUN_CAPTURE=0
PASSES=0
WARNINGS=0
FAILURES=0
LOADED_LOCAL=0

usage() {
    cat <<EOF
Usage: redstone-openbcm-bde-smoke.sh [options]

Options:
  --bundle-dir DIR       directory containing the OpenBCM BDE bundle, default .
  --dma-size N           dma_size value for linux-kernel-bde.ko, default 4
  --no-load              inspect PCI, modules, and BDE nodes without insmod
  --reload-existing      rmmod existing BDE modules before loading bundle modules
  --unload-after         rmmod bundle modules after the smoke test
  --capture              run redstone-stage1-capture after the smoke test
  --strict               exit nonzero if any required check fails
  -h, --help             show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
    --bundle-dir)
        [ "$#" -gt 1 ] || { usage >&2; exit 2; }
        BUNDLE_DIR=$2
        shift 2
        ;;
    --dma-size)
        [ "$#" -gt 1 ] || { usage >&2; exit 2; }
        DMA_SIZE=$2
        shift 2
        ;;
    --no-load)
        LOAD_MODULES=0
        shift
        ;;
    --reload-existing)
        RELOAD_EXISTING=1
        shift
        ;;
    --unload-after)
        UNLOAD_AFTER=1
        shift
        ;;
    --capture)
        RUN_CAPTURE=1
        shift
        ;;
    --strict)
        STRICT=1
        shift
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
    esac
done

case "$DMA_SIZE" in
*[!0-9]*|"")
    echo "redstone-openbcm-bde-smoke.sh: invalid --dma-size: $DMA_SIZE" >&2
    exit 2
    ;;
esac

if ! mkdir -p "$BASE_DIR" 2>/dev/null; then
    BASE_DIR=/tmp/redstone-stage1
    mkdir -p "$BASE_DIR" || exit 1
fi

STAMP=$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%s)
OUT_DIR="$BASE_DIR/openbcm-bde-smoke-$STAMP"
LOG="$OUT_DIR/smoke.log"

mkdir -p "$OUT_DIR" || exit 1
: > "$LOG"

emit() {
    printf '%s\n' "$*" | tee -a "$LOG"
}

pass() {
    PASSES=$((PASSES + 1))
    emit "PASS: $*"
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    emit "WARN: $*"
}

fail() {
    FAILURES=$((FAILURES + 1))
    emit "FAIL: $*"
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

module_loaded() {
    mod=$1
    mod_us=$(printf '%s' "$mod" | tr '-' '_')
    grep -Eq "^($mod|$mod_us)[[:space:]]" /proc/modules 2>/dev/null
}

capture_cmd() {
    name=$1
    shift
    cmd=$1
    out="$OUT_DIR/$name.txt"

    {
        printf '$ %s\n\n' "$cmd"
        sh -c "$cmd"
        rc=$?
        printf '\nexit=%s\n' "$rc"
    } > "$out" 2>&1

    return "$rc"
}

check_file() {
    path=$1
    desc=$2

    if [ -f "$path" ]; then
        pass "$desc exists: $path"
    else
        fail "$desc missing: $path"
    fi
}

check_char() {
    path=$1
    desc=$2

    if [ -c "$path" ]; then
        pass "$desc exists: $path"
    else
        fail "$desc missing: $path"
    fi
}

ensure_char_node() {
    path=$1
    name=$2
    desc=$3

    if [ -c "$path" ]; then
        return 0
    fi

    if [ -e "$path" ]; then
        fail "$desc path exists but is not a character device: $path"
        return 1
    fi

    major=$(
        awk -v name="$name" '$2 == name { print $1; exit }' /proc/devices \
            2>/dev/null
    )
    if [ -z "$major" ]; then
        fail "$desc major not registered in /proc/devices: $name"
        return 1
    fi

    if mknod "$path" c "$major" 0 2>/dev/null && chmod 666 "$path" 2>/dev/null; then
        pass "$desc created: $path major=$major minor=0"
        return 0
    fi

    fail "$desc mknod failed: $path major=$major minor=0"
    return 1
}

check_module_loaded() {
    module=$1

    if module_loaded "$module"; then
        pass "module loaded: $module"
    else
        fail "module not loaded: $module"
    fi
}

unload_module_if_loaded() {
    module=$1

    if ! module_loaded "$module"; then
        return 0
    fi

    if capture_cmd "rmmod_$module" "rmmod $module"; then
        if module_loaded "$module"; then
            fail "module still loaded after rmmod: $module"
        else
            pass "module unloaded: $module"
        fi
    else
        fail "rmmod failed: $module"
    fi
}

unload_bde_modules() {
    unload_module_if_loaded linux-user-bde
    unload_module_if_loaded linux-kernel-bde
}

load_bde_modules() {
    kernel_module="$BUNDLE_DIR/linux-kernel-bde.ko"
    user_module="$BUNDLE_DIR/linux-user-bde.ko"

    check_file "$kernel_module" "OpenBCM kernel BDE module"
    check_file "$user_module" "OpenBCM user BDE module"

    if module_loaded linux-kernel-bde || module_loaded linux-user-bde; then
        if [ "$RELOAD_EXISTING" = "1" ]; then
            warn "existing BDE modules loaded; attempting explicit reload"
            unload_bde_modules
        else
            fail "BDE modules already loaded; stop switchd and use --reload-existing for bundle proof"
            return
        fi
    fi

    if module_loaded linux-kernel-bde || module_loaded linux-user-bde; then
        fail "existing BDE modules remain loaded; local OpenBCM bundle not loaded"
        return
    fi

    if capture_cmd insmod_linux_kernel_bde "insmod '$kernel_module' dma_size=$DMA_SIZE"; then
        pass "loaded OpenBCM linux-kernel-bde.ko from bundle"
        LOADED_LOCAL=1
    else
        fail "failed to load OpenBCM linux-kernel-bde.ko from bundle"
        return
    fi

    if capture_cmd insmod_linux_user_bde "insmod '$user_module'"; then
        pass "loaded OpenBCM linux-user-bde.ko from bundle"
    else
        fail "failed to load OpenBCM linux-user-bde.ko from bundle"
    fi
}

detect_bcm56846() {
    out="$OUT_DIR/pci_bcm56846.txt"
    : > "$out"

    if have_cmd lspci; then
        lspci -nn > "$out" 2>&1 || true
        if grep -qiE '(^|[^[:xdigit:]])14e4:b846([^[:xdigit:]]|$)' "$out"; then
            pass "BCM56846 PCIe device detected by lspci as 14e4:b846"
            return
        fi
    else
        printf 'lspci unavailable\n' >> "$out"
    fi

    for dev in /sys/bus/pci/devices/*; do
        [ -d "$dev" ] || continue
        vendor=$(cat "$dev/vendor" 2>/dev/null || true)
        device=$(cat "$dev/device" 2>/dev/null || true)
        printf '%s vendor=%s device=%s\n' "$dev" "$vendor" "$device" >> "$out"
        if [ "$vendor" = "0x14e4" ] && [ "$device" = "0xb846" ]; then
            pass "BCM56846 PCIe device detected in sysfs"
            return
        fi
    done

    fail "BCM56846 PCIe device not detected"
}

capture_summary() {
    capture_cmd uname 'uname -a' || true
    capture_cmd modules 'cat /proc/modules 2>/dev/null || true; echo; lsmod 2>/dev/null || true' || true
    capture_cmd bde_devices 'ls -l /dev 2>/dev/null | grep -iE "bde|bcm|uk|proxy" || true' || true
    capture_cmd dmesg_focus 'dmesg | grep -iE "openbcm|bcm|bde|trident|5684|pcie|pci|dma|shbde" || true' || true
}

emit "Redstone OpenBCM BDE smoke test"
emit "  output: $OUT_DIR"
emit "  bundle: $BUNDLE_DIR"
emit "  load modules: $LOAD_MODULES"
emit "  dma size: $DMA_SIZE"
emit ""

check_file "$BUNDLE_DIR/redstone-openbcm-bde.manifest" "OpenBCM BDE manifest"

if [ "$LOAD_MODULES" = "1" ]; then
    load_bde_modules
else
    warn "module loading skipped by --no-load"
fi

check_module_loaded linux-kernel-bde
check_module_loaded linux-user-bde
ensure_char_node /dev/linux-kernel-bde linux-kernel-bde "kernel BDE device"
ensure_char_node /dev/linux-user-bde linux-user-bde "user BDE device"
check_char /dev/linux-kernel-bde "kernel BDE device"
check_char /dev/linux-user-bde "user BDE device"
capture_summary
detect_bcm56846

if [ "$RUN_CAPTURE" = "1" ]; then
    if have_cmd redstone-stage1-capture; then
        if capture_cmd capture 'redstone-stage1-capture'; then
            pass "redstone-stage1-capture completed"
        else
            warn "redstone-stage1-capture returned nonzero"
        fi
    else
        warn "redstone-stage1-capture unavailable"
    fi
fi

if [ "$UNLOAD_AFTER" = "1" ]; then
    if [ "$LOADED_LOCAL" = "1" ]; then
        unload_bde_modules
    else
        warn "not unloading modules because this run did not prove local bundle load"
    fi
fi

emit ""
emit "Redstone OpenBCM BDE smoke complete: $PASSES pass, $WARNINGS warning(s), $FAILURES failure(s)"
emit "Evidence directory: $OUT_DIR"

if [ "$STRICT" = "1" ] && [ "$FAILURES" -ne 0 ]; then
    exit 1
fi

exit 0
