#!/bin/bash

# Generalized variables
PACKAGE_NAME="libarchive"
VERSION="3.7.4"
TAR_FILENAME="${PACKAGE_NAME}-${VERSION}.tar.xz"
URL="https://github.com/libarchive/libarchive/releases/download/v${VERSION}/${TAR_FILENAME}"
MD5_HASH="1bab4c1b443ecf4f23ff9881665e680a"
INSTALL_DIR="/usr"
BUILD_DIR="/tmp/${PACKAGE_NAME}-build"

# Get the current user
CURRENT_USER=$(whoami)

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure necessary commands are available
for cmd in curl tar make md5sum; do
    if ! command_exists "$cmd"; then
        echo "Error: $cmd is not installed. Please install it before running this script."
        exit 1
    fi
done

# Create build directory if it doesn't exist
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}" || exit

# Download the tarball
echo "Downloading ${PACKAGE_NAME} version ${VERSION}..."
curl -LO "${URL}"

# Verify the hash
echo "Verifying MD5 hash..."
echo "${MD5_HASH}  ${TAR_FILENAME}" | md5sum -c - || { echo "Hash mismatch. Aborting."; exit 1; }

# Extract the tarball
echo "Extracting ${PACKAGE_NAME}..."
tar -xvf "${TAR_FILENAME}" || { echo "Extraction failed. Aborting."; exit 1; }

# Build and install
EXTRACT_DIR="${PACKAGE_NAME}-${VERSION}"
cd "${EXTRACT_DIR}" || exit
chmod -R u+w .
chown -R d:d .

echo "Configuring ${PACKAGE_NAME}..."
./configure --prefix="${INSTALL_DIR}" --disable-static --without-expat || { echo "Configuration failed. Aborting."; exit 1; }

echo "Building ${PACKAGE_NAME}..."
make || { echo "Build failed. Aborting."; exit 1; }

# Run tests
echo "Running tests..."
LC_ALL=C.UTF-8 make -j12 check || { echo "Some tests failed. Review the output."; }

# Install the package
echo "Installing ${PACKAGE_NAME}..."
sudo make install || { echo "Installation failed. Aborting."; exit 1; }



# Clean up
echo "Cleaning up..."
cd "${BUILD_DIR}" || exit
rm -rf "${EXTRACT_DIR}" "${TAR_FILENAME}"

# Remove build directory if empty
if [ -z "$(ls -A ${BUILD_DIR})" ]; then
    rmdir "${BUILD_DIR}"
fi

echo "Installation of ${PACKAGE_NAME} version ${VERSION} is complete."
