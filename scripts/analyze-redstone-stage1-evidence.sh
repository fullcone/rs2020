#!/bin/sh
# Analyze Redstone stage-1 validation or capture evidence on a host machine.

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
Usage: analyze-redstone-stage1-evidence.sh [--strict] PATH

PATH may be:
  - a redstone-stage1-validate output directory
  - a redstone-stage1-capture output directory
  - a .tar.gz/.tgz capture tarball

--strict exits nonzero when required acceptance evidence is missing.
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

has_text() {
    pattern=$1
    find "$ROOT" -type f -size -2097152c \
        -exec grep -Eiq "$pattern" {} \; -print -quit 2>/dev/null |
        grep -q .
}

file_has_text() {
    file=$1
    pattern=$2
    [ -f "$file" ] && grep -Eiq "$pattern" "$file"
}

has_file() {
    name=$1
    find "$ROOT" -type f -name "$name" -print -quit 2>/dev/null | grep -q .
}

has_path() {
    name=$1
    find "$ROOT" -name "$name" -print -quit 2>/dev/null | grep -q .
}

has_swp_link_up() {
    if has_text 'front-panel link is up: swp[0-9]+|at least one swp link is up: swp[0-9]+'; then
        return 0
    fi

    find "$ROOT" -type f -size -2097152c -exec awk '
        /^##[[:space:]]+swp[0-9]+/ {
            in_swp = 1
            next
        }
        /^##[[:space:]]+/ {
            in_swp = 0
            next
        }
        /^[0-9]+:[[:space:]]+swp[0-9]+[:@]/ {
            line = tolower($0)
            if (line ~ /lower_up/ || line ~ /state[[:space:]]+up/) {
                found = 1
            }
        }
        in_swp {
            line = tolower($0)
            if (line ~ /^carrier=1$/ ||
                line ~ /^operstate=up$/ ||
                line ~ /link detected:[[:space:]]*yes/ ||
                line ~ /lower_up/ ||
                line ~ /state[[:space:]]+up/) {
                found = 1
            }
        }
        END {
            exit found ? 0 : 1
        }
    ' {} \; -print -quit 2>/dev/null | grep -q .
}

has_exact_bcm56846_pci_evidence() {
    pci_file=$(first_file "$ROOT" pci_bcm56846.txt)

    if [ -n "$pci_file" ] &&
        { file_has_text "$pci_file" '(^|[^[:xdigit:]])14e4:b846([^[:xdigit:]]|$)' ||
            file_has_text "$pci_file" 'vendor=0x14e4[[:space:]]+device=0xb846'; }; then
        return 0
    fi

    if [ -n "${VALIDATE_LOG:-}" ] &&
        { file_has_text "$VALIDATE_LOG" '^PASS: BCM56846 PCIe device detected by lspci as 14e4:b846$' ||
            file_has_text "$VALIDATE_LOG" '^PASS: BCM56846 PCIe device detected in sysfs$'; }; then
        return 0
    fi

    has_text '(^|[^[:xdigit:]])14e4:b846([^[:xdigit:]]|$)|vendor=0x14e4[[:space:]]+device=0xb846'
}

extract_if_needed() {
    case "$INPUT" in
    *.tar.gz|*.tgz)
        if ! command -v tar >/dev/null 2>&1; then
            fail "tar is unavailable; cannot inspect $INPUT"
            return
        fi
        TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/redstone-evidence.XXXXXX") || exit 1
        if tar -xzf "$INPUT" -C "$TMPDIR"; then
            pass "extracted evidence tarball"
        else
            fail "failed to extract evidence tarball: $INPUT"
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
            fail "evidence path is not a directory or .tar.gz/.tgz file: $INPUT"
            return
        fi
        ;;
    esac
}

report_action() {
    case "$FIRST_ACTION" in
    *"board selector"*)
        printf 'Next action: verify /etc/edgenos/board is redstone, rs2020, or r0678 before switchd starts.\n'
        ;;
    *"BCM56846"*)
        printf 'Next action: inspect PCIe reset, DTS PCI window, and BDE probe logs before changing switchd config.\n'
        ;;
    *"BDE"*)
        printf 'Next action: check linux-kernel-bde/linux-user-bde module load order, /dev nodes, and kernel dmesg.\n'
        ;;
    *"switchd"*)
        printf 'Next action: inspect switchd-init status, /etc/switchd/redstone-stage1.bcm, and switchd stderr/log output.\n'
        ;;
    *"swp"*|*"link"*)
        printf 'Next action: inspect switchd port creation, retimer/CPLD init logs, and the selected front-panel port link partner.\n'
        ;;
    *"ping"*)
        printf 'Next action: keep the link-up port fixed, assign bench IPs, and rerun validation with --peer.\n'
        ;;
    "")
        ;;
    *)
        printf 'Next action: inspect the first FAIL line above and compare it with the raw evidence files.\n'
        ;;
    esac
}

