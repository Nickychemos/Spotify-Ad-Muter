#!/usr/bin/env bash
# Install the official Spotify .deb (replaces the snap version).
set -euo pipefail

TIMEOUT_OPTS=(-o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20)
KEY_ID="5384CE82BA52C83A"
KEYRING="/etc/apt/trusted.gpg.d/spotify.gpg"

echo "[1/4] Fetching current Spotify signing key ($KEY_ID)"
if curl -sSf --max-time 30 "https://download.spotify.com/debian/pubkey_${KEY_ID}.gpg" \
      | sudo gpg --dearmor --yes -o "$KEYRING"; then
    echo "    got key from spotify.com"
else
    echo "    spotify.com had no key file for this ID — falling back to Ubuntu keyserver"
    sudo apt install -y gnupg dirmngr "${TIMEOUT_OPTS[@]}" >/dev/null
    sudo rm -f "$KEYRING"
    TMPRING="$(mktemp)"
    sudo gpg --no-default-keyring --keyring "$TMPRING" \
             --keyserver hkps://keyserver.ubuntu.com --recv-keys "$KEY_ID"
    sudo gpg --no-default-keyring --keyring "$TMPRING" --export "$KEY_ID" \
      | sudo tee "$KEYRING" >/dev/null
    sudo rm -f "$TMPRING"
fi

echo "[2/4] Adding Spotify apt source"
echo "deb https://repository.spotify.com stable non-free" \
  | sudo tee /etc/apt/sources.list.d/spotify.list

echo "[3/4] Refreshing only the spotify source"
sudo apt update "${TIMEOUT_OPTS[@]}" \
  -o Dir::Etc::sourcelist="sources.list.d/spotify.list" \
  -o Dir::Etc::sourceparts="-" \
  -o APT::Get::List-Cleanup="0"

echo "[4/4] Installing spotify-client"
sudo apt install -y spotify-client "${TIMEOUT_OPTS[@]}"

echo
echo "DONE: spotify installed at $(command -v spotify)"
