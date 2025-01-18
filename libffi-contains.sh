#!/bin/bash

# Define variables for libffi
PACKAGE_NAME="libffi"
VERSION="3.4.6"
TAR_FILENAME="${PACKAGE_NAME}-${VERSION}.tar.gz"
URL="https://github.com/libffi/libffi/releases/download/v3.4.6/${TAR_FILENAME}"
HASH="B9CAC6C5997DCA2B3787A59EDE34E0EB"  # Correct MD5 hash for libffi-3.4.6
INSTALL_DIR="/usr"
BUILD_DIR="/tmp/${PACKAGE_NAME}-build"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure necessary commands are available
for cmd in wget tar make sudo md5sum chown curl; do
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
curl -LO "${URL}"

# Remove write protection from tarball
chmod u+w "${TAR_FILENAME}"

# Check the hash
echo "Checking hash..."
echo "${HASH}  ${TAR_FILENAME}" | md5sum -c - || { echo "Hash mismatch. Aborting."; exit 1; }

# Extract
echo "Extracting archive..."
tar -xvf "${TAR_FILENAME}" || { echo "Failed to extract archive."; exit 1; }

# Remove write protection from extracted directory
EXTRACT_DIR="${PACKAGE_NAME}-${VERSION}"
chmod -R u+w "${EXTRACT_DIR}"

# Change ownership to current user
echo "Changing ownership of extracted directory..."
chown -R $(id -u):$(id -g) "${EXTRACT_DIR}"

# Configure, build, and install 
cd "${EXTRACT_DIR}" || exit
echo "Configuring ${PACKAGE_NAME}..."
./configure --prefix="${INSTALL_DIR}" --disable-static --enable-shared || { echo "Configuration failed."; exit 1; }

echo "Building ${PACKAGE_NAME}..."
make || { echo "Build failed."; exit 1; }

# Run tests
echo "Running tests..."
make check -j12 || { echo "Tests failed."; exit 1; }

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

echo "Installation of ${PACKAGE_NAME} complete."
