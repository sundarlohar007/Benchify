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

# Create minimal .desktop file for linuxdeploy
mkdir -p AppDir/usr/share/applications
cat > AppDir/usr/share/applications/performancebench.desktop << 'DESKTOPEOF'
[Desktop Entry]
Name=PerformanceBench
Exec=performancebench
Type=Application
Categories=Development;
DESKTOPEOF

# APPIMAGE_EXTRACT_AND_RUN works around missing FUSE on minimal CI runners.
export APPIMAGE_EXTRACT_AND_RUN=1
"${LINUXDEPLOY}" \
  --appdir AppDir \
  --output appimage \
  --desktop-file AppDir/usr/share/applications/performancebench.desktop

# Rename output (linuxdeploy emits something like PerformanceBench-x86_64.AppImage)
APPIMAGE_OUT=$(ls -1 ./*.AppImage 2>/dev/null | head -1 || true)
if [ -z "${APPIMAGE_OUT}" ]; then
  echo "::error::linuxdeploy did not produce an AppImage"
  exit 1
fi
mv "${APPIMAGE_OUT}" "${OUTPUT}"
chmod +x "${OUTPUT}"
echo "✅ AppImage created: ${OUTPUT}"
