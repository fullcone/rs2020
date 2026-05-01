#!/bin/sh
# Generate/check a Redstone original-active SDK config reference.
#
# The generated files contain vendor SDK configuration bodies and are written
# only under output/. The tracked manifest stores hashes and structural facts so
# the reference can be checked without committing the proprietary config text.

set -eu

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"

ORIGINAL_ROOT=${REDSTONE_ORIGINAL_ROOT:-}
if [ -z "$ORIGINAL_ROOT" ]; then
    if [ -d "$TOPDIR/../../startup_redstone_t/ZEBOS/bcm" ]; then
        ORIGINAL_ROOT="$(cd "$TOPDIR/../.." && pwd)"
    else
        ORIGINAL_ROOT="$TOPDIR"
    fi
fi

SOURCE_BCM_DIR=${REDSTONE_ORIGINAL_BCM_DIR:-"$ORIGINAL_ROOT/startup_redstone_t/ZEBOS/bcm"}
SPLIT_CONFIG=${REDSTONE_SPLIT_CONFIG:-}
if [ -z "$SPLIT_CONFIG" ]; then
    if [ -f "$ORIGINAL_ROOT/cf_card/startup/ZebOS.conf.disabled" ]; then
        SPLIT_CONFIG="$ORIGINAL_ROOT/cf_card/startup/ZebOS.conf.disabled"
    elif [ -f "$ORIGINAL_ROOT/startup_original/ZebOS.conf.disabled" ]; then
        SPLIT_CONFIG="$ORIGINAL_ROOT/startup_original/ZebOS.conf.disabled"
    else
        SPLIT_CONFIG="$ORIGINAL_ROOT/ZebOS.conf.disabled"
    fi
fi

OUTDIR=${REDSTONE_ORIGINAL_ACTIVE_OUT:-"$TOPDIR/output/redstone-original-active-sdk"}
MANIFEST=${REDSTONE_ORIGINAL_ACTIVE_MANIFEST:-"$TOPDIR/config/bcm/redstone-original-active-sdk.manifest"}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

note() {
    printf '%s\n' "$*"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [check|generate|manifest|print-env|clean]

Environment:
  REDSTONE_ORIGINAL_ROOT           extracted firmware root
  REDSTONE_ORIGINAL_BCM_DIR        directory containing config.bcm.in/split.sh
  REDSTONE_SPLIT_CONFIG            ZebOS config with active split lines
  REDSTONE_ORIGINAL_ACTIVE_OUT     ignored output directory
  REDSTONE_ORIGINAL_ACTIVE_MANIFEST tracked expected manifest
EOF
}

sha256_file() {
    file=$1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        die "missing sha256sum/shasum"
    fi
}

require_file() {
    [ -f "$1" ] || die "missing required file: $1"
}

has_split() {
    iface=$1
    grep -Eq "^[[:space:]]*split[[:space:]]+interface[[:space:]]+$iface([[:space:]]|$)" "$SPLIT_CONFIG"
}

line_present() {
    pattern=$1
    file=$2
    if tr -d '\r' < "$file" | grep -Eq "$pattern"; then
        printf true
    else
        printf false
    fi
}

split_interfaces() {
    list=
    for iface in fxe49 fxe50 fxe51 fxe52; do
        if has_split "$iface"; then
            if [ -n "$list" ]; then
                list="$list,$iface"
            else
                list="$iface"
            fi
        fi
    done
    [ -n "$list" ] || list=none
    printf '%s' "$list"
}

egress_cells() {
    cells=$(
        awk '
            /^[[:space:]]*egress[[:space:]]+cell[[:space:]]+[0-9]+/ {
                print $3
            }
        ' "$SPLIT_CONFIG" | tr '\n' ' ' | sed 's/[[:space:]]*$//'
    )
    [ -n "$cells" ] || cells=none
    printf '%s' "$cells"
}

check_sources() {
    require_file "$SOURCE_BCM_DIR/config.bcm.in"
    require_file "$SOURCE_BCM_DIR/phy.soc.in"
    require_file "$SOURCE_BCM_DIR/fixup.soc.in"
    require_file "$SOURCE_BCM_DIR/rc.soc"
    require_file "$SOURCE_BCM_DIR/qsfp_led.soc"
    require_file "$SOURCE_BCM_DIR/startup"
    require_file "$SOURCE_BCM_DIR/split.sh"
    require_file "$SOURCE_BCM_DIR/mmu.sh"
    require_file "$SPLIT_CONFIG"

    has_split fxe49 || die "expected active split line for fxe49 in $SPLIT_CONFIG"
    has_split fxe50 || die "expected active split line for fxe50 in $SPLIT_CONFIG"
    has_split fxe51 || die "expected active split line for fxe51 in $SPLIT_CONFIG"
    if has_split fxe52; then
        die "expected fxe52 to remain unsplit in original-active profile"
    fi
}

