#!/bin/bash
set -euo pipefail

RKNPU_VERSION="1.0"
DMA32_VERSION="1.0"
ENVFILE="/boot/armbianEnv.txt"
ENVBACKUP="${ENVFILE}.pre-npu"
RKNPU_DTB="/boot/dtb/rockchip/rk3568-odroid-m1-npu.dtb"
RKNPU_OVERLAY="/boot/overlay-user/rknpu.dtbo"

restore_key_from_backup() {
    local key="$1"
    local file="$2"
    local backup="$3"
    local backup_line

    backup_line="$(grep "^${key}=" "$backup" 2>/dev/null || true)"

    if grep -q "^${key}=" "$file" 2>/dev/null; then
        if [ -n "$backup_line" ]; then
            sed -i "s|^${key}=.*|${backup_line}|" "$file"
        else
            sed -i "/^${key}=/d" "$file"
        fi
    elif [ -n "$backup_line" ]; then
        printf '%s\n' "$backup_line" >> "$file"
    fi
}

remove_rknpu_from_user_overlays() {
    local file="$1"
    local tmp

    tmp="$(mktemp)"
    awk '
        /^user_overlays=/ {
            line = substr($0, length("user_overlays=") + 1)
            n = split(line, a, /[[:space:]]+/)
            out = ""
            for (i = 1; i <= n; i++) {
                if (a[i] != "" && a[i] != "rknpu") {
                    out = out (out ? " " : "") a[i]
                }
            }
            if (out != "")
                print "user_overlays=" out
            next
        }
        { print }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

echo "=== Rockchip RKNPU DKMS Uninstaller ==="
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run as root (sudo $0)"
    exit 1
fi

echo "[1/8] Unloading modules if present..."
modprobe -r rknpu 2>/dev/null || true
modprobe -r dma32_heap 2>/dev/null || true
echo "  Done."

echo "[2/8] Removing DKMS modules..."
if command -v dkms >/dev/null 2>&1; then
    dkms remove -m rknpu -v "$RKNPU_VERSION" --all 2>/dev/null || true
    dkms remove -m dma32-heap -v "$DMA32_VERSION" --all 2>/dev/null || true
fi
rm -rf "/usr/src/rknpu-${RKNPU_VERSION}"
rm -rf "/usr/src/dma32-heap-${DMA32_VERSION}"
echo "  DKMS state removed."

echo "[3/8] Removing boot artifacts..."
rm -f "$RKNPU_DTB"
rm -f "$RKNPU_OVERLAY"
echo "  Boot artifacts removed."

echo "[4/8] Removing module autoload config..."
rm -f /etc/modules-load.d/rknpu.conf
rm -f /etc/modules-load.d/dma32-heap.conf
rm -f /etc/modules-load.d/devfreq-governors.conf
echo "  Module autoload config removed."

echo "[5/8] Removing udev rules..."
rm -f /etc/udev/rules.d/99-dma-heap-dma32.rules
if [ -L /dev/dma_heap/system ] && [ "$(readlink /dev/dma_heap/system)" = "/dev/dma_heap/dma32" ]; then
    rm -f /dev/dma_heap/system
fi
if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules || true
    udevadm trigger --subsystem-match=dma_heap || true
fi
echo "  Udev cleanup complete."

echo "[6/8] Restoring boot configuration..."
if [ -f "$ENVFILE" ]; then
    if [ -f "$ENVBACKUP" ]; then
        restore_key_from_backup "fdtfile" "$ENVFILE" "$ENVBACKUP"
        restore_key_from_backup "user_overlays" "$ENVFILE" "$ENVBACKUP"
        echo "  Restored fdtfile and user_overlays from ${ENVBACKUP}."
    else
        sed -i '\|^fdtfile=rockchip/rk3568-odroid-m1-npu.dtb$|d' "$ENVFILE"
        remove_rknpu_from_user_overlays "$ENVFILE"
        echo "  Removed rknpu boot settings without backup."
    fi
else
    echo "  Skipped: ${ENVFILE} not found."
fi

echo "[7/8] Refreshing module dependencies..."
if command -v depmod >/dev/null 2>&1; then
    depmod -a || true
fi
echo "  Done."

echo "[8/8] Final state..."
echo "  Project files in the repository were not removed."
echo "  A reboot is required to fully unload DT/boot changes."
echo ""
echo "=== Uninstall complete. Reboot recommended. ==="
