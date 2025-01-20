#!/bin/bash

# Variables
PACKAGE_NAME="nspr"
PACKAGE_VERSION="4.35"
PACKAGE_TARBALL="${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz"
PACKAGE_URL="https://archive.mozilla.org/pub/nspr/releases/v${PACKAGE_VERSION}/src/${PACKAGE_TARBALL}"
PACKAGE_MD5="5e0acf9fbdde85181bddd510f4624841"
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
cd "${PACKAGE_NAME}-${PACKAGE_VERSION}/nspr"

# Step 6: Apply Fixes
echo "Applying fixes..."
sed -i '/^RELEASE/s|^|#|' pr/src/misc/Makefile.in
sed -i 's|$(LIBRARY) ||' config/rules.mk

# Step 7: Configure
echo "Configuring ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
./configure --prefix=${INSTALL_DIR}   \
            --with-mozilla           \
            --with-pthreads          \
            $([ "$(uname -m)" = "x86_64" ] && echo "--enable-64bit")

# Step 8: Build
echo "Building ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
make -j12

# Step 9: Install
echo "Installing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
sudo make install

# Step 10: Clean Up
echo "Cleaning up..."
cd ../..
rm -rf "${PACKAGE_NAME}-${PACKAGE_VERSION}"

echo "${PACKAGE_NAME}-${PACKAGE_VERSION} installation complete."
