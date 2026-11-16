#!/bin/sh
# Installs or updates Roon Bridge on a Savant audio server (Savant PAV-SMS2001).
#
# From GitHub (logged in over SSH with the RPM account; asks for the root password):
#   wget -qO- https://raw.githubusercontent.com/fl0zan0/savant_audio_roon/main/install.sh | sh
#
# Differences with Roon's own installer (roonbridge-installer-linuxarmv7hf.sh):
#   - downloads with redirects followed (Roon moved download.roonlabs.com to .net; the
#     old script saved the 301 page and failed with "not a bzip2 file");
#   - program and data live in /data/RPM/savant-audio-roon, which Savant firmware updates
#     keep: after an update, run this again and the bridge comes back with the same
#     identity in Roon (no new device to enable);
#   - a previous install from Roon's script (/opt/RoonBridge, /var/roon) is migrated.
#
# Run again at any time to reinstall the latest Roon Bridge (settings are kept).
# Uninstall: sh /data/RPM/savant-audio-roon/uninstall.sh [--purge]

set -eu

REPO=${REPO:-fl0zan0/savant_audio_roon}
ROON_URL=https://download.roonlabs.net/builds/RoonBridge_linuxarmv7hf.tar.bz2
BASE=/data/RPM/savant-audio-roon
APP=$BASE/RoonBridge
DATA=$BASE/data
UNIT=roonbridge
SERVICE=/etc/systemd/system/$UNIT.service

say()  { printf '\n==> %s\n' "$*"; }
fail() { printf '\nError: %s\n' "$*" >&2; exit 1; }

fetch() { # fetch URL FILE
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$2" "$1"
    else
        wget -q -O "$2" "$1"
    fi
}

# --- become root -----------------------------------------------------------------------
if [ "$(id -u)" != 0 ]; then
    SELF=/tmp/savant-audio-roon-install.sh
    if [ -f "$0" ] && grep -q savant_audio_roon "$0" 2>/dev/null; then
        cp "$0" "$SELF"
    else # run through "wget | sh": get a copy of this script
        fetch "https://raw.githubusercontent.com/$REPO/main/install.sh" "$SELF" \
            || fail "could not download the installer from GitHub."
    fi
    echo "Root access is needed: enter the root password (on Savant audio servers it is usually the RPM password)."
    exec su root -c "sh $SELF $*" < /dev/tty
fi

case "$(uname -m)" in
    armv7*|aarch64*) ;;
    *) fail "this is for the Savant audio server (armv7), not $(uname -m)." ;;
esac
[ -d /data/RPM ] || fail "/data/RPM not found: is this a Savant audio server?"
command -v bash >/dev/null 2>&1 || fail "bash is required by Roon Bridge."

# --- download and check ----------------------------------------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

say "Downloading Roon Bridge"
fetch "$ROON_URL" "$TMP/rb.tar.bz2" || fail "download failed: $ROON_URL"
tar xjf "$TMP/rb.tar.bz2" -C "$TMP" || fail "the downloaded file is not a valid archive."
[ -x "$TMP/RoonBridge/check.sh" ] || fail "broken package (no RoonBridge/check.sh)."
echo "   version: $(head -n 2 "$TMP/RoonBridge/VERSION" | tail -n 1)"

say "Checking that Roon Bridge can run here"
"$TMP/RoonBridge/check.sh" || fail "Roon Bridge's own check failed (see above)."

# --- install ---------------------------------------------------------------------------
say "Installing in $BASE"
systemctl stop "$UNIT" 2>/dev/null || true
mkdir -p "$BASE"

# Migrate an install made with Roon's script: keep its identity and settings.
if [ -d /var/roon ] && [ ! -d "$DATA" ]; then
    echo "   moving /var/roon to $DATA (keeps the bridge's identity in Roon)"
    mv /var/roon "$DATA"
fi
if [ -d /opt/RoonBridge ]; then
    echo "   removing the former /opt/RoonBridge"
    rm -rf /opt/RoonBridge
fi
mkdir -p "$DATA"

rm -rf "$APP"
mv "$TMP/RoonBridge" "$APP"
fetch "https://raw.githubusercontent.com/$REPO/main/install.sh" "$BASE/install.sh" 2>/dev/null || true
fetch "https://raw.githubusercontent.com/$REPO/main/uninstall.sh" "$BASE/uninstall.sh" 2>/dev/null || true
chmod +x "$BASE"/*.sh 2>/dev/null || true

# The unit file is a real file in /etc (not a link into /data, which is mounted after
# systemd loads its units); RequiresMountsFor orders the start after /data is mounted.
cat > "$SERVICE" <<EOF
[Unit]
Description=Roon Bridge (savant_audio_roon)
After=network-online.target
Wants=network-online.target
RequiresMountsFor=$BASE

[Service]
Type=simple
User=root
Environment=ROON_DATAROOT=$DATA
Environment=ROON_ID_DIR=$DATA
ExecStart=$APP/start.sh
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$UNIT" >/dev/null 2>&1
systemctl restart "$UNIT"
sleep 5
systemctl is-active --quiet "$UNIT" || {
    systemctl --no-pager status "$UNIT" | tail -15
    fail "the $UNIT service does not start (see above)."
}

say "Result"
echo "   service $UNIT: $(systemctl is-active "$UNIT") / $(systemctl is-enabled "$UNIT")"
echo "   program: $APP"
echo "   data:    $DATA"
echo "   logs:    $DATA/RAATServer/Logs/"
echo ""
echo "In Roon: Settings > Audio, enable this Savant audio server's output."
echo "After a Savant firmware update, run the same install command again."
echo ""
echo "Installation complete."
