#!/usr/bin/env bash
# PiMonitor Uninstaller
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash uninstall.sh"; exit 1; }

G='\033[0;32m' Y='\033[1;33m' B='\033[0;34m' Z='\033[0m'
ok()   { echo -e "${G}  ✓${Z} $*"; }
warn() { echo -e "${Y}  ⚠${Z} $*"; }
info() { echo -e "${B}  ▸${Z} $*"; }

echo ""
echo "  PiMonitor Uninstaller"
echo "  Your config in /etc/pimonitor/ will be preserved."
echo ""
read -r -p "  Continue? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { echo "  Aborted."; exit 0; }
echo ""

systemctl stop    pimonitor 2>/dev/null && ok "Service stopped"    || true
systemctl disable pimonitor 2>/dev/null && ok "Service disabled"   || true

[[ -f /etc/systemd/system/pimonitor.service ]] && {
    rm /etc/systemd/system/pimonitor.service
    systemctl daemon-reload
    ok "Service file removed"
}

[[ -L /usr/local/bin/pimonitor ]] && { rm /usr/local/bin/pimonitor; ok "Removed /usr/local/bin/pimonitor"; }
[[ -d /opt/pimonitor ]]           && { rm -rf /opt/pimonitor;       ok "Removed /opt/pimonitor"; }

echo ""
warn "Config preserved: /etc/pimonitor/"
info "To also remove config:  sudo rm -rf /etc/pimonitor"
echo ""
ok "PiMonitor uninstalled."
