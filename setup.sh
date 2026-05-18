#!/usr/bin/env bash
# Spotify Ad Muter — one-time setup for Ubuntu / Debian-based systems.
set -euo pipefail

echo "[1/3] Installing system dependency: playerctl"
if ! command -v playerctl >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y playerctl
else
    echo "playerctl already installed."
fi

echo "[2/3] Creating Python virtual environment in ./venv"
if [ ! -d venv ]; then
    python3 -m venv venv
fi

echo "[3/3] Installing Python dependencies"
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt

echo
echo "Setup complete. Start the muter with:"
echo "    ./venv/bin/python src/spotify_ad_mute.py"
