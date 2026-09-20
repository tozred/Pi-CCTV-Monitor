#!/usr/bin/env bash
# =============================================================================
# PiMonitor installer
# =============================================================================
# Installs PiMonitor on Raspberry Pi OS / Debian / Ubuntu.
#
#   sudo bash install.sh                        install + enable on boot
#   sudo bash install.sh --harden               also apply kiosk hardening
#   sudo bash install.sh --splash logo.png      also set a branded boot splash
#   sudo bash install.sh --all                  everything (recommended for kiosks)
#   sudo bash install.sh --user pi --no-enable
#
# Safe to re-run. Your existing pimonitor.conf is never overwritten.
# =============================================================================
set -euo pipefail

VERSION="2.0"

# --- defaults --------------------------------------------------------------
RUN_USER="${RUN_USER:-$(id -nu 1000 2>/dev/null || echo pi)}"
INSTALL_DIR="/opt/pimonitor"
CONFIG_DIR="/etc/pimonitor"
ENABLE_SERVICE=true
DO_HARDEN=false
SPLASH_IMAGE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' B='\033[0;34m' W='\033[1m' Z='\033[0m'
info()   { echo -e "${B}  >${Z} $*"; }
ok()     { echo -e "${G}  +${Z} $*"; }
warn()   { echo -e "${Y}  !${Z} $*"; }
err()    { echo -e "${R}  x${Z} $*" >&2; }
banner() { echo -e "\n${W}${B}--- $* ---${Z}\n"; }

usage() {
    cat <<EOF
PiMonitor installer v$VERSION

USAGE
  sudo bash install.sh [options]

OPTIONS
  --user USER        run the display as this user (default: $RUN_USER)
  --harden           kiosk hardening: never sleep, never blank the screen,
                     no wifi power saving, persistent logs
  --splash IMAGE     show IMAGE during boot instead of kernel text,
                     and silence the boot output
  --all              --harden --splash (uses assets/splash-example.png
                     unless you also pass --splash with your own image)
  --no-enable        do not enable autostart on boot
  -h, --help         this help

AFTER INSTALLING
  1. Find your cameras:  pimonitor-discover --scan 192.168.1.0/24 -u admin -p pass --config
  2. Edit the config:    sudo nano $CONFIG_DIR/pimonitor.conf
  3. Start it:           sudo systemctl start pimonitor
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)      RUN_USER="$2"; shift 2 ;;
        --no-enable) ENABLE_SERVICE=false; shift ;;
        --harden)    DO_HARDEN=true; shift ;;
        --splash)    SPLASH_IMAGE="$2"; shift 2 ;;
        --all)       DO_HARDEN=true; [[ -z "$SPLASH_IMAGE" ]] && SPLASH_IMAGE="__default__"; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           err "Unknown option: $1"; usage; exit 1 ;;
    esac
done

[[ $EUID -eq 0 ]] || { err "Run as root:  sudo bash install.sh"; exit 1; }

if ! id -u "$RUN_USER" &>/dev/null; then
    err "User '$RUN_USER' does not exist."
    info "Create it:  sudo useradd -m $RUN_USER"
    info "Or pick another:  sudo bash install.sh --user YOUR_USER"
    exit 1
fi

if [[ "$SPLASH_IMAGE" == "__default__" ]]; then
    SPLASH_IMAGE="$SCRIPT_DIR/assets/splash-example.png"
fi
if [[ -n "$SPLASH_IMAGE" && ! -f "$SPLASH_IMAGE" ]]; then
    err "Splash image not found: $SPLASH_IMAGE"; exit 1
fi

echo ""
echo -e "${W}${B}PiMonitor installer v$VERSION${Z}"
echo ""
echo "  Install dir :  $INSTALL_DIR"
echo "  Config dir  :  $CONFIG_DIR"
echo "  Run as user :  $RUN_USER"
echo "  Hardening   :  $DO_HARDEN"
echo "  Boot splash :  ${SPLASH_IMAGE:-no}"
echo ""

# ---------------------------------------------------------------------------
banner "System check"
OS_ID="unknown"
[[ -f /etc/os-release ]] && { . /etc/os-release; OS_ID="${ID:-unknown}"; }
case "$OS_ID" in
    raspbian|debian|ubuntu) ok "OS: ${PRETTY_NAME:-$OS_ID}" ;;
    *) warn "Untested OS: ${PRETTY_NAME:-$OS_ID}, continuing" ;;
esac
info "Architecture: $(uname -m)"
info "Kernel: $(uname -r)"
IS_PI=false
if [[ -f /sys/firmware/devicetree/base/model ]]; then
    MODEL=$(tr -d '\0' < /sys/firmware/devicetree/base/model)
    info "Hardware: $MODEL"
    grep -qi "raspberry pi" <<<"$MODEL" && IS_PI=true
fi

