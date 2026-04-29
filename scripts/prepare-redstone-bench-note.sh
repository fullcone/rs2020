#!/bin/sh
# Create a per-run Redstone bench note outside the verified handoff package.
set -eu

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<'EOF'
Usage: prepare-redstone-bench-note.sh HANDOFF_DIR [RESULT_DIR]

Copies HANDOFF_DIR/bench-results/REDSTONE-BENCH-RESULT-TEMPLATE.md to a
timestamped stage-1 note in RESULT_DIR. RESULT_DIR defaults to
${REDSTONE_RESULT_DIR:-../redstone-bench-results}.

The helper refuses to write inside HANDOFF_DIR so MANIFEST.txt verification
continues to reject only real tampering, not operator-generated bench notes.
EOF
    exit 1
}

case "${1:-}" in
    -h|--help|help|"")
        usage
        ;;
esac

HANDOFF_DIR=$1
RESULT_DIR=${2:-${REDSTONE_RESULT_DIR:-../redstone-bench-results}}
TEMPLATE=$HANDOFF_DIR/bench-results/REDSTONE-BENCH-RESULT-TEMPLATE.md

[ -d "$HANDOFF_DIR" ] || fail "handoff directory missing: $HANDOFF_DIR"
[ -f "$TEMPLATE" ] || fail "bench result template missing: $TEMPLATE"

mkdir -p "$RESULT_DIR" || fail "failed to create result directory: $RESULT_DIR"

handoff_real=$(cd "$HANDOFF_DIR" && pwd -P) || fail "failed to resolve handoff directory: $HANDOFF_DIR"
result_real=$(cd "$RESULT_DIR" && pwd -P) || fail "failed to resolve result directory: $RESULT_DIR"

case "$result_real" in
    "$handoff_real"|"$handoff_real"/*)
        fail "refusing to write bench notes inside the manifest-verified handoff directory: $result_real"
        ;;
esac

stamp=$(date -u +%Y%m%dT%H%M%SZ)
note=$result_real/${stamp}-stage1.md

if [ -e "$note" ]; then
    fail "bench note already exists: $note"
fi

cp -p "$TEMPLATE" "$note"
echo "Bench result note: $note"
