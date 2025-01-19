#!/bin/bash

# Variables
PACKAGE_NAME="cyrus-sasl"
PACKAGE_VERSION="2.1.28"
PACKAGE_TARBALL="${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz"
PACKAGE_URL="https://github.com/cyrusimap/cyrus-sasl/releases/download/cyrus-sasl-2.1.28/${PACKAGE_TARBALL}"
PACKAGE_MD5="6f228a692516f5318a64505b46966cfa"
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
            --sysconfdir=/etc \
            --enable-auth-sasldb \
            --with-dblib=lmdb \
            --with-dbpath=/var/lib/sasl/sasldb2 \
            --with-sphinx-build=no \
            --with-saslauthd=/var/run/saslauthd

# Step 7: Build
echo "Building ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
make -j12

# Step 8: Install
echo "Installing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
sudo make install

# Step 9: Clean Up
echo "Cleaning up..."
cd ..
rm -rf "${PACKAGE_NAME}-${PACKAGE_VERSION}"

echo "${PACKAGE_NAME}-${PACKAGE_VERSION} installation complete."
