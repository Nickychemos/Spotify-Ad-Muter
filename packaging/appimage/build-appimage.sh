#!/usr/bin/env bash
# Build spotify-ad-muter-VERSION-x86_64.AppImage into ./build/.
# Uses python-appimage, which bundles a stock CPython into the AppImage so it
# runs on any glibc Linux without depending on the host's Python.
set -euo pipefail

cd "$(dirname "$0")/../.."  # → repo root

VERSION="${VERSION:-1.0.0}"
PYVERSION="${PYVERSION:-3.12}"
PKG="spotify-ad-muter"

BUILD_DIR="$(pwd)/build"
mkdir -p "$BUILD_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Bootstrap python-appimage in an isolated venv.
python3 -m venv "$WORK/venv"
"$WORK/venv/bin/pip" install --quiet --upgrade pip
"$WORK/venv/bin/pip" install --quiet python-appimage

# Construct the app directory expected by python-appimage:
#   APP/entrypoint              "module:function" — what to call as __main__
#   APP/requirements.txt        pip deps to install into the bundled site-packages
#   APP/spotify_ad_mute.py      the module itself, will go into site-packages
APP="$WORK/app"
mkdir -p "$APP"
cp src/spotify_ad_mute.py "$APP/spotify_ad_mute.py"

cat > "$APP/requirements.txt" <<'EOF'
pulsectl>=23.5.2
EOF

cat > "$APP/entrypoint" <<'EOF'
spotify_ad_mute:main
EOF

# Build. python-appimage writes the .AppImage into the current working dir.
( cd "$WORK" && "$WORK/venv/bin/python-appimage" build app -p "$PYVERSION" --name "$PKG" "$APP" )

# Move it to build/ with our preferred name.
PRODUCED="$(find "$WORK" -maxdepth 1 -name '*.AppImage' -print -quit)"
if [ -z "$PRODUCED" ]; then
    echo "ERROR: python-appimage didn't produce a .AppImage file." >&2
    exit 1
fi
OUT="$BUILD_DIR/${PKG}-${VERSION}-x86_64.AppImage"
mv "$PRODUCED" "$OUT"
chmod +x "$OUT"

echo
echo "Built:"
ls -la "$OUT"