append_config_group() {
    iface=$1
    label=$2
    lane_base=$3
    lane_map=$4
    logical_port=$5
    phy_port=$6
    phy_addr=${7:-}

    printf '#%s\n' "$label"
    if has_split "$iface"; then
        i=0
        while [ "$i" -lt 4 ]; do
            printf 'portmap_%s=%s:10\n' "$((logical_port + i))" "$((lane_base + i))"
            i=$((i + 1))
        done
        printf 'xgxs_tx_lane_map_xe%s=%s\n' "$phy_port" "$lane_map"
        if [ -n "$phy_addr" ]; then
            i=0
            while [ "$i" -lt 4 ]; do
                printf 'port_phy_addr_xe%s=%s\n' "$((phy_port + i))" "$phy_addr"
                i=$((i + 1))
            done
        fi
    else
        printf 'portmap_%s=%s:40\n' "$logical_port" "$lane_base"
        printf 'xgxs_tx_lane_map_xe%s=%s\n' "$phy_port" "$lane_map"
        if [ -n "$phy_addr" ]; then
            printf 'port_phy_addr_xe%s=%s\n' "$phy_port" "$phy_addr"
        fi
    fi
}

append_phy_group() {
    iface=$1
    phy_port=$2

    if has_split "$iface"; then
        i=0
        while [ "$i" -lt 4 ]; do
            printf 'port xe%s an=off speed=10000\n' "$((phy_port + i))"
            i=$((i + 1))
        done
    else
        printf 'port xe%s an=off speed=40000\n' "$phy_port"
    fi
}

