#!/bin/bash
set -euo pipefail

# Dictum installer — downloads the latest notarized release and installs it to /Applications.

APP_NAME="Dictum"
INSTALL_DIR="/Applications"
REPO="Nikoro/dictum"

echo "Installing ${APP_NAME}..."

# Create temp directory
TMPDIR_INSTALL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_INSTALL"' EXIT

# Download latest release
echo "Downloading latest release..."
curl -fsSL "https://github.com/${REPO}/releases/latest/download/Dictum.zip" -o "${TMPDIR_INSTALL}/Dictum.zip"

# Extract
echo "Extracting..."
ditto -x -k "${TMPDIR_INSTALL}/Dictum.zip" "${TMPDIR_INSTALL}"

# Remove old version if present
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  echo "Removing previous version..."
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

# Move to Applications
echo "Moving to ${INSTALL_DIR}..."
mv "${TMPDIR_INSTALL}/${APP_NAME}.app" "${INSTALL_DIR}/"

echo ""
echo "${APP_NAME} installed successfully!"
echo "Open it from ${INSTALL_DIR} or Spotlight."
