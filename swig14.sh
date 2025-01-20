#!/bin/bash

# Variables
PACKAGE_NAME="swig"
PACKAGE_VERSION="4.2.1"
PACKAGE_TARBALL="${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz"
PACKAGE_URL="https://downloads.sourceforge.net/${PACKAGE_NAME}/${PACKAGE_TARBALL}"
PACKAGE_MD5="7697b443d7845381d64c90ab54d244af"
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
tar -xzf "${PACKAGE_TARBALL}"

# Step 5: Enter Source Directory
cd "${PACKAGE_NAME}-${PACKAGE_VERSION}"

# Step 6: Configure
echo "Configuring ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
./configure --prefix=${INSTALL_DIR} \
            --without-javascript \
            --without-maximum-compile-warnings

# Step 7: Build
echo "Building ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
make -j12

# Step 8: Test
echo "Testing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
PY3=1 make -j12 TCL_INCLUDE= -k check

# Step 9: Install
echo "Installing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
sudo make install

# Step 10: Clean Up
echo "Cleaning up..."
cd ..
rm -rf "${PACKAGE_NAME}-${PACKAGE_VERSION}"

echo "${PACKAGE_NAME}-${PACKAGE_VERSION} installation complete."
