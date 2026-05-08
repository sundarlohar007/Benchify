#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2024 PerformanceBench Contributors
#
# Build a macOS .pkg installer (productbuild) that drops PerformanceBench.app
# into /Applications. Complements package_dmg.sh — DMG is drag-to-install,
# PKG is wizard-driven install.

set -euo pipefail

VERSION="${VERSION:-1.0.0}"
APP_DIR="build/macos/Build/Products/Release"
APP_NAME="PerformanceBench"
PKG_NAME="${APP_NAME}-${VERSION}.pkg"
IDENTIFIER="dev.benchify.performancebench"

if [ ! -d "${APP_DIR}/${APP_NAME}.app" ]; then
  echo "::error::App bundle missing: ${APP_DIR}/${APP_NAME}.app — run 'flutter build macos --release' first"
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

# Component pkg: payload is the .app bundle, install location is /Applications.
COMPONENT_PKG="${WORK_DIR}/component.pkg"
PAYLOAD_ROOT="${WORK_DIR}/payload"
mkdir -p "${PAYLOAD_ROOT}/Applications"
cp -R "${APP_DIR}/${APP_NAME}.app" "${PAYLOAD_ROOT}/Applications/"

echo "==> Building component pkg..."
pkgbuild \
  --root "${PAYLOAD_ROOT}" \
  --identifier "${IDENTIFIER}" \
  --version "${VERSION}" \
  --install-location "/" \
  "${COMPONENT_PKG}"

# Distribution xml — gives wizard UI (title, license, single-pkg layout).
DIST_XML="${WORK_DIR}/distribution.xml"
cat > "${DIST_XML}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>${APP_NAME} ${VERSION}</title>
    <organization>${IDENTIFIER}</organization>
    <domains enable_localSystem="true"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <choices-outline>
        <line choice="default"><line choice="${IDENTIFIER}"/></line>
    </choices-outline>
    <choice id="default"/>
    <choice id="${IDENTIFIER}" visible="false">
        <pkg-ref id="${IDENTIFIER}"/>
    </choice>
    <pkg-ref id="${IDENTIFIER}" version="${VERSION}" onConclusion="none">component.pkg</pkg-ref>
</installer-gui-script>
EOF

echo "==> Building distribution pkg..."
productbuild \
  --distribution "${DIST_XML}" \
  --package-path "${WORK_DIR}" \
  "${PKG_NAME}"

echo "==> PKG created: ${PKG_NAME}"
ls -lh "${PKG_NAME}"

# Notarization (optional — same gating as DMG script)
if [ -n "${APPLE_NOTARY_PROFILE:-}" ]; then
  echo "==> Notarizing PKG..."
  xcrun notarytool submit "${PKG_NAME}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_NOTARY_PROFILE}" \
    --wait
  xcrun stapler staple "${PKG_NAME}"
  echo "==> Notarization complete."
else
  echo "==> Skipping notarization (APPLE_NOTARY_PROFILE not set)."
fi

echo "PKG packaging complete: ${PKG_NAME}"
