#!/usr/bin/env bash
# =============================================================================
# PiMonitor Installer
# =============================================================================
# Installs PiMonitor on Raspberry Pi OS Bookworm and compatible Debian/Ubuntu.
# Tested on Pi 4B and Pi 5. Should work on any modern Debian-based distro.
#
# Usage:
#   sudo bash install.sh
#   sudo bash install.sh --user myuser
#   sudo bash install.sh --no-enable
# =============================================================================
set -euo pipefail

# ─── defaults ────────────────────────────────────────────────────────────────
RUN_USER="${RUN_USER:-pi}"
INSTALL_DIR="/opt/pimonitor"
CONFIG_DIR="/etc/pimonitor"
ENABLE_SERVICE=true
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── colours ─────────────────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' B='\033[0;34m' W='\033[1m' Z='\033[0m'
info()   { echo -e "${B}  ▸${Z} $*"; }
ok()     { echo -e "${G}  ✓${Z} $*"; }
warn()   { echo -e "${Y}  ⚠${Z} $*"; }
err()    { echo -e "${R}  ✗${Z} $*" >&2; }
banner() { echo -e "\n${W}${B}━━━  $*  ━━━${Z}\n"; }

# ─── argument parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)      RUN_USER="$2"; shift 2 ;;
        --no-enable) ENABLE_SERVICE=false; shift ;;
        -h|--help)
            echo "Usage: sudo bash install.sh [--user USER] [--no-enable]"
            exit 0 ;;
        *) err "Unknown option: $1"; exit 1 ;;
    esac
done

# ─── root check ──────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || { err "Run as root:  sudo bash install.sh"; exit 1; }

# ─── user check ──────────────────────────────────────────────────────────────
if ! id -u "$RUN_USER" &>/dev/null; then
    err "User '$RUN_USER' does not exist."
    info "Create it first:  sudo useradd -m $RUN_USER"
    info "Or use:           sudo bash install.sh --user YOUR_USERNAME"
    exit 1
fi

# =============================================================================
echo ""
echo -e "${W}${B}╔══════════════════════════════════════╗"
echo -e "║         PiMonitor Installer          ║"
echo -e "╚══════════════════════════════════════╝${Z}"
echo ""
echo "  Install dir  :  $INSTALL_DIR"
echo "  Config dir   :  $CONFIG_DIR"
echo "  Run as user  :  $RUN_USER"
echo ""

# ─── OS detection ────────────────────────────────────────────────────────────
banner "System check"
OS_ID="unknown"
[[ -f /etc/os-release ]] && { source /etc/os-release; OS_ID="${ID:-unknown}"; }
case "$OS_ID" in
    raspbian|debian|ubuntu) ok "OS: ${PRETTY_NAME:-$OS_ID}" ;;
    *) warn "Untested OS: ${PRETTY_NAME:-$OS_ID} — proceeding anyway" ;;
esac
info "Architecture: $(uname -m)"
info "Kernel: $(uname -r)"

# ─── check Pi model and GPU memory ──────────────────────────────────────────
if [[ -f /sys/firmware/devicetree/base/model ]]; then
    MODEL=$(tr -d '\0' < /sys/firmware/devicetree/base/model)
    info "Hardware: $MODEL"
    if echo "$MODEL" | grep -qi "raspberry pi 4\|raspberry pi 3"; then
        GPU_MEM=$(vcgencmd get_mem gpu 2>/dev/null | grep -oP '\d+' || echo "?")
        if [[ "$GPU_MEM" != "?" ]] && [[ "$GPU_MEM" -lt 128 ]]; then
            warn "GPU memory is ${GPU_MEM}MB — recommend gpu_mem=128 in /boot/firmware/config.txt"
        else
            ok "GPU memory: ${GPU_MEM}MB"
        fi
    fi
fi

# ─── install packages ────────────────────────────────────────────────────────
banner "Installing packages"

apt-get update -qq

PKGS=(
    mpv                    # the video player
    xserver-xorg-core      # minimal X server (no desktop)
    xinit                  # startx helper
    x11-utils              # xdpyinfo
    x11-xserver-utils      # xrandr, xsetroot, xset
)

info "Installing: ${PKGS[*]}"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    "${PKGS[@]}" 2>&1 | grep -E '(Setting up|already|E:)' | sed 's/^/    /' || true
ok "Packages installed"

