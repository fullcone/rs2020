#!/bin/sh
# Build a host-side Redstone platform/DTS inventory from returned capture evidence.
set -u

SCRIPT_NAME=$(basename "$0")
TMP_ROOT=
ROOT=

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME PATH_TO_VALIDATION_BUNDLE_OR_DIR

Classifies returned Redstone capture evidence into OBSERVED/PENDING platform
items for DTS, board-file, and driver follow-up. Pending rows are advisory and
do not make this tool fail; invalid input or extraction failures do.
EOF
}

cleanup() {
    if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
        rm -rf "$TMP_ROOT"
    fi
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

materialize_input() {
    input=$1

    if [ -d "$input" ]; then
        ROOT=$input
        return 0
    fi

    if [ ! -f "$input" ]; then
        fail "input path does not exist: $input"
    fi

    case "$input" in
        *.tar.gz|*.tgz)
            TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/redstone-platform-inventory.XXXXXX") || fail "mktemp failed"
            tar -xzf "$input" -C "$TMP_ROOT" || fail "failed to extract capture bundle: $input"
            ROOT=$TMP_ROOT
            ;;
        *)
            fail "unsupported input type, expected directory, .tar.gz, or .tgz: $input"
            ;;
    esac
}

has_text() {
    pattern=$1
    find "$ROOT" -type f -size -2097152c -exec grep -Eiq "$pattern" {} \; -print -quit 2>/dev/null | grep -q .
}

first_match() {
    pattern=$1
    find "$ROOT" -type f -size -2097152c -exec grep -Eih "$pattern" {} \; 2>/dev/null \
        | head -n 1 \
        | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//' \
        | cut -c 1-120
}

count_unique_i2c_buses() {
    find "$ROOT" -type f -size -2097152c -exec grep -Eho 'i2c-[0-9]+' {} \; 2>/dev/null \
        | sort -u \
        | wc -l \
        | tr -d ' '
}

print_row() {
    status=$1
    area=$2
    detail=$3
    printf '%-8s %-30s %s\n' "$status" "$area" "$detail"
}

observed() {
    OBSERVED=$((OBSERVED + 1))
    print_row "OBSERVED" "$1" "$2"
}

pending() {
    PENDING=$((PENDING + 1))
    print_row "PENDING" "$1" "$2"
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    print_row "WARN" "$1" "$2"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -ne 1 ]; then
    usage >&2
    exit 2
fi

trap cleanup EXIT INT TERM

materialize_input "$1"
if [ ! -d "$ROOT" ]; then
    fail "materialized capture root is not a directory: $ROOT"
fi

OBSERVED=0
PENDING=0
WARNINGS=0

echo "Redstone platform/DTS inventory from capture evidence"
echo "Capture root: $ROOT"
echo
printf '%-8s %-30s %s\n' "STATUS" "AREA" "EVIDENCE / NEXT ACTION"
printf '%-8s %-30s %s\n' "--------" "------------------------------" "----------------------"

if has_text 'R0678|RS2020|Redstone|redstone|D2012|D2020|Product[[:space:]]+Name|switch1_mac|pro_name'; then
    observed "board identity" "$(first_match 'R0678|RS2020|Redstone|redstone|D2012|D2020|Product[[:space:]]+Name|switch1_mac|pro_name')"
else
    pending "board identity" "capture product EEPROM and /etc/edgenos_board.txt before pinning board selector"
fi

if has_text 'fsl,P2020|P2020RDB|/proc/device-tree/model|/proc/device-tree/compatible|model[[:space:]]*=|compatible[[:space:]]='; then
    observed "device-tree base" "$(first_match 'fsl,P2020|P2020RDB|/proc/device-tree/model|/proc/device-tree/compatible|model[[:space:]]*=|compatible[[:space:]]=')"
else
    pending "device-tree base" "capture /proc/device-tree/model and compatible before deriving Redstone DTS"
fi

if has_text '(^|[^[:xdigit:]])14e4:b846([^[:xdigit:]]|$)|vendor=0x14e4[[:space:]]+device=0xb846|device=0xb846[[:space:]]+vendor=0x14e4'; then
    observed "BCM56846 PCIe" "$(first_match '(^|[^[:xdigit:]])14e4:b846([^[:xdigit:]]|$)|vendor=0x14e4[[:space:]]+device=0xb846|device=0xb846[[:space:]]+vendor=0x14e4')"
