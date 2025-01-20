#!/bin/bash

# Variables
PACKAGE_NAME="libtasn1"
PACKAGE_VERSION="4.19.0"
PACKAGE_TARBALL="${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz"
PACKAGE_URL="https://ftp.gnu.org/gnu/${PACKAGE_NAME}/${PACKAGE_TARBALL}"
PACKAGE_MD5="f701ab57eb8e7d9c105b2cd5d809b29a"
INSTALL_DIR="/usr"
CURRENT_USER=$(whoami)

# Step 1: Download
echo "Downloading ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
wget -O "${PACKAGE_TARBALL}" "${PACKAGE_URL}"

# Step 2: Verify MD5 checksum
echo "Verifying MD5 checksum..."
echo "${PACKAGE_MD5}  ${PACKAGE_TARBALL}" | md5sum -c -

# Step 3: Extract
echo "Extracting ${PACKAGE_TARBALL}..."
tar -xf "${PACKAGE_TARBALL}"

# Step 4: Enter Source Directory
cd "${PACKAGE_NAME}-${PACKAGE_VERSION}"

# Step 5: Configure
echo "Configuring ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
./configure --prefix=${INSTALL_DIR} --disable-static

# Step 6: Build
echo "Building ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
make 

# Step 7: Test
echo "Running tests for ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
make -j12 check

# Step 8: Install
echo "Installing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
sudo make install

# Step 9: Clean Up
echo "Cleaning up..."
cd ..
rm -rf "${PACKAGE_NAME}-${PACKAGE_VERSION}" "${PACKAGE_TARBALL}"

echo "${PACKAGE_NAME}-${PACKAGE_VERSION} installation complete."
