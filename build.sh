#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ZenTap"
DESKTOP_APP="${HOME}/Desktop/${APP_NAME}.app"
BUILD_DIR="${ROOT_DIR}/build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"

mkdir -p "${BUILD_DIR}" "${ROOT_DIR}/Resources"

swift "${ROOT_DIR}/Resources/IconMaker.swift" "${BUILD_DIR}/${APP_NAME}.iconset"
iconutil -c icns "${BUILD_DIR}/${APP_NAME}.iconset" -o "${BUILD_DIR}/${APP_NAME}.icns"

swiftc \
  "${ROOT_DIR}/Sources/ZenTap/main.swift" \
  -o "${BUILD_DIR}/${APP_NAME}" \
  -framework AppKit \
  -framework ApplicationServices \
  -framework AVFoundation \
  -framework Carbon \
  -framework Speech

rm -rf "${APP_DIR}" "${DESKTOP_APP}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${ROOT_DIR}/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "${BUILD_DIR}/${APP_NAME}.icns" "${APP_DIR}/Contents/Resources/${APP_NAME}.icns"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cp -R "${APP_DIR}" "${DESKTOP_APP}"
codesign --force --deep --sign - "${DESKTOP_APP}"
codesign --verify --deep --strict --verbose=2 "${DESKTOP_APP}"

echo "Built ${DESKTOP_APP}"