generate_files() {
    out=$1
    rm -rf "$out"
    mkdir -p "$out"

    cp "$SOURCE_BCM_DIR/config.bcm.in" "$out/config.bcm"
    cp "$SOURCE_BCM_DIR/phy.soc.in" "$out/phy.soc"
    cp "$SOURCE_BCM_DIR/fixup.soc.in" "$out/fixup.soc"
    cp "$SOURCE_BCM_DIR/rc.soc" "$out/rc.soc"
    cp "$SOURCE_BCM_DIR/qsfp_led.soc" "$out/qsfp_led.soc"
    cp "$SOURCE_BCM_DIR/startup" "$out/startup"

    port=49
    phy=48
    {
        printf '\n# Original active split profile generated from Redstone split.sh rules.\n'
        append_config_group fxe49 WC15 61 0x2031 "$port" "$phy"
    } >> "$out/config.bcm"
    if has_split fxe49; then port=$((port + 4)); phy=$((phy + 4)); else port=$((port + 1)); phy=$((phy + 1)); fi

    {
        append_config_group fxe50 WC14 57 0x2031 "$port" "$phy" 0x5c
    } >> "$out/config.bcm"
    if has_split fxe50; then port=$((port + 4)); phy=$((phy + 4)); else port=$((port + 1)); phy=$((phy + 1)); fi

    {
        append_config_group fxe51 WC17 69 0x3120 "$port" "$phy"
    } >> "$out/config.bcm"
    if has_split fxe51; then port=$((port + 4)); phy=$((phy + 4)); else port=$((port + 1)); phy=$((phy + 1)); fi

    {
        append_config_group fxe52 WC16 65 0x2031 "$port" "$phy"
    } >> "$out/config.bcm"

    phy=48
    {
        printf '\n# Original active split profile generated from Redstone split.sh rules.\n'
        append_phy_group fxe49 "$phy"
    } >> "$out/phy.soc"
    if has_split fxe49; then phy=$((phy + 4)); else phy=$((phy + 1)); fi

    {
        append_phy_group fxe50 "$phy"
    } >> "$out/phy.soc"
    if has_split fxe50; then phy=$((phy + 4)); else phy=$((phy + 1)); fi

    {
        append_phy_group fxe51 "$phy"
    } >> "$out/phy.soc"
    if has_split fxe51; then phy=$((phy + 4)); else phy=$((phy + 1)); fi

    {
        append_phy_group fxe52 "$phy"
        printf 'linkscan 250000\n'
        printf 'echo rc: phy init complete\n'
    } >> "$out/phy.soc"

    cells=$(egress_cells)
    if [ "$cells" != none ]; then
        idx=0
        for cell in $cells; do
            printf 'REG THDO_CONFIG_PORT_UC%s.Q_SHARED_LIMIT_CELL = %s\n' "$idx" "$cell" >> "$out/fixup.soc"
            printf 'REG THDO_CONFIG_PORT_MC%s.Q_SHARED_LIMIT_CELL = %s\n' "$idx" "$cell" >> "$out/fixup.soc"
            idx=$((idx + 1))
        done
    fi

    cat > "$out/SOURCE-MANIFEST.txt" <<EOF
source_bcm_dir=$SOURCE_BCM_DIR
split_config=$SPLIT_CONFIG
split_interfaces=$(split_interfaces)
egress_cells=$(egress_cells)
config_bcm_in_sha256=$(sha256_file "$SOURCE_BCM_DIR/config.bcm.in")
split_sh_sha256=$(sha256_file "$SOURCE_BCM_DIR/split.sh")
mmu_sh_sha256=$(sha256_file "$SOURCE_BCM_DIR/mmu.sh")
phy_soc_in_sha256=$(sha256_file "$SOURCE_BCM_DIR/phy.soc.in")
fixup_soc_in_sha256=$(sha256_file "$SOURCE_BCM_DIR/fixup.soc.in")
rc_soc_sha256=$(sha256_file "$SOURCE_BCM_DIR/rc.soc")
qsfp_led_soc_sha256=$(sha256_file "$SOURCE_BCM_DIR/qsfp_led.soc")
startup_sha256=$(sha256_file "$SOURCE_BCM_DIR/startup")
generated_config_bcm_sha256=$(sha256_file "$out/config.bcm")
generated_phy_soc_sha256=$(sha256_file "$out/phy.soc")
generated_fixup_soc_sha256=$(sha256_file "$out/fixup.soc")
generated_rc_soc_sha256=$(sha256_file "$out/rc.soc")
generated_qsfp_led_soc_sha256=$(sha256_file "$out/qsfp_led.soc")
generated_startup_sha256=$(sha256_file "$out/startup")
EOF
}