elif has_text 'BCM56846|bcm56846|(^|[^[:xdigit:]])b846([^[:xdigit:]]|$)|(^|[^[:xdigit:]])56846([^[:xdigit:]]|$)'; then
    warn "BCM56846 PCIe" "device-like text found without exact 14e4:b846 evidence; keep PCIe row pending"
else
    pending "BCM56846 PCIe" "capture lspci -nn and /sys/bus/pci/devices vendor/device"
fi

i2c_count=$(count_unique_i2c_buses)
if [ "$i2c_count" -gt 0 ] 2>/dev/null; then
    observed "I2C bus map" "$i2c_count unique bus label(s) observed; map mux topology from i2cdetect/i2c_list evidence"
else
    pending "I2C bus map" "capture i2c bus list before adding mux channels to DTS"
fi

if has_text 'i2cdetect|UU|[[:space:]][0-7][0-9a-f]:|scan skipped|i2c_scan_skipped'; then
    if has_text 'scan skipped|i2c_scan_skipped'; then
        warn "I2C live scan" "scan was skipped; use bus inventory only until safe scan data exists"
    else
        observed "I2C live scan" "$(first_match 'i2cdetect|UU|[[:space:]][0-7][0-9a-f]:')"
    fi
else
    pending "I2C live scan" "return safe i2cdetect captures or explicit skip note"
fi

if has_text 'kennisis_cpld|/sys/class/kennisis_cpld|/sys/class/cpld|CPLD@|cpld'; then
    observed "CPLD/sysfs" "$(first_match 'kennisis_cpld|/sys/class/kennisis_cpld|/sys/class/cpld|CPLD@|cpld')"
else
    pending "CPLD/sysfs" "capture CPLD sysfs tree and register dump before modeling board control"
fi

if has_text 'hwmon|thermal|temp[0-9]_input|fan[0-9]_input|ambient|lm75|tmp75'; then
    observed "hwmon/thermal" "$(first_match 'hwmon|thermal|temp[0-9]_input|fan[0-9]_input|ambient|lm75|tmp75')"
else
    pending "hwmon/thermal" "capture /sys/class/hwmon and thermal zones for DTS sensor nodes"
fi

if has_text 'gianfar|eTSEC|ethernet@[0-9a-f]+|fm[0-9]|eth[0-9]|mgmt'; then
    observed "management Ethernet" "$(first_match 'gianfar|eTSEC|ethernet@[0-9a-f]+|fm[0-9]|eth[0-9]|mgmt')"
else
    pending "management Ethernet" "capture ip link, ethtool -i, and DT ethernet nodes"
fi

if has_text 'swp[0-9]+|front[ -]?panel|port[[:space:]]+[0-9]+|link up|LOWER_UP'; then
    observed "front-panel netdev" "$(first_match 'swp[0-9]+|front[ -]?panel|port[[:space:]]+[0-9]+|link up|LOWER_UP')"
else
    pending "front-panel netdev" "capture switchd port inventory and one link-up port"
fi

if has_text 'sfp|qsfp|transceiver|module[[:space:]]+present|eeprom'; then
    observed "optics presence" "$(first_match 'sfp|qsfp|transceiver|module[[:space:]]+present|eeprom')"
else
    pending "optics presence" "capture SFP/QSFP GPIO, EEPROM, and presence paths before DTS wiring"
fi

if has_text 'fan[0-9]|pwm[0-9]|tach|psu|power[[:space:]]+supply|led|locator'; then
    observed "fans/PSU/LEDs" "$(first_match 'fan[0-9]|pwm[0-9]|tach|psu|power[[:space:]]+supply|led|locator')"
else
    pending "fans/PSU/LEDs" "capture platform control sysfs before claiming board-service coverage"
fi

echo
echo "Summary: $OBSERVED observed, $PENDING pending, $WARNINGS warning(s)"
echo "Next action: promote only OBSERVED rows into Redstone DTS/driver work; keep PENDING rows in the hardware inventory until hardware evidence exists."

exit 0
