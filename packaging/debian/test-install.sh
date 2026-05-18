#!/usr/bin/env bash
# Test-install the freshly-built .deb on this machine.
# Cleans up the dev systemd unit first, then sudo-apt-installs the package,
# then shows the resulting service status. Needs sudo for apt.
set -euo pipefail

cd "$(dirname "$0")/../.."  # → repo root

DEB="build/spotify-ad-muter_1.0.0_all.deb"
if [ ! -f "$DEB" ]; then
    echo "ERROR: $DEB not found. Run 'make deb' first." >&2
    exit 1
fi

echo "[1/4] Disabling old dev systemd unit (if present)"
systemctl --user disable --now spotify-ad-mute.service 2>/dev/null || true

echo "[2/4] Removing old dev unit files"
sudo rm -f \
    /home/nicky/.config/systemd/user/spotify-ad-mute.service \
    /home/nicky/.config/systemd/user/default.target.wants/spotify-ad-mute.service
systemctl --user daemon-reload || true

echo "[3/4] Installing $DEB"
sudo apt install -y "./$DEB"

echo "[4/4] Service status after install:"
echo
systemctl --user status spotify-ad-muter.service --no-pager 2>&1 | head -20 || true
echo
echo "--- last 8 lines of the muter's own log ---"
tail -n 8 ~/.spotify-ad-muter.log 2>/dev/null || echo "(log file not created yet — service might still be starting)"