write_manifest() {
    out=$1
    config="$out/config.bcm"
    phy="$out/phy.soc"
    fixup="$out/fixup.soc"

    split_list=$(split_interfaces)
    cell_list=$(egress_cells)
    src_config_sha=$(sha256_file "$SOURCE_BCM_DIR/config.bcm.in")
    src_split_sha=$(sha256_file "$SOURCE_BCM_DIR/split.sh")
    src_mmu_sha=$(sha256_file "$SOURCE_BCM_DIR/mmu.sh")
    src_phy_sha=$(sha256_file "$SOURCE_BCM_DIR/phy.soc.in")
    src_fixup_sha=$(sha256_file "$SOURCE_BCM_DIR/fixup.soc.in")
    src_rc_sha=$(sha256_file "$SOURCE_BCM_DIR/rc.soc")
    src_qsfp_sha=$(sha256_file "$SOURCE_BCM_DIR/qsfp_led.soc")
    src_startup_sha=$(sha256_file "$SOURCE_BCM_DIR/startup")
    gen_config_sha=$(sha256_file "$config")
    gen_phy_sha=$(sha256_file "$phy")
    gen_fixup_sha=$(sha256_file "$fixup")
    gen_rc_sha=$(sha256_file "$out/rc.soc")
    gen_qsfp_sha=$(sha256_file "$out/qsfp_led.soc")
    gen_startup_sha=$(sha256_file "$out/startup")
    portmap_count=$(grep -Ec '^portmap_[0-9]+=' "$config" || true)
    split_10g_count=$(grep -Ec '^portmap_[0-9]+=[0-9]+:10$' "$config" || true)
    qsfp_40g_count=$(grep -Ec '^portmap_[0-9]+=65:40$' "$config" || true)
    phy_10g_count=$(grep -Ec '^port xe[0-9]+ an=off speed=10000$' "$phy" || true)
    phy_40g_count=$(grep -Ec '^port xe[0-9]+ an=off speed=40000$' "$phy" || true)
    has_pbmp=$(line_present '^pbmp_xport_xe=0x1fffffffffffffffe$' "$config")
    has_l2xmsg=$(line_present '^l2xmsg_chunks=256$' "$config")
    has_phy_84848=$(line_present '^phy_84848=1$' "$config")
    has_fxe49=$(line_present '^portmap_49=61:10$' "$config")
    has_fxe50=$(line_present '^portmap_53=57:10$' "$config")
    has_fxe51=$(line_present '^portmap_57=69:10$' "$config")
    has_fxe52=$(line_present '^portmap_61=65:40$' "$config")

    cat <<EOF
schema=redstone-original-active-sdk-reference.v1
source_profile=redstone_t_startup_bcm
split_interfaces=$split_list
unsplit_interfaces=fxe52
egress_cells=$cell_list
source_config_bcm_in_sha256=$src_config_sha
source_split_sh_sha256=$src_split_sha
source_mmu_sh_sha256=$src_mmu_sha
source_phy_soc_in_sha256=$src_phy_sha
source_fixup_soc_in_sha256=$src_fixup_sha
source_rc_soc_sha256=$src_rc_sha
source_qsfp_led_soc_sha256=$src_qsfp_sha
source_startup_sha256=$src_startup_sha
generated_config_bcm_sha256=$gen_config_sha
generated_phy_soc_sha256=$gen_phy_sha
generated_fixup_soc_sha256=$gen_fixup_sha
generated_rc_soc_sha256=$gen_rc_sha
generated_qsfp_led_soc_sha256=$gen_qsfp_sha
generated_startup_sha256=$gen_startup_sha
generated_config_portmap_count=$portmap_count
generated_config_split_10g_portmap_count=$split_10g_count
generated_config_qsfp52_40g_portmap_count=$qsfp_40g_count
generated_phy_split_10g_port_count=$phy_10g_count
generated_phy_40g_port_count=$phy_40g_count
generated_has_pbmp_xport_xe=$has_pbmp
generated_has_l2xmsg_chunks=$has_l2xmsg
generated_has_phy_84848=$has_phy_84848
generated_has_active_fxe49=$has_fxe49
generated_has_active_fxe50=$has_fxe50
generated_has_active_fxe51=$has_fxe51
generated_has_unsplit_fxe52=$has_fxe52
EOF
}

make_temp_dir() {
    if command -v mktemp >/dev/null 2>&1; then
        mktemp -d "${TMPDIR:-/tmp}/redstone-original-active-sdk.XXXXXX"
    else
        tmp="${TMPDIR:-/tmp}/redstone-original-active-sdk.$$"
        mkdir -p "$tmp"
        printf '%s\n' "$tmp"
    fi
}

cmd=${1:-check}
case "$cmd" in
    check)
        check_sources
        require_file "$MANIFEST"
        tmp=$(make_temp_dir)
        trap 'rm -rf "$tmp"' EXIT INT TERM
        generate_files "$tmp/generated"
        write_manifest "$tmp/generated" > "$tmp/manifest"
        if diff -u "$MANIFEST" "$tmp/manifest"; then
            note "ok: original-active SDK reference manifest matches generated output"
        else
            die "original-active SDK reference manifest is stale"
        fi
        ;;
    generate)
        check_sources
        generate_files "$OUTDIR"
        write_manifest "$OUTDIR" > "$OUTDIR/redstone-original-active-sdk.manifest"
        note "generated: $OUTDIR"
        note "manifest: $OUTDIR/redstone-original-active-sdk.manifest"
        ;;
    manifest)
        check_sources
        tmp=$(make_temp_dir)
        trap 'rm -rf "$tmp"' EXIT INT TERM
        generate_files "$tmp/generated"
        write_manifest "$tmp/generated"
        ;;
    print-env)
        printf 'TOPDIR=%s\n' "$TOPDIR"
        printf 'ORIGINAL_ROOT=%s\n' "$ORIGINAL_ROOT"
        printf 'SOURCE_BCM_DIR=%s\n' "$SOURCE_BCM_DIR"
        printf 'SPLIT_CONFIG=%s\n' "$SPLIT_CONFIG"
        printf 'OUTDIR=%s\n' "$OUTDIR"
        printf 'MANIFEST=%s\n' "$MANIFEST"
        ;;
    clean)
        rm -rf "$OUTDIR"
        note "removed: $OUTDIR"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage >&2
        die "unknown command: $cmd"
        ;;
esac
