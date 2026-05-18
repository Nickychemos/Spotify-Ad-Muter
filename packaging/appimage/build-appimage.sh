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

# Construct the app directory expected by python-appimage.
APP="$WORK/app"
mkdir -p "$APP"
cp src/spotify_ad_mute.py "$APP/spotify_ad_mute.py"

cat > "$APP/requirements.txt" <<'EOF'
pulsectl>=23.5.2
EOF

# Calling spotify_ad_mute.main() is what `python src/spotify_ad_mute.py` does.
cat > "$APP/entrypoint" <<'EOF'
{{ python-executable }} -c "from spotify_ad_mute import main; import sys; sys.exit(main())" "$@"
EOF

OUT="$BUILD_DIR/${PKG}-${VERSION}-x86_64.AppImage"
"$WORK/venv/bin/python-appimage" build app -p "$PYVERSION" "$APP" --name "$PKG" --output "$OUT"

echo
echo "Built:"
ls -la "$OUT"
echo
echo "Smoke test (should print usage / startup line):"
"$OUT" --help 2>&1 | head -5 || true
