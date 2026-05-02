#!/bin/bash
# Build minimal initramfs for open-nos-as5610 (PPC32).
# Uses nos-init.c (static C init) instead of a shell script.
# Produces: initramfs.cpio.gz
#
# Requires: powerpc-linux-gnu-gcc (or Docker) to compile nos-init.c

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${SCRIPT_DIR}/initramfs.cpio.gz"
ROOT="${SCRIPT_DIR}/root"

rm -rf "$ROOT"
mkdir -p "$ROOT"/{bin,sbin,dev,proc,sys,newroot}

# Compile static C init (nos-init.c -> /init in initramfs)
INIT_SRC="${SCRIPT_DIR}/nos-init.c"
if [ ! -f "$INIT_SRC" ]; then
	INIT_SRC="${SCRIPT_DIR}/initramfs/nos-init.c"
fi
INIT_BIN="${ROOT}/init"
INIT_CFLAGS="-static -nostdlib -nostartfiles -nodefaultlibs -ffreestanding -fno-stack-protector -Os -Wall -Wno-unused-function"
INIT_LDFLAGS="-Wl,-e,_start"
INIT_LIBS="-lgcc"

if [ -f "$INIT_SRC" ]; then
	if command -v powerpc-linux-gnu-gcc &>/dev/null; then
		echo "Compiling nos-init.c with powerpc-linux-gnu-gcc (freestanding)..."
		powerpc-linux-gnu-gcc $INIT_CFLAGS $INIT_LDFLAGS -o "$INIT_BIN" "$INIT_SRC" $INIT_LIBS
		chmod +x "$INIT_BIN"
	elif command -v docker &>/dev/null; then
		echo "Compiling nos-init.c via Docker (debian:bookworm)..."
		INIT_SRC_REL="${INIT_SRC#"$SCRIPT_DIR"/}"
		INIT_BIN_REL="${INIT_BIN#"$SCRIPT_DIR"/}"
		docker run --rm \
			-v "$SCRIPT_DIR:/work" -w /work \
			-e DEBIAN_FRONTEND=noninteractive \
			-e INIT_SRC_REL="$INIT_SRC_REL" \
			-e INIT_BIN_REL="$INIT_BIN_REL" \
			debian:bookworm bash -c \
			'apt-get update -qq && apt-get install -y -qq gcc-powerpc-linux-gnu >/dev/null 2>&1 && powerpc-linux-gnu-gcc -static -nostdlib -nostartfiles -nodefaultlibs -ffreestanding -fno-stack-protector -Os -Wall -Wno-unused-function -Wl,-e,_start -o "$INIT_BIN_REL" "$INIT_SRC_REL" -lgcc && chmod +x "$INIT_BIN_REL"'
	else
		echo "ERROR: need powerpc-linux-gnu-gcc or Docker to compile nos-init.c"
		exit 1
	fi
else
	echo "ERROR: nos-init.c not found at $INIT_SRC"
	exit 1
fi

( cd "$ROOT" && find . | cpio -o -H newc ) | gzip -9 > "$OUT"
echo "Built: $OUT ($(du -sh "$OUT" | cut -f1))"