extract_if_needed

if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
    printf '\nRedstone stage-1 evidence analysis failed before inspection: %s failure(s)\n' "$FAILURES" >&2
    exit 1
fi

VALIDATE_LOG=$(first_file "$ROOT" validate.log)
CAPTURE_LOG=$(first_file "$ROOT" capture.log)
PING_FILE=$(first_file "$ROOT" ping.txt)
BDE_DEV_FILE=$(first_file "$ROOT" bde_devices.txt)

printf 'Redstone stage-1 evidence analysis\n'
printf '  input: %s\n' "$INPUT"
printf '  root: %s\n' "$ROOT"
printf '  strict: %s\n\n' "$STRICT"

if [ -n "$VALIDATE_LOG" ]; then
    pass "validation log found: ${VALIDATE_LOG#$ROOT/}"
    if file_has_text "$VALIDATE_LOG" '^FAIL:'; then
        fail "validation log contains FAIL lines"
    else
        pass "validation log has no FAIL lines"
    fi
    if file_has_text "$VALIDATE_LOG" '^WARN:'; then
        warn "validation log contains WARN lines"
    else
        pass "validation log has no WARN lines"
    fi
    if file_has_text "$VALIDATE_LOG" 'Redstone stage-1 validation complete: .* 0 failure\(s\)'; then
        pass "validation summary reports 0 failures"
    else
        fail "validation summary does not report 0 failures"
    fi
else
    if [ "$STRICT" = "1" ]; then
        fail "validation log not found; capture-only evidence cannot prove acceptance by itself"
    else
        warn "validation log not found; capture-only evidence cannot prove acceptance by itself"
    fi
fi

if [ -n "$CAPTURE_LOG" ]; then
    pass "capture log found: ${CAPTURE_LOG#$ROOT/}"
else
    warn "capture log not found; DTS/platform follow-up evidence may be incomplete"
fi

if has_text 'board selector is Redstone-compatible|^redstone$|^rs2020$|^r0678$'; then
    pass "Redstone board selector evidence found"
else
    fail "Redstone board selector evidence missing"
fi

if has_text 'redstone-stage1\.bcm' && has_text 'portmap_52|52-port map'; then
    pass "Redstone switchd config and 52-port map evidence found"
else
    fail "Redstone switchd config or portmap_52 evidence missing"
fi

if has_text 'linux[-_]kernel[-_]bde' && has_text 'linux[-_]user[-_]bde'; then
    pass "BDE module evidence found"
else
    fail "BDE module evidence missing"
fi

if { [ -n "$BDE_DEV_FILE" ] &&
        file_has_text "$BDE_DEV_FILE" 'linux-kernel-bde' &&
        file_has_text "$BDE_DEV_FILE" 'linux-user-bde'; } ||
    { has_text '/dev/linux-kernel-bde|linux-kernel-bde.*device|kernel BDE device exists' &&
        has_text '/dev/linux-user-bde|linux-user-bde.*device|user BDE device exists'; }; then
    pass "BDE device-node evidence found"
else
    fail "BDE device-node evidence missing"
fi

if has_exact_bcm56846_pci_evidence; then
    pass "exact BCM56846 PCIe evidence found"
else
    fail "exact BCM56846 PCIe evidence missing"
fi

if has_text 'switchd is running|switchd.*running via|PASS: switchd is running'; then
    pass "switchd running evidence found"
else
    fail "switchd running evidence missing"
fi

if has_text 'swp[0-9]+'; then
    pass "swp interface evidence found"
else
    fail "swp interface evidence missing"
fi

if has_swp_link_up; then
    pass "front-panel link-up evidence found"
else
    fail "front-panel link-up evidence missing"
fi

if [ -n "$PING_FILE" ]; then
    if file_has_text "$PING_FILE" '^exit=0$'; then
        pass "ping command evidence succeeded"
    else
        fail "ping command evidence did not exit 0"
    fi
elif has_text 'ping succeeded'; then
    pass "ping success evidence found"
else
    if [ "$STRICT" = "1" ]; then
        fail "ping evidence missing; run validation with --peer for stage-1 acceptance"
    else
        warn "ping evidence missing; run validation with --peer for stage-1 acceptance"
    fi
fi

if has_file dmesg_redstone_focus.txt || has_file dmesg_focus.txt; then
    pass "focused dmesg evidence found"
else
    warn "focused dmesg evidence missing"
fi

if has_path sys_class_eeprom || has_path sys_class_cpld || has_path sys_class_kennisis_cpld || has_path sys_class_hwmon; then
    pass "platform sysfs class evidence directory found"
else
    warn "platform sysfs class evidence not found"
fi

printf '\nRedstone stage-1 evidence summary: %s pass, %s warning(s), %s failure(s)\n' \
    "$PASSES" "$WARNINGS" "$FAILURES"
report_action

if [ "$FAILURES" -ne 0 ]; then
    exit 1
fi

exit 0
