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

# Stage icon for linuxdeploy. Reuse the macOS asset (PNG) — we don't have a
# Linux-native icon file. linuxdeploy needs the icon at a path it can find via
# --icon-file, OR matching the desktop file's Icon= name under hicolor.
# This script is invoked from the `performancebench/` working directory, so
# the macOS asset path is relative to that — NOT one level up.
ICON_SRC="macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
ICON_DST="AppDir/performancebench.png"
if [ -f "${ICON_SRC}" ]; then
  cp "${ICON_SRC}" "${ICON_DST}"
else
  echo "::error::Icon source missing: ${ICON_SRC} (pwd=$(pwd))"
  exit 1
fi

# Create minimal .desktop file for linuxdeploy. Icon= must be present and must
# match the icon basename (no extension) for linuxdeploy to accept it.
mkdir -p AppDir/usr/share/applications
cat > AppDir/usr/share/applications/performancebench.desktop << 'DESKTOPEOF'
[Desktop Entry]
Name=PerformanceBench
Exec=performancebench
Icon=performancebench
Type=Application
Categories=Development;
DESKTOPEOF

# Flutter's Linux build emits the binary + data/ + lib/ as siblings; we copy
# the whole bundle into AppDir root so the binary's runtime layout is preserved.
# linuxdeploy normally searches AppDir/usr/bin for the executable named in
# `Exec=`; pass --executable explicitly so it picks up the root-level binary.
EXECUTABLE="AppDir/performancebench"
if [ ! -x "${EXECUTABLE}" ]; then
  echo "::error::Flutter binary missing or not executable: ${EXECUTABLE}"
  ls -la AppDir | head -20
  exit 1
fi

# APPIMAGE_EXTRACT_AND_RUN works around missing FUSE on minimal CI runners.
export APPIMAGE_EXTRACT_AND_RUN=1
"${LINUXDEPLOY}" \
  --appdir AppDir \
  --output appimage \
  --desktop-file AppDir/usr/share/applications/performancebench.desktop \
  --icon-file "${ICON_DST}" \
  --executable "${EXECUTABLE}"

# Rename output (linuxdeploy emits something like PerformanceBench-x86_64.AppImage)
APPIMAGE_OUT=$(ls -1 ./*.AppImage 2>/dev/null | head -1 || true)
if [ -z "${APPIMAGE_OUT}" ]; then
  echo "::error::linuxdeploy did not produce an AppImage"
  exit 1
fi
mv "${APPIMAGE_OUT}" "${OUTPUT}"
chmod +x "${OUTPUT}"
echo "✅ AppImage created: ${OUTPUT}"
