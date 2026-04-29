#!/bin/sh
# Analyze Redstone OpenBCM BDE smoke evidence on a host machine.

set -u

STRICT=0
INPUT=
TMPDIR=
ROOT=
PASSES=0
WARNINGS=0
FAILURES=0
FIRST_ACTION=

usage() {
    cat <<'EOF'
Usage: analyze-redstone-openbcm-bde-smoke.sh [--strict] PATH

PATH may be:
  - an openbcm-bde-smoke-* evidence directory
  - a .tar.gz/.tgz evidence tarball

--strict treats missing optional context, such as focused dmesg, as a failure.
EOF
}

cleanup() {
    if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
        rm -rf "$TMPDIR"
    fi
}
trap cleanup EXIT INT TERM

while [ "$#" -gt 0 ]; do
    case "$1" in
    --strict)
        STRICT=1
        shift
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    -*)
        usage >&2
        exit 2
        ;;
    *)
        if [ -n "$INPUT" ]; then
            usage >&2
            exit 2
        fi
        INPUT=$1
        shift
        ;;
    esac
done

if [ -z "$INPUT" ]; then
    usage >&2
    exit 2
fi

pass() {
    PASSES=$((PASSES + 1))
    printf 'PASS: %s\n' "$*"
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    printf 'WARN: %s\n' "$*"
}

fail() {
    FAILURES=$((FAILURES + 1))
    printf 'FAIL: %s\n' "$*"
    if [ -z "$FIRST_ACTION" ]; then
        FIRST_ACTION=$*
    fi
}

first_file() {
    root=$1
    name=$2
    find "$root" -type f -name "$name" -print 2>/dev/null | sort | head -n 1
}

file_has_text() {
    file=$1
    pattern=$2
    [ -f "$file" ] && grep -Eiq "$pattern" "$file"
}

has_text() {
    pattern=$1
    find "$ROOT" -type f -size -2097152c \
        -exec grep -Eiq "$pattern" {} \; -print -quit 2>/dev/null |
        grep -q .
}

has_file() {
    name=$1
    find "$ROOT" -type f -name "$name" -print -quit 2>/dev/null | grep -q .
}

extract_if_needed() {
    case "$INPUT" in
    *.tar.gz|*.tgz)
        if ! command -v tar >/dev/null 2>&1; then
            fail "tar is unavailable; cannot inspect $INPUT"
            return
        fi
        TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/redstone-openbcm-bde.XXXXXX") || exit 1
        if tar -xzf "$INPUT" -C "$TMPDIR"; then
            pass "extracted BDE smoke evidence tarball"
        else
            fail "failed to extract BDE smoke evidence tarball: $INPUT"
            return
        fi
        child_count=$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
        if [ "$child_count" = "1" ]; then
            ROOT=$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d -print | head -n 1)
        else
            ROOT=$TMPDIR
        fi
        ;;
    *)
        if [ -d "$INPUT" ]; then
            ROOT=$INPUT
        else
            fail "BDE smoke evidence path is not a directory or .tar.gz/.tgz file: $INPUT"
            return
        fi
        ;;
    esac
}

report_action() {
    case "$FIRST_ACTION" in
    *"bundle load proof"*)
        printf 'Next action: rerun ./redstone-openbcm-bde-smoke.sh --strict from the OpenBCM BDE bundle before switchd or platform BDE modules load.\n'
        ;;
    *"BCM56846"*)
        printf 'Next action: inspect PCIe reset, DTS PCI windows, and BDE probe logs before changing SDK init code.\n'
        ;;
    *"device-node"*|*"module"*)
        printf 'Next action: inspect linux-kernel-bde/linux-user-bde load order, insmod logs, and /dev node creation.\n'
        ;;
    *"smoke log"*)
        printf 'Next action: copy the complete openbcm-bde-smoke-* directory or tarball from Redstone.\n'
        ;;
    "")
        ;;
    *)
        printf 'Next action: inspect the first FAIL line above and compare it with the raw BDE smoke evidence files.\n'
        ;;
    esac
}

extract_if_needed

if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
    printf '\nRedstone OpenBCM BDE smoke analysis failed before inspection: %s failure(s)\n' "$FAILURES" >&2
    exit 1
fi

SMOKE_LOG=$(first_file "$ROOT" smoke.log)
MANIFEST=$(first_file "$ROOT" redstone-openbcm-bde.manifest)
MODULES_FILE=$(first_file "$ROOT" modules.txt)
BDE_DEV_FILE=$(first_file "$ROOT" bde_devices.txt)
PCI_FILE=$(first_file "$ROOT" pci_bcm56846.txt)
DMESG_FILE=$(first_file "$ROOT" dmesg_focus.txt)

printf 'Redstone OpenBCM BDE smoke evidence analysis\n'
printf '  input: %s\n' "$INPUT"
printf '  root: %s\n' "$ROOT"
printf '  strict: %s\n\n' "$STRICT"