# ---------------------------------------------------------------------------
banner "Packages"
PKGS=(mpv xserver-xorg-core xserver-xorg xinit x11-utils x11-xserver-utils)
[[ -n "$SPLASH_IMAGE" ]] && PKGS+=(fbi)
# ffmpeg gives pimonitor-discover a fast, reliable stream prober
command -v ffprobe >/dev/null || PKGS+=(ffmpeg)

info "Installing: ${PKGS[*]}"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PKGS[@]}" \
    2>&1 | grep -E '(Setting up|E:)' | sed 's/^/    /' || true
ok "Packages installed"

# ---------------------------------------------------------------------------
banner "X11"
XWRAP="/etc/X11/Xwrapper.config"
if ! grep -q "allowed_users *= *anybody" "$XWRAP" 2>/dev/null; then
    printf 'allowed_users = anybody\nneeds_root_rights = no\n' > "$XWRAP"
    ok "Configured $XWRAP (X without root)"
else
    ok "$XWRAP already configured"
fi
for grp in video input render tty; do
    getent group "$grp" &>/dev/null && usermod -aG "$grp" "$RUN_USER" 2>/dev/null || true
done
ok "User '$RUN_USER' added to video/input/render/tty"

# ---------------------------------------------------------------------------
banner "PiMonitor"
install -d -m 755 "$INSTALL_DIR"
install -m 755 "$SCRIPT_DIR/pimonitor"           "$INSTALL_DIR/pimonitor"
install -m 755 "$SCRIPT_DIR/pimonitor-discover"  "$INSTALL_DIR/pimonitor-discover"
install -m 644 "$SCRIPT_DIR/pimonitor.conf.example" "$INSTALL_DIR/pimonitor.conf.example"
ln -sf "$INSTALL_DIR/pimonitor"          /usr/local/bin/pimonitor
ln -sf "$INSTALL_DIR/pimonitor-discover" /usr/local/bin/pimonitor-discover

cat > "$INSTALL_DIR/xinitrc" <<'XINITRC'
#!/usr/bin/env bash
# Minimal X session for PiMonitor: no desktop, no window manager.
xsetroot -solid black 2>/dev/null || true
exec /usr/local/bin/pimonitor
XINITRC
chmod 755 "$INSTALL_DIR/xinitrc"
ok "Installed to $INSTALL_DIR"
ok "Commands: pimonitor, pimonitor-discover"

# ---------------------------------------------------------------------------
banner "Configuration"
install -d -m 755 "$CONFIG_DIR"
CONFIG="$CONFIG_DIR/pimonitor.conf"
install -m 644 "$SCRIPT_DIR/pimonitor.conf.example" "$CONFIG_DIR/pimonitor.conf.example"
if [[ ! -f "$CONFIG" ]]; then
    install -m 600 "$SCRIPT_DIR/pimonitor.conf.example" "$CONFIG"
    ok "Config created: $CONFIG"
    NEW_CONFIG=true
else
    ok "Existing config kept: $CONFIG"
    NEW_CONFIG=false
fi
# The config holds camera passwords.
chown -R "$RUN_USER:$RUN_USER" "$CONFIG_DIR" 2>/dev/null || true
chmod 600 "$CONFIG" 2>/dev/null || true
ok "Config is readable only by '$RUN_USER' (it contains camera passwords)"

# ---------------------------------------------------------------------------
banner "Service"
sed -e "s|__RUN_USER__|$RUN_USER|g" \
    -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
    -e "s|__CONFIG_DIR__|$CONFIG_DIR|g" \
    "$SCRIPT_DIR/systemd/pimonitor.service" > /etc/systemd/system/pimonitor.service
chmod 644 /etc/systemd/system/pimonitor.service
systemctl daemon-reload
ok "Installed pimonitor.service"

if [[ "$ENABLE_SERVICE" == true ]]; then
    systemctl enable pimonitor.service >/dev/null 2>&1
    ok "Autostart on boot enabled"
fi
if systemctl list-unit-files NetworkManager-wait-online.service &>/dev/null; then
    systemctl enable NetworkManager-wait-online.service >/dev/null 2>&1 || true
    ok "Streams will wait for the network at boot"
elif systemctl list-unit-files systemd-networkd-wait-online.service &>/dev/null; then
    systemctl enable systemd-networkd-wait-online.service >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
if [[ "$DO_HARDEN" == true ]]; then
    banner "Kiosk hardening"

    systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 || true
    ok "Sleep, suspend and hibernate disabled"

    install -d -m 755 /etc/systemd/logind.conf.d
    cat > /etc/systemd/logind.conf.d/10-pimonitor-no-sleep.conf <<'EOF'
