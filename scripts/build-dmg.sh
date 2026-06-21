#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${PROJECT_DIR}/DerivedData"
STAGING_DIR="${PROJECT_DIR}/dist/SimpleMarkdown-dmg"
RELEASE_DIR="${PROJECT_DIR}/dist/releases"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/SimpleMarkdown.app"
DMG_PATH="${RELEASE_DIR}/SimpleMarkdown.dmg"

cd "${PROJECT_DIR}"

xcodebuild \
  -project SimpleMarkdown.xcodeproj \
  -scheme SimpleMarkdown \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  clean build

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}" "${RELEASE_DIR}"

ditto "${APP_PATH}" "${STAGING_DIR}/SimpleMarkdown.app"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
  -volname SimpleMarkdown \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

hdiutil verify "${DMG_PATH}"

echo "Created ${DMG_PATH}"
