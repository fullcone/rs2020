#!/bin/sh
# analyze-redstone-handoff-capture.sh - Verify a Redstone handoff and capture.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<EOF
Usage: $0 HANDOFF_PATH CAPTURE_PATH

Arguments:
  HANDOFF_PATH   Redstone handoff directory or redstone-stage1-hardware-handoff.tar.gz
  CAPTURE_PATH   Redstone validation directory or capture tarball from hardware
EOF
    exit 1
}

require_file() {
    [ -f "$1" ] || fail "missing required file: $1"
}

check_handoff_path() {
    handoff_path=$1

    if [ -d "$handoff_path" ]; then
        return 0
    fi

    case "$handoff_path" in
        *.tar.gz|*.tgz)
            [ -f "$handoff_path" ] || fail "handoff tarball not found: $handoff_path"
            ;;
        *)
            fail "handoff path must be a directory, .tar.gz, or .tgz: $handoff_path"
            ;;
    esac
}

[ "${1:-}" != "-h" ] || usage
[ "${1:-}" != "--help" ] || usage
[ "$#" -eq 2 ] || usage

HANDOFF_PATH=$1
CAPTURE_PATH=$2

[ -e "$CAPTURE_PATH" ] || fail "capture path not found: $CAPTURE_PATH"

check_handoff_path "$HANDOFF_PATH"

VERIFY_TOOL="$SCRIPT_DIR/verify-redstone-hardware-handoff.sh"
ANALYZE_TOOL="$SCRIPT_DIR/analyze-redstone-stage1-evidence.sh"

require_file "$VERIFY_TOOL"
require_file "$ANALYZE_TOOL"

echo "==> Verifying Redstone hardware handoff package"
sh "$VERIFY_TOOL" "$HANDOFF_PATH"

echo "==> Analyzing Redstone strict capture evidence"
sh "$ANALYZE_TOOL" --strict "$CAPTURE_PATH"

echo "PASS: Redstone handoff package and capture evidence passed host analysis"
