#!/bin/sh
# Shared board metadata for build scripts.

: "${EDGENOS_BOARD:=as5610-52x}"

case "$EDGENOS_BOARD" in
    as5610-52x|accton-as5610-52x)
        EDGENOS_BOARD="as5610-52x"
        EDGENOS_BOARD_LABEL="AS5610-52X"
        EDGENOS_DTS_SOURCE="kernel/dts/as5610-52x.dts"
        EDGENOS_DTS_BASENAME="as5610-52x"
        EDGENOS_KERNEL_DEFCONFIG="config/kernel/as5610_defconfig"
        EDGENOS_IMAGE_NAME="edgenos-as5610-52x.bin"
        ;;
    redstone|rs2020|r0678)
        EDGENOS_BOARD="redstone"
        EDGENOS_BOARD_LABEL="Redstone"
        # Compatibility placeholder until a hardware-validated Redstone DTS exists.
        EDGENOS_DTS_SOURCE="kernel/dts/as5610-52x.dts"
        EDGENOS_DTS_BASENAME="redstone-stage1"
        EDGENOS_KERNEL_DEFCONFIG="config/kernel/as5610_defconfig"
        EDGENOS_IMAGE_NAME="edgenos-redstone-stage1.bin"
        ;;
    *)
        echo "ERROR: unsupported EDGENOS_BOARD=$EDGENOS_BOARD" >&2
        return 1 2>/dev/null || exit 1
        ;;
esac

# Keep the FIT config name compatible with the current installer and U-Boot path.
: "${EDGENOS_FIT_CONFIG:=accton_as5610_52x}"
: "${EDGENOS_FIT_DTB_NODE:=accton_as5610_52x_dtb}"
: "${EDGENOS_FIT_DESCRIPTION:=EdgeNOS for ${EDGENOS_BOARD_LABEL}}"

export EDGENOS_BOARD
export EDGENOS_BOARD_LABEL
export EDGENOS_DTS_SOURCE
export EDGENOS_DTS_BASENAME
export EDGENOS_KERNEL_DEFCONFIG
export EDGENOS_IMAGE_NAME
export EDGENOS_FIT_CONFIG
export EDGENOS_FIT_DTB_NODE
export EDGENOS_FIT_DESCRIPTION