if [ -n "$SMOKE_LOG" ]; then
    pass "smoke log found: ${SMOKE_LOG#$ROOT/}"
    if file_has_text "$SMOKE_LOG" '^FAIL:'; then
        fail "smoke log contains FAIL lines"
    else
        pass "smoke log has no FAIL lines"
    fi
    if file_has_text "$SMOKE_LOG" '^WARN:'; then
        warn "smoke log contains WARN lines"
    else
        pass "smoke log has no WARN lines"
    fi
    if file_has_text "$SMOKE_LOG" 'Redstone OpenBCM BDE smoke complete: .* 0 failure\(s\)'; then
        pass "smoke summary reports 0 failures"
    else
        fail "smoke summary does not report 0 failures"
    fi
else
    fail "smoke log not found"
fi

if [ -n "$MANIFEST" ] || { [ -n "$SMOKE_LOG" ] &&
        file_has_text "$SMOKE_LOG" '^PASS: OpenBCM BDE manifest exists:'; }; then
    pass "OpenBCM BDE manifest evidence found"
else
    fail "OpenBCM BDE manifest evidence missing"
fi

if [ -n "$SMOKE_LOG" ] &&
    file_has_text "$SMOKE_LOG" '^PASS: loaded OpenBCM linux-kernel-bde\.ko from bundle$' &&
    file_has_text "$SMOKE_LOG" '^PASS: loaded OpenBCM linux-user-bde\.ko from bundle$'; then
    pass "OpenBCM BDE bundle load proof found"
else
    fail "OpenBCM BDE bundle load proof missing"
fi

if [ -n "$SMOKE_LOG" ] &&
    file_has_text "$SMOKE_LOG" 'BDE modules already loaded|local OpenBCM bundle not loaded'; then
    fail "smoke log shows existing BDE modules prevented bundle-load proof"
fi

if { [ -n "$MODULES_FILE" ] &&
        file_has_text "$MODULES_FILE" '(^|[[:space:]])linux[-_]kernel[-_]bde([[:space:]]|$)' &&
        file_has_text "$MODULES_FILE" '(^|[[:space:]])linux[-_]user[-_]bde([[:space:]]|$)'; } ||
    { [ -n "$SMOKE_LOG" ] &&
        file_has_text "$SMOKE_LOG" '^PASS: module loaded: linux-kernel-bde$' &&
        file_has_text "$SMOKE_LOG" '^PASS: module loaded: linux-user-bde$'; }; then
    pass "OpenBCM BDE module-loaded evidence found"
else
    fail "OpenBCM BDE module-loaded evidence missing"
fi

if { [ -n "$BDE_DEV_FILE" ] &&
        file_has_text "$BDE_DEV_FILE" 'linux-kernel-bde' &&
        file_has_text "$BDE_DEV_FILE" 'linux-user-bde'; } ||
    { [ -n "$SMOKE_LOG" ] &&
        file_has_text "$SMOKE_LOG" '^PASS: kernel BDE device exists: /dev/linux-kernel-bde$' &&
        file_has_text "$SMOKE_LOG" '^PASS: user BDE device exists: /dev/linux-user-bde$'; }; then
    pass "OpenBCM BDE device-node evidence found"
else
    fail "OpenBCM BDE device-node evidence missing"
fi

if { [ -n "$PCI_FILE" ] &&
        { file_has_text "$PCI_FILE" '(^|[^[:xdigit:]])14e4:b846([^[:xdigit:]]|$)' ||
            file_has_text "$PCI_FILE" 'vendor=0x14e4[[:space:]]+device=0xb846'; }; } ||
    { [ -n "$SMOKE_LOG" ] &&
        { file_has_text "$SMOKE_LOG" '^PASS: BCM56846 PCIe device detected by lspci as 14e4:b846$' ||
            file_has_text "$SMOKE_LOG" '^PASS: BCM56846 PCIe device detected in sysfs$'; }; }; then
    pass "exact BCM56846 PCIe evidence found"
else
    fail "exact BCM56846 PCIe evidence missing"
fi

if [ -n "$PCI_FILE" ] || has_file pci_bcm56846.txt; then
    pass "PCI evidence file found"
else
    warn "PCI evidence file not found"
fi

if [ -n "$DMESG_FILE" ] || has_file dmesg_focus.txt; then
    pass "focused dmesg evidence found"
else
    if [ "$STRICT" = "1" ]; then
        fail "focused dmesg evidence missing"
    else
        warn "focused dmesg evidence missing"
    fi
fi

printf '\nRedstone OpenBCM BDE smoke evidence summary: %s pass, %s warning(s), %s failure(s)\n' \
    "$PASSES" "$WARNINGS" "$FAILURES"
report_action

if [ "$FAILURES" -ne 0 ]; then
    exit 1
fi

exit 0
