#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

VERSION=${GITHUB_REF_NAME:-0.1.0}
VERSION=${VERSION#v}
PKGNAME=solen
ARCH=all
STAGE="dist/${PKGNAME}_${VERSION}_${ARCH}"

rm -rf dist
mkdir -p "${STAGE}/DEBIAN"

cat > "${STAGE}/DEBIAN/control" <<EOF
Package: ${PKGNAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: SOLEN <noreply@example.com>
Description: SOLEN (ServerUtils) runner and scripts
 Simple sysadmin toolkit with a unified runner, JSON outputs, and systemd units.
EOF

# Install files
mkdir -p "${STAGE}/usr/local/bin" "${STAGE}/usr/local/lib/solen" "${STAGE}/usr/share/doc/solen/examples/logrotate" "${STAGE}/usr/share/doc/solen"

install -m 0755 serverutils "${STAGE}/usr/local/bin/serverutils"
ln -s serverutils "${STAGE}/usr/local/bin/solen"

cp -R Scripts "${STAGE}/usr/local/lib/solen/"
cp -R systemd "${STAGE}/usr/local/lib/solen/"
install -m 0644 docs/LOGGING.md "${STAGE}/usr/share/doc/solen/LOGGING.md"
install -m 0644 docs/examples/logrotate/solen "${STAGE}/usr/share/doc/solen/examples/logrotate/solen"

mkdir -p dist
dpkg-deb --build "${STAGE}" >/dev/null
echo "Built $(ls dist/*.deb)"

