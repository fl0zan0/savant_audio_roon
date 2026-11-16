#!/bin/sh
# Uninstalls Roon Bridge installed by savant_audio_roon (asks for the root password).
#   sh /data/RPM/savant-audio-roon/uninstall.sh            # keeps the data (identity, settings)
#   sh /data/RPM/savant-audio-roon/uninstall.sh --purge    # removes everything
# Or from GitHub:
#   wget -qO- https://raw.githubusercontent.com/fl0zan0/savant_audio_roon/main/uninstall.sh | sh
#   wget -qO- https://raw.githubusercontent.com/fl0zan0/savant_audio_roon/main/uninstall.sh | sh -s -- --purge
set -eu

REPO=${REPO:-fl0zan0/savant_audio_roon}
BASE=/data/RPM/savant-audio-roon
UNIT=roonbridge
SERVICE=/etc/systemd/system/$UNIT.service

if [ "$(id -u)" != 0 ]; then
    SELF=/tmp/savant-audio-roon-uninstall.sh
    if [ -f "$0" ] && grep -q savant_audio_roon "$0" 2>/dev/null; then
        cp "$0" "$SELF"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$SELF" "https://raw.githubusercontent.com/$REPO/main/uninstall.sh"
    else
        wget -q -O "$SELF" "https://raw.githubusercontent.com/$REPO/main/uninstall.sh"
    fi
    echo "Root access is needed: enter the root password."
    exec su root -c "sh $SELF $*" < /dev/tty
fi

echo "==> Stopping and removing the $UNIT service"
systemctl stop "$UNIT" 2>/dev/null || true
systemctl disable "$UNIT" 2>/dev/null || true
rm -f "$SERVICE"
systemctl daemon-reload

if [ "${1:-}" = "--purge" ]; then
    echo "==> Removing $BASE"
    rm -rf "$BASE"
else
    echo "==> Removing the program (data kept in $BASE/data)"
    rm -rf "$BASE/RoonBridge"
fi
echo "Uninstall complete."