# ─── configure X11 rootless ─────────────────────────────────────────────────
banner "Configuring X11"

XWRAP="/etc/X11/Xwrapper.config"
if ! grep -q "allowed_users = anybody" "$XWRAP" 2>/dev/null; then
    cat > "$XWRAP" << 'EOF'
allowed_users = anybody
needs_root_rights = no
EOF
    ok "Configured Xwrapper.config (rootless X11)"
else
    ok "Xwrapper.config already set"
fi

for grp in video input render; do
    if getent group "$grp" &>/dev/null; then
        usermod -aG "$grp" "$RUN_USER" 2>/dev/null && \
            info "Added $RUN_USER → group '$grp'" || true
    fi
done

# ─── install application files ───────────────────────────────────────────────
banner "Installing PiMonitor"

install -d -m 755 "$INSTALL_DIR"
install -m 755 "$SCRIPT_DIR/pimonitor"            "$INSTALL_DIR/pimonitor"
install -m 644 "$SCRIPT_DIR/pimonitor.conf.example" "$INSTALL_DIR/pimonitor.conf.example"

# Symlink to /usr/local/bin so it's on PATH
ln -sf "$INSTALL_DIR/pimonitor" /usr/local/bin/pimonitor

# xinitrc — bare X session that immediately runs the daemon
cat > "$INSTALL_DIR/xinitrc" << 'XINITRC'
#!/usr/bin/env bash
# Minimal X init for PiMonitor — no desktop, no window manager
xsetroot -solid black 2>/dev/null || true
exec /usr/local/bin/pimonitor
XINITRC
chmod 755 "$INSTALL_DIR/xinitrc"

ok "Installed to $INSTALL_DIR"
ok "Symlinked: /usr/local/bin/pimonitor"

# ─── config ─────────────────────────────────────────────────────────────────
banner "Configuration"

install -d -m 755 "$CONFIG_DIR"
CONFIG="$CONFIG_DIR/pimonitor.conf"

if [[ ! -f "$CONFIG" ]]; then
    install -m 644 "$SCRIPT_DIR/pimonitor.conf.example" "$CONFIG"
    ok "Config installed: $CONFIG"
    echo ""
    warn "┌─────────────────────────────────────────────────────┐"
    warn "│  IMPORTANT: Edit your config before starting!       │"
    warn "│  sudo nano $CONFIG"
    warn "│  Add your RTSP camera URLs in the CAMERAS section.  │"
    warn "└─────────────────────────────────────────────────────┘"
    echo ""
else
    ok "Config already exists, not overwriting: $CONFIG"
    # Always update the example
    install -m 644 "$SCRIPT_DIR/pimonitor.conf.example" "$CONFIG_DIR/pimonitor.conf.example"
    info "Updated example: $CONFIG_DIR/pimonitor.conf.example"
fi

chown -R "$RUN_USER:$RUN_USER" "$CONFIG_DIR" 2>/dev/null || true

# ─── systemd service ────────────────────────────────────────────────────────
banner "Systemd service"

sed \
    -e "s|__RUN_USER__|$RUN_USER|g" \
    -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
    -e "s|__CONFIG_DIR__|$CONFIG_DIR|g" \
    "$SCRIPT_DIR/systemd/pimonitor.service" \
    > /etc/systemd/system/pimonitor.service

chmod 644 /etc/systemd/system/pimonitor.service
systemctl daemon-reload
ok "Service file installed"

if [[ "$ENABLE_SERVICE" == "true" ]]; then
    systemctl enable pimonitor.service
    ok "Service enabled (autostart on boot)"
fi

# =============================================================================
banner "Done!"
echo -e "  ${W}Next steps:${Z}"
echo ""
echo -e "  1. Edit your cameras:"
echo -e "     ${Y}sudo nano $CONFIG${Z}"
echo ""
echo -e "  2. Start PiMonitor:"
echo -e "     ${Y}sudo systemctl start pimonitor${Z}"
echo ""
echo -e "  3. Watch the logs:"
echo -e "     ${Y}sudo journalctl -u pimonitor -f${Z}"
echo ""
echo -e "  4. Reboot for autostart:"
echo -e "     ${Y}sudo reboot${Z}"
echo ""
