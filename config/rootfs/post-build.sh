#!/bin/bash
# post-build.sh - Buildroot post-build script
# Called with $1 = target rootfs directory

TARGET_DIR="$1"
EDGENOS_BOARD="${EDGENOS_BOARD:-as5610-52x}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[ -f "$REPO_ROOT/scripts/board-env.sh" ] && . "$REPO_ROOT/scripts/board-env.sh"

# Set root password to 'as5610'
HASH='$6$52x8izoNf.9aB3Vd$azJoPieNNwYutepMslp9J.32/wB0pGCdd5lxeiz9J8jhoBdqwllvIvNIvyGYnCWfYuVZ4LBP9970NCzaymfsI/'
sed -i "s|^root:[^:]*:|root:${HASH}:|" "${TARGET_DIR}/etc/shadow"

# Ensure root account is not locked
sed -i 's|^root:!:|root:'"${HASH}"':|' "${TARGET_DIR}/etc/shadow"

# Allow root login via SSH (for initial setup)
if [ -f "${TARGET_DIR}/etc/ssh/sshd_config" ]; then
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' "${TARGET_DIR}/etc/ssh/sshd_config"
    # If not present, add it
    grep -q "^PermitRootLogin" "${TARGET_DIR}/etc/ssh/sshd_config" || \
        echo "PermitRootLogin yes" >> "${TARGET_DIR}/etc/ssh/sshd_config"
fi

# Enable BusyBox init script when present.
[ -f "${TARGET_DIR}/etc/init.d/S20edgenos" ] && \
    chmod 755 "${TARGET_DIR}/etc/init.d/S20edgenos"

# Enable systemd services only when the selected Buildroot init system provides
# systemd units. Redstone stage-1 uses BusyBox init because glibc is unavailable
# with the e500v2 SPE ABI.
SYSD="${TARGET_DIR}/etc/systemd/system"
if [ -d "${TARGET_DIR}/usr/lib/systemd/system" ]; then
    WANTS="${SYSD}/multi-user.target.wants"
    mkdir -p "$WANTS"

    # Enable sshd
    [ -f "${TARGET_DIR}/usr/lib/systemd/system/sshd.service" ] && \
        ln -sf /usr/lib/systemd/system/sshd.service "$WANTS/sshd.service" 2>/dev/null

    # Enable SSH keygen
    [ -f "${SYSD}/sshd-keygen.service" ] && \
        ln -sf /etc/systemd/system/sshd-keygen.service "$WANTS/sshd-keygen.service" 2>/dev/null

    # Enable systemd-networkd for DHCP
    ln -sf /usr/lib/systemd/system/systemd-networkd.service "$WANTS/systemd-networkd.service" 2>/dev/null
    ln -sf /usr/lib/systemd/system/systemd-resolved.service "$WANTS/systemd-resolved.service" 2>/dev/null

    # Enable platform-init and switchd
    [ -f "${SYSD}/platform-init.service" ] && \
        ln -sf /etc/systemd/system/platform-init.service "$WANTS/platform-init.service" 2>/dev/null
    [ -f "${SYSD}/switchd.service" ] && \
        ln -sf /etc/systemd/system/switchd.service "$WANTS/switchd.service" 2>/dev/null
    [ -f "${SYSD}/thermal-mgmt.service" ] && \
        ln -sf /etc/systemd/system/thermal-mgmt.service "$WANTS/thermal-mgmt.service" 2>/dev/null
fi

# Set hostname
echo "edgenos" > "${TARGET_DIR}/etc/hostname"

# Record board profile for runtime init scripts.
mkdir -p "${TARGET_DIR}/etc/edgenos"
printf '%s\n' "$EDGENOS_BOARD" > "${TARGET_DIR}/etc/edgenos/board"

