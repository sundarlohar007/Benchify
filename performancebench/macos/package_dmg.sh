#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2024 PerformanceBench Contributors
#
# Package macOS .app bundle into a DMG.

set -euo pipefail

VERSION="${VERSION:-1.0.0}"
APP_DIR="build/macos/Build/Products/Release"
APP_NAME="PerformanceBench"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "==> Building Flutter macOS release..."
flutter build macos --release

echo "==> Creating DMG..."
hdiutil create -volname "${APP_NAME}" \
  -srcfolder "${APP_DIR}/${APP_NAME}.app" \
  -ov -format UDZO \
  "${DMG_NAME}"

echo "==> DMG created: ${DMG_NAME}"
ls -lh "${DMG_NAME}"

# Notarization (optional — requires APPLE_NOTARY_PROFILE env var)
if [ -n "${APPLE_NOTARY_PROFILE:-}" ]; then
  echo "==> Notarizing..."
  xcrun notarytool submit "${DMG_NAME}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_NOTARY_PROFILE}" \
    --wait
  xcrun stapler staple "${DMG_NAME}"
  echo "==> Notarization complete."
else
  echo "==> Skipping notarization (APPLE_NOTARY_PROFILE not set)."
fi

echo "✅ DMG packaging complete: ${DMG_NAME}"
