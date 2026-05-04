#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2024 PerformanceBench Contributors
#
# Generate Linux AppImage from Flutter build output.

set -euo pipefail

VERSION="${VERSION:-1.0.0}"
APP_NAME="PerformanceBench"
OUTPUT="${APP_NAME}-${VERSION}-x86_64.AppImage"

echo "==> Building Flutter Linux release..."
flutter build linux --release

BUILD_DIR="build/linux/x64/release/bundle"

# Download linuxdeploy if not present
LINUXDEPLOY="/tmp/linuxdeploy-x86_64.AppImage"
if [ ! -f "${LINUXDEPLOY}" ]; then
  echo "==> Downloading linuxdeploy..."
  wget -q "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" \
    -O "${LINUXDEPLOY}"
  chmod +x "${LINUXDEPLOY}"
fi

echo "==> Creating AppImage..."
mkdir -p AppDir
cp -r "${BUILD_DIR}"/* AppDir/

"${LINUXDEPLOY}" \
  --appdir AppDir \
  --output appimage \
  --desktop-file AppDir/data/flutter_assets/linux.desktop 2>/dev/null || true

# Rename output
if ls *.AppImage 1>/dev/null 2>&1; then
  mv ./*.AppImage "${OUTPUT}"
  chmod +x "${OUTPUT}"
  echo "✅ AppImage created: ${OUTPUT}"
else
  # Fallback: simple tar.gz
  echo "==> AppImage not available — creating tar.gz fallback..."
  tar -czf "${APP_NAME}-${VERSION}-linux-x64.tar.gz" -C build/linux/x64/release bundle
  echo "✅ Archive created: ${APP_NAME}-${VERSION}-linux-x64.tar.gz"
fi
