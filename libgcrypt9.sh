#!/bin/bash

# Variables
PACKAGE_NAME="libgcrypt"
PACKAGE_VERSION="1.11.0"
PACKAGE_TARBALL="${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.bz2"
PACKAGE_URL="https://www.gnupg.org/ftp/gcrypt/libgcrypt/${PACKAGE_TARBALL}"
PACKAGE_MD5="321c4975cfd6a496f0530b65a673f9a4"
BUILD_DIR="."
INSTALL_DIR="/usr"
CURRENT_USER=$(whoami)

# Step 1: Download
echo "Downloading ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
wget -O "${PACKAGE_TARBALL}" "${PACKAGE_URL}"

# Step 2: Verify MD5 checksum
echo "Verifying MD5 checksum..."
echo "${PACKAGE_MD5}  ${PACKAGE_TARBALL}" | md5sum -c -

# Step 3: Remove write protection and change ownership
echo "Removing write protection and setting ownership..."
sudo chmod -R u+w "${BUILD_DIR}/${PACKAGE_TARBALL}"
sudo chown -R ${CURRENT_USER}:${CURRENT_USER} "${BUILD_DIR}/${PACKAGE_TARBALL}"

# Step 4: Extract
echo "Extracting ${PACKAGE_TARBALL}..."
tar -xjf "${PACKAGE_TARBALL}"

# Step 5: Enter Source Directory
cd "${PACKAGE_NAME}-${PACKAGE_VERSION}"

# Step 6: Configure
echo "Configuring ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
./configure --prefix=${INSTALL_DIR}

# Step 7: Build
echo "Building ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
make -j12

# Step 8: Test
echo "Testing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
make check

# Step 9: Install
echo "Installing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
sudo make install

# Step 10: Clean Up
echo "Cleaning up..."
cd ..
rm -rf "${PACKAGE_NAME}-${PACKAGE_VERSION}"

echo "${PACKAGE_NAME}-${PACKAGE_VERSION} installation complete."
