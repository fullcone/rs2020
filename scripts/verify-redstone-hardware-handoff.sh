#!/bin/sh
# Verify a Redstone stage-1 hardware handoff directory or tarball.

set -u

INPUT=
WORKDIR=
ROOT=
PASSES=0
WARNINGS=0
FAILURES=0

usage() {
    cat <<'EOF'
Usage: verify-redstone-hardware-handoff.sh PATH

PATH may be:
  - output/redstone-handoff
  - output/redstone-stage1-hardware-handoff.tar.gz

The verifier checks the handoff manifest, required bench files, file sizes, and
SHA-256 hashes before the package is copied to or used on the Redstone bench.
EOF
}

cleanup() {
    if [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ]; then
        rm -rf "$WORKDIR"
    fi
}
trap cleanup EXIT INT TERM

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
}

need_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    fi
    fail "$1 is required"
    return 1
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        fail "sha256sum or shasum is required"
        printf 'missing'
    fi
}

file_size() {
    wc -c < "$1" | tr -d ' '
}

manifest_value() {
    key=$1
    grep -E "^$key=" "$ROOT/MANIFEST.txt" 2>/dev/null |
        sed -n "1s/^$key=//p"
}

require_file() {
    rel=$1
    if [ -f "$ROOT/$rel" ]; then
        pass "required file exists: $rel"
    else
        fail "required file missing: $rel"
    fi
}

extract_if_needed() {
    work_parent=${TMPDIR:-/tmp}
    WORKDIR=$(mktemp -d "$work_parent/redstone-handoff-verify.XXXXXX") || exit 1

    case "$INPUT" in
    *.tar.gz|*.tgz)
        if ! need_cmd tar; then
            return
        fi
        if tar -xzf "$INPUT" -C "$WORKDIR"; then
            pass "extracted handoff tarball"
        else
            fail "failed to extract handoff tarball: $INPUT"
            return
        fi
        child_count=$(find "$WORKDIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
        if [ "$child_count" = "1" ]; then
            ROOT=$(find "$WORKDIR" -mindepth 1 -maxdepth 1 -type d -print | head -n 1)
        else
            ROOT=$WORKDIR
        fi
        ;;
    *)
        if [ -d "$INPUT" ]; then
            ROOT=$INPUT
        else
            fail "handoff path is not a directory or .tar.gz/.tgz file: $INPUT"
        fi
        ;;
    esac
}

check_manifest_header() {
    board=$(manifest_value board)
    image_name=$(manifest_value image_name)
    dtb_name=$(manifest_value dtb_name)
    git_head=$(manifest_value git_head)
    generated_utc=$(manifest_value generated_utc)

    if [ "$board" = "redstone" ]; then
        pass "manifest board is redstone"
    else
        fail "manifest board is ${board:-missing}, expected redstone"
    fi

    if [ "$image_name" = "edgenos-redstone-stage1.bin" ]; then
        pass "manifest image name is Redstone stage-1"
    else
        fail "manifest image_name is ${image_name:-missing}, expected edgenos-redstone-stage1.bin"
    fi

    if [ "$dtb_name" = "redstone-stage1.dtb" ]; then
        pass "manifest DTB name is redstone-stage1.dtb"
    else
        fail "manifest dtb_name is ${dtb_name:-missing}, expected redstone-stage1.dtb"
    fi

    if [ -n "$git_head" ]; then
        pass "manifest records git head: $git_head"
    else
        warn "manifest git head is missing"
    fi

    if [ -n "$generated_utc" ]; then
        pass "manifest records generated UTC: $generated_utc"
    else
        warn "manifest generated UTC is missing"
    fi
}

