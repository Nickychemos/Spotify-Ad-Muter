#!/usr/bin/env bash
# Build spotify-ad-muter_VERSION_all.deb from the staging directory.
# Output lands in ./build/.
set -euo pipefail

cd "$(dirname "$0")/../.."  # → repo root

VERSION="${VERSION:-1.0.0}"
PKG="spotify-ad-muter"
ARCH="all"

BUILD_DIR="build"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$BUILD_DIR"

# --- file layout in /
install -d "$STAGE/DEBIAN"
install -d "$STAGE/usr/bin"
install -d "$STAGE/usr/lib/spotify-ad-muter"
install -d "$STAGE/usr/lib/systemd/user"
install -d "$STAGE/usr/share/doc/spotify-ad-muter"

# --- runtime files
install -m 755 packaging/debian/spotify-ad-muter        "$STAGE/usr/bin/spotify-ad-muter"
install -m 644 src/spotify_ad_mute.py                   "$STAGE/usr/lib/spotify-ad-muter/spotify_ad_mute.py"
install -m 644 packaging/systemd/spotify-ad-muter.service \
    "$STAGE/usr/lib/systemd/user/spotify-ad-muter.service"
install -m 644 README.md                                "$STAGE/usr/share/doc/spotify-ad-muter/README.md"

# --- control + maintainer scripts
sed "s/@VERSION@/$VERSION/" packaging/debian/control.in > "$STAGE/DEBIAN/control"
install -m 755 packaging/debian/postinst                "$STAGE/DEBIAN/postinst"
install -m 755 packaging/debian/prerm                   "$STAGE/DEBIAN/prerm"

# --- build
OUT="$BUILD_DIR/${PKG}_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$STAGE" "$OUT"

echo
echo "Built: $OUT"
echo
dpkg-deb -I "$OUT"
echo "--- contents ---"
dpkg-deb -c "$OUT"
