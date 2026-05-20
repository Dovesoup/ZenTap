#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ZenTap"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${ROOT_DIR}/Info.plist")"
BUILD_DIR="${ROOT_DIR}/build"
DIST_DIR="${ROOT_DIR}/dist"
STAGING_DIR="${BUILD_DIR}/dmg-root"
DESKTOP_APP="${HOME}/Desktop/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

"${ROOT_DIR}/build.sh"

rm -rf "${STAGING_DIR}" "${DMG_PATH}" "${DMG_PATH}.sha256"
mkdir -p "${STAGING_DIR}" "${DIST_DIR}"

cp -R "${DESKTOP_APP}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
  -volname "ZenTap ${VERSION}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

shasum -a 256 "${DMG_PATH}" > "${DMG_PATH}.sha256"

echo "Built ${DMG_PATH}"
echo "Checksum ${DMG_PATH}.sha256"