check_required_files() {
    image_name=$(manifest_value image_name)
    dtb_name=$(manifest_value dtb_name)

    require_file RUNBOOK.md
    require_file MANIFEST.txt
    if [ -n "$image_name" ]; then
        require_file "images/$image_name"
    fi
    require_file images/rootfs.sqsh
    if [ -n "$dtb_name" ]; then
        require_file "images/$dtb_name"
    fi
    require_file openbcm-bde/linux-kernel-bde.ko
    require_file openbcm-bde/linux-user-bde.ko
    require_file openbcm-bde/redstone-openbcm-bde-smoke.sh
    require_file openbcm-bde/redstone-openbcm-bde.manifest
    require_file openbcm-init/redstone-openbcm-init-probe
    require_file openbcm-init/redstone-openbcm-init-probe.manifest
    require_file host-tools/analyze-redstone-stage1-evidence.sh
    require_file host-tools/analyze-redstone-handoff-capture.sh
    require_file host-tools/analyze-redstone-platform-inventory.sh
    require_file host-tools/verify-redstone-hardware-handoff.sh
    require_file host-tools/prepare-redstone-bench-note.sh
    require_file bench-results/REDSTONE-BENCH-RESULT-TEMPLATE.md
}

check_manifest_entries() {
    manifest=$ROOT/MANIFEST.txt
    manifest_entries=$WORKDIR/manifest-entries.txt
    actual_entries=$WORKDIR/actual-entries.txt
    in_files=0
    entry_count=0

    : > "$manifest_entries"

    if ! need_cmd awk || ! need_cmd sort || ! need_cmd comm; then
        return
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
        files:)
            in_files=1
            continue
            ;;
        esac

        [ "$in_files" = "1" ] || continue
        [ -n "$line" ] || continue

        case "$line" in
        *"  bytes="*"  sha256="*)
            rel=${line%%  bytes=*}
            rest=${line#*  bytes=}
            expected_size=${rest%%  sha256=*}
            expected_sha=${rest##*  sha256=}
            entry_count=$((entry_count + 1))
            printf '%s\n' "$rel" >> "$manifest_entries"

            if [ ! -f "$ROOT/$rel" ]; then
                fail "manifest entry missing from package: $rel"
                continue
            fi

            actual_size=$(file_size "$ROOT/$rel")
            if [ "$actual_size" = "$expected_size" ]; then
                pass "size matches: $rel"
            else
                fail "size mismatch for $rel: got $actual_size expected $expected_size"
            fi

            actual_sha=$(sha256_file "$ROOT/$rel")
            if [ "$actual_sha" = "$expected_sha" ]; then
                pass "sha256 matches: $rel"
            else
                fail "sha256 mismatch for $rel: got $actual_sha expected $expected_sha"
            fi
            ;;
        *)
            fail "malformed manifest file entry: $line"
            ;;
        esac
    done < "$manifest"

    if [ "$entry_count" -gt 0 ]; then
        pass "manifest has $entry_count file entries"
    else
        fail "manifest has no file entries"
    fi

    (cd "$ROOT" && find . -type f ! -name MANIFEST.txt | sed 's#^\./##' | sort) > "$actual_entries"
    sort "$manifest_entries" > "$manifest_entries.sorted"
    mv "$manifest_entries.sorted" "$manifest_entries"

    if extra=$(comm -23 "$actual_entries" "$manifest_entries" | head -n 1) && [ -n "$extra" ]; then
        fail "package contains file not listed in manifest: $extra"
    else
        pass "manifest lists every package file"
    fi

    if missing=$(comm -13 "$actual_entries" "$manifest_entries" | head -n 1) && [ -n "$missing" ]; then
        fail "manifest lists file not present in package: $missing"
    else
        pass "every manifest file is present"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
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

extract_if_needed

printf 'Redstone hardware handoff verification\n'
printf '  input: %s\n' "$INPUT"
printf '  root: %s\n\n' "${ROOT:-missing}"

if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
    fail "handoff root is unavailable"
else
    if [ -f "$ROOT/MANIFEST.txt" ]; then
        pass "manifest found"
        check_manifest_header
        check_required_files
        check_manifest_entries
    else
        fail "MANIFEST.txt missing"
    fi
fi

printf '\nRedstone hardware handoff verification summary: %s pass, %s warning(s), %s failure(s)\n' \
    "$PASSES" "$WARNINGS" "$FAILURES"

if [ "$FAILURES" -ne 0 ]; then
    exit 1
fi

exit 0
