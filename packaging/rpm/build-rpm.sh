#!/usr/bin/env bash
# Build spotify-ad-muter-VERSION-1.<dist>.noarch.rpm into ./build/.
# Needs `rpmbuild` (package `rpm` on Debian/Ubuntu, `rpm-build` on Fedora).
set -euo pipefail

cd "$(dirname "$0")/../.."  # → repo root

VERSION="${VERSION:-1.0.0}"
PKG="spotify-ad-muter"

BUILD_DIR="$(pwd)/build"
RPM_TOP="$BUILD_DIR/rpm"
mkdir -p "$RPM_TOP"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Tarball of the repo under the canonical name expected by %prep.
TARBALL_DIR="$(mktemp -d)"
trap 'rm -rf "$TARBALL_DIR"' EXIT
cp -a . "$TARBALL_DIR/$PKG-$VERSION"
rm -rf "$TARBALL_DIR/$PKG-$VERSION/.git" \
       "$TARBALL_DIR/$PKG-$VERSION/build" \
       "$TARBALL_DIR/$PKG-$VERSION/venv" \
       "$TARBALL_DIR/$PKG-$VERSION/.claude"
( cd "$TARBALL_DIR" && tar czf "$RPM_TOP/SOURCES/$PKG-$VERSION.tar.gz" "$PKG-$VERSION" )

# Spec file with version substituted.
sed "s/@VERSION@/$VERSION/g" packaging/rpm/spotify-ad-muter.spec.in > "$RPM_TOP/SPECS/$PKG.spec"

rpmbuild --define "_topdir $RPM_TOP" -bb "$RPM_TOP/SPECS/$PKG.spec"

# Copy artifact out of rpmbuild's tree into build/ for easy upload.
find "$RPM_TOP/RPMS" -name '*.rpm' -exec cp {} "$BUILD_DIR/" \;

echo
echo "Built:"
ls -la "$BUILD_DIR"/*.rpm
