#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${PROJECT_DIR}/DerivedData"
RELEASE_DIR="${PROJECT_DIR}/dist/releases"
ZIP_STAGING_DIR="${PROJECT_DIR}/dist/SimpleMarkdown-zip"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/SimpleMarkdown.app"
ZIP_PATH="${RELEASE_DIR}/SimpleMarkdown.zip"

cd "${PROJECT_DIR}"

xcodebuild \
  -project SimpleMarkdown.xcodeproj \
  -scheme SimpleMarkdown \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  clean build

rm -rf "${ZIP_STAGING_DIR}"
mkdir -p "${ZIP_STAGING_DIR}" "${RELEASE_DIR}"

ditto "${APP_PATH}" "${ZIP_STAGING_DIR}/SimpleMarkdown.app"
ditto -c -k --keepParent "${ZIP_STAGING_DIR}/SimpleMarkdown.app" "${ZIP_PATH}"

echo "Created ${ZIP_PATH}"
