#!/bin/bash

# Generalized variables
PACKAGE_NAME="yajl"
VERSION="2.1.0"
TAR_FILENAME="${PACKAGE_NAME}-${VERSION}.tar.gz"
URL="https://codeload.github.com/lloyd/${PACKAGE_NAME}/tar.gz/refs/tags/${VERSION}"
BUILD_DIR="/tmp/${PACKAGE_NAME}-build"
INSTALL_DIR="/usr"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure necessary commands are available
for cmd in wget tar make sudo; do
    if ! command_exists "$cmd"; then
        echo "Error: $cmd is not installed. Please install it before running this script."
        exit 1
    fi
done

# Create build directory if it doesn't exist
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}" || exit

# Download the tarball
echo "Downloading ${PACKAGE_NAME}..."
wget -c "${URL}" -O "${TAR_FILENAME}"

# Remove write protection from tarball
chmod u+w "${TAR_FILENAME}"

# Extract tarball
echo "Extracting ${PACKAGE_NAME}..."
tar -xvf "${TAR_FILENAME}" || { echo "Failed to extract ${PACKAGE_NAME}."; exit 1; }

# Change directory to extracted source
EXTRACT_DIR="${PACKAGE_NAME}-${VERSION}"
cd "${EXTRACT_DIR}" || exit
chmod -R d:d .
# Configure build with shared library support
echo "Configuring ${PACKAGE_NAME} with shared support..."
./configure --prefix="${INSTALL_DIR}" --enable-shared || { echo "Configuration failed."; exit 1; }

# Build
echo "Building ${PACKAGE_NAME}..."
make || { echo "Build failed."; exit 1; }

# Install
echo "Installing ${PACKAGE_NAME}..."
sudo make install || { echo "Installation failed."; exit 1; }

# Clean up
echo "Cleaning up..."
cd "${BUILD_DIR}" || exit
rm -rf "${EXTRACT_DIR}" "${TAR_FILENAME}"

# Remove build directory if empty
if [ -z "$(ls -A ${BUILD_DIR})" ]; then
    rmdir "${BUILD_DIR}"
fi

echo "${PACKAGE_NAME} ${VERSION} installation complete."
