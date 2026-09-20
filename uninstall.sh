#!/usr/bin/env bash
# =============================================================================
# PiMonitor uninstaller
# =============================================================================
#   sudo bash uninstall.sh            remove PiMonitor, keep your config
#   sudo bash uninstall.sh --purge    remove everything including the config
# =============================================================================
set -euo pipefail

PURGE=false
[[ "${1:-}" == "--purge" ]] && PURGE=true

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash uninstall.sh"; exit 1; }

echo "Stopping services..."
systemctl stop pimonitor.service pimonitor-splash.service 2>/dev/null || true
systemctl disable pimonitor.service pimonitor-splash.service 2>/dev/null || true

echo "Removing units..."
rm -f /etc/systemd/system/pimonitor.service
rm -f /etc/systemd/system/pimonitor-splash.service
rm -rf /etc/systemd/system/pimonitor.service.d
systemctl daemon-reload

echo "Removing program files..."
rm -rf /opt/pimonitor
rm -f /usr/local/bin/pimonitor /usr/local/bin/pimonitor-discover
rm -rf /run/pimonitor

echo "Reverting kiosk hardening..."
systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
rm -f /etc/systemd/logind.conf.d/10-pimonitor-no-sleep.conf
rm -f /etc/NetworkManager/conf.d/10-pimonitor-no-powersave.conf
rm -f /etc/systemd/journald.conf.d/10-pimonitor-persist.conf

# Restore the boot files if we changed them
for d in /boot/firmware /boot; do
    if [[ -f "$d/cmdline.txt.pimonitor.bak" ]]; then
        mv "$d/cmdline.txt.pimonitor.bak" "$d/cmdline.txt"
        echo "Restored $d/cmdline.txt"
    fi
    if [[ -f "$d/config.txt.pimonitor.bak" ]]; then
        mv "$d/config.txt.pimonitor.bak" "$d/config.txt"
        echo "Restored $d/config.txt"
    fi
done

if [[ "$PURGE" == true ]]; then
    rm -rf /etc/pimonitor
    echo "Removed /etc/pimonitor (config deleted)"
else
    echo "Kept /etc/pimonitor (use --purge to delete it)"
fi

echo ""
echo "PiMonitor removed. Reboot to fully restore the normal boot screen."