[Login]
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
EOF
    systemctl restart systemd-logind 2>/dev/null || true
    ok "Power keys and idle timeouts ignored"

    if [[ -d /etc/NetworkManager ]]; then
        install -d -m 755 /etc/NetworkManager/conf.d
        printf '[connection]\nwifi.powersave = 2\n' > /etc/NetworkManager/conf.d/10-pimonitor-no-powersave.conf
        ok "Wifi power saving disabled (it causes stream stalls)"
    fi

    install -d -m 755 /etc/systemd/journald.conf.d /var/log/journal
    printf '[Journal]\nStorage=persistent\n' > /etc/systemd/journald.conf.d/10-pimonitor-persist.conf
    systemctl restart systemd-journald 2>/dev/null || true
    ok "Logs survive reboots (so crashes can be diagnosed)"

    if command -v raspi-config >/dev/null 2>&1; then
        raspi-config nonint do_blanking 1 >/dev/null 2>&1 && ok "Screen blanking disabled" || true
    fi

    for svc in bluetooth avahi-daemon; do
        systemctl disable --now "$svc" >/dev/null 2>&1 && info "Disabled $svc (not needed on a camera wall)" || true
    done
fi

# ---------------------------------------------------------------------------
if [[ -n "$SPLASH_IMAGE" ]]; then
    banner "Boot splash"

    install -m 644 "$SPLASH_IMAGE" "$INSTALL_DIR/boot-splash.png"
    ok "Splash image installed"

    sed -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
        "$SCRIPT_DIR/systemd/pimonitor-splash.service" > /etc/systemd/system/pimonitor-splash.service
    chmod 644 /etc/systemd/system/pimonitor-splash.service

    # Hand the screen over cleanly: the splash releases the VT just before X grabs it.
    install -d -m 755 /etc/systemd/system/pimonitor.service.d
    cat > /etc/systemd/system/pimonitor.service.d/10-splash.conf <<'EOF'
[Service]
ExecStartPre=-/bin/systemctl stop pimonitor-splash.service
EOF

    systemctl daemon-reload
    systemctl enable pimonitor-splash.service >/dev/null 2>&1
    ok "Splash shows from early boot until the cameras appear"

    # Silence the boot: no rainbow, no logos, no kernel text, no cursor.
    BOOTDIR=""
    [[ -f /boot/firmware/cmdline.txt ]] && BOOTDIR=/boot/firmware
    [[ -z "$BOOTDIR" && -f /boot/cmdline.txt ]] && BOOTDIR=/boot
    if [[ -n "$BOOTDIR" ]]; then
        cp "$BOOTDIR/cmdline.txt" "$BOOTDIR/cmdline.txt.pimonitor.bak" 2>/dev/null || true
        [[ -f "$BOOTDIR/config.txt" ]] && cp "$BOOTDIR/config.txt" "$BOOTDIR/config.txt.pimonitor.bak" 2>/dev/null || true

        if [[ -f "$BOOTDIR/config.txt" ]]; then
            grep -q "^disable_splash=1" "$BOOTDIR/config.txt" || echo "disable_splash=1" >> "$BOOTDIR/config.txt"
            ok "Rainbow splash disabled"
        fi

        CUR=$(cat "$BOOTDIR/cmdline.txt")
        NEW="${CUR/console=tty1/console=tty3}"
        for p in quiet loglevel=0 logo.nologo vt.global_cursor_default=0 consoleblank=0; do
            grep -qw -- "$p" <<<"$NEW" || NEW="$NEW $p"
        done
        echo "$NEW" | tr -s ' ' | sed 's/ *$//' > "$BOOTDIR/cmdline.txt"
        ok "Boot messages silenced (backups saved as *.pimonitor.bak)"
    else
        warn "No cmdline.txt found, skipped boot text silencing (not a Pi?)"
    fi
fi

# ---------------------------------------------------------------------------
banner "Done"
echo -e "  ${W}Next steps:${Z}"
echo ""
if [[ "$NEW_CONFIG" == true ]]; then
echo -e "  1. Find your cameras and their stream URLs:"
echo -e "     ${Y}sudo pimonitor-discover --scan 192.168.1.0/24 -u admin -p PASSWORD --config${Z}"
echo ""
echo -e "  2. Paste the result into the config:"
echo -e "     ${Y}sudo nano $CONFIG${Z}"
echo ""
echo -e "  3. Start the wall:"
echo -e "     ${Y}sudo systemctl start pimonitor${Z}"
else
echo -e "  1. Restart with your existing config:"
echo -e "     ${Y}sudo systemctl restart pimonitor${Z}"
fi
echo ""
echo -e "  Logs:   ${Y}journalctl -u pimonitor -f${Z}"
echo -e "  Status: ${Y}pimonitor status${Z}"
if [[ -n "$SPLASH_IMAGE" ]] || [[ "$DO_HARDEN" == true ]]; then
echo ""
echo -e "  ${W}Reboot to apply the boot changes:${Z} ${Y}sudo reboot${Z}"
fi
echo ""