# Windows checkouts can inject CRLF into overlay scripts and ifupdown config.
# BusyBox ifupdown treats a trailing carriage return as part of the method
# name, which turns "dhcp\r" into an unknown method on hardware.
for text_file in \
    "${TARGET_DIR}/etc/network/interfaces" \
    "${TARGET_DIR}/usr/sbin/platform-diag.sh" \
    "${TARGET_DIR}/usr/sbin/platform-init.sh" \
    "${TARGET_DIR}/usr/sbin/redstone-stage1-bench-run" \
    "${TARGET_DIR}/usr/sbin/redstone-stage1-capture" \
    "${TARGET_DIR}/usr/sbin/redstone-stage1-validate" \
    "${TARGET_DIR}/usr/sbin/redstone-mgmt-status" \
    "${TARGET_DIR}/usr/sbin/redstone-mgmt-web" \
    "${TARGET_DIR}/www/cgi-bin/redstone-status" \
    "${TARGET_DIR}/www/cgi-bin/redstone-action" \
    "${TARGET_DIR}/usr/sbin/switchd-init"
do
    [ -f "$text_file" ] && sed -i 's/\r$//' "$text_file"
done

# Redstone stage-1 is a serial-console bring-up image. Keep the management
# eTSEC ports manual so boot scripts do not trigger eth0/eth2 watchdog noise
# while we isolate the eth1 SGMII/TBI path.
if [ "$EDGENOS_BOARD" = "redstone" ]; then
    cat > "${TARGET_DIR}/etc/network/interfaces" <<'EOF'
# /etc/network/interfaces - Redstone stage-1 manual management links
#
# Do not auto-start eTSEC interfaces during hardware bring-up. Isolate eth1
# from the serial console and assign the test address manually.
EOF
fi

# Ensure /etc/fstab mounts devtmpfs on /dev. Without this, busybox init's
# `mount -a` does not populate /dev, so /dev/null and /dev/ttyS0 are missing
# until devices are created lazily, breaking getty respawn and stdio redirect.
FSTAB="${TARGET_DIR}/etc/fstab"
if [ -f "$FSTAB" ] && ! grep -qE '^[^#]*[[:space:]]/dev[[:space:]]+devtmpfs' "$FSTAB"; then
    printf 'devtmpfs\t/dev\t\tdevtmpfs\tdefaults\t0\t0\n' >> "$FSTAB"
fi

# sshd refuses to use a privsep dir that is not owned by root or is
# group/world-writable. Buildroot ships /var/empty as 0777; tighten it.
if [ -d "${TARGET_DIR}/var/empty" ]; then
    chmod 0755 "${TARGET_DIR}/var/empty"
    chown 0:0 "${TARGET_DIR}/var/empty" 2>/dev/null || true
fi

# Some stage-1 FITs are generated from a Windows-mounted workspace where cpio
# metadata can drift. Repair the OpenSSH privilege-separation directory at
# runtime too, immediately before sshd starts.
if [ -f "${TARGET_DIR}/etc/init.d/S50sshd" ] && \
    ! grep -q 'Redstone var-empty permission repair' "${TARGET_DIR}/etc/init.d/S50sshd"; then
    sed -i '/printf "Starting sshd:/i\
\t# Redstone var-empty permission repair for initramfs built from Windows workspaces.\
\t[ -d /var/empty ] && { chown 0:0 /var/empty 2>/dev/null || true; chmod 0755 /var/empty 2>/dev/null || true; }' \
        "${TARGET_DIR}/etc/init.d/S50sshd"
fi

# Keep loopback independent from ifupdown so stage-1 remains usable even when
# management interfaces are intentionally left manual.
cat > "${TARGET_DIR}/etc/init.d/S39loopback" <<'EOF'
#!/bin/sh
# Bring up loopback (busybox ifupdown can't do "loopback" method).
case "$1" in
    start)
        /sbin/ifconfig lo 127.0.0.1 netmask 255.0.0.0 up 2>/dev/null
        ;;
    stop)
        /sbin/ifconfig lo down 2>/dev/null
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
exit 0
EOF
chmod 0755 "${TARGET_DIR}/etc/init.d/S39loopback"

for script in \
    "${TARGET_DIR}/usr/sbin/redstone-mgmt-status" \
    "${TARGET_DIR}/usr/sbin/redstone-mgmt-web" \
    "${TARGET_DIR}/www/cgi-bin/redstone-status" \
    "${TARGET_DIR}/www/cgi-bin/redstone-action"
do
    [ -f "$script" ] && chmod 0755 "$script"
done

if [ -x "${REPO_ROOT}/scripts/install-openbcm-init-probe.sh" ]; then
    "${REPO_ROOT}/scripts/install-openbcm-init-probe.sh" "$TARGET_DIR"
fi
